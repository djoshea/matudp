classdef NetworkShell < DisplayController
% This class runs a shell that receives network commands over udp
% and allows remote control of the task on screen
%
% The network commands operate inside a virtual workspace. The evaluation
% function automatically saves and restores the variables in this workspace
% so that successively sent commands can access variables created in earlier
% commands. The evaluation function can automatically add any
% created ScreenObject instances to the ScreenObjectManager as well,
% if autoAddScreenObjectsToManager == true (default). This saves repeated calls
% to mgr.add() and mgr.remove()
%

    properties
        % if true, all ScreenObject instances that exist in the evaluation
        % workspace will be automatically added to the ScreenObjectManager
        % which saves you from needing to send mgr.add(...) and .remove(...)
        % calls across the network
        autoAddScreenObjectsToManager = true;
    end

    properties
        netLog % ScreenLog object for logging incoming commands
        lastInfoPollTime 
    end

    methods
        function ns = NetworkShell(varargin)
            ns = ns@DisplayController(varargin{:});
            ns.name = 'NetworkShell';
        end
    end

    methods(Access=protected)

        function initialize(ns)
            ns.setTask('DisplayTask');
           
            % log of all the received network packets
            ns.netLog = ns.addLog('Network Rx Log:');
            ns.netLog.titleColor = ns.sd.white;
            ns.netLog.entrySpacing = 2;
            ns.netLog.titleSpacing = 3;
            ns.netLog.hide();
        end

        function cleanup(ns)

        end

        function update(ns)
            ns.readNetwork();
            ns.hideMouseIfNotPolled();
        end

        function readNetwork(ns)
            groups = ns.com.readGroups();
            evalCommands = {};

            for iG = 1:length(groups)
                group = groups(iG);

                switch group.name
                    case 'eval'
                        if isfield(group.signals, 'eval')
                            % evaluate a command directly in the network workspace
                            evalCommands{end+1} = group.signals.eval;
                            ns.netLog.add(group.signals.eval);
                        else
                            ns.log('Eval group received without eval signal');
                        end

                    case 'setTask'
                        if isfield(group.signals, 'setTask')
                            taskName = group.signals.setTask;
                        elseif isfield(group.signals, 'taskName')
                            taskName = group.signals.taskName;
                        else
                            ns.log('setTask group received without taskName or setTask signal');
                            continue;
                        end
                        if isfield(group.signals, 'taskVersion')
                            taskVersion = group.signals.taskVersion;
                        else
                            taskVersion = NaN;
                        end
                        ns.setTask(taskName, taskVersion);

                    case 'taskCommand'
                        % calls .runCommand on the current DisplayTask
                        % runCommand receives the name of the command and a containers.Map
                        % handle that contains the current net workspace (groups received via
                        % 'ds' tags)
                        if isfield(group.signals, 'taskCommand')
                            taskCommands = group.signals.taskCommand;
                            if ischar(taskCommands)
                                taskCommands = {taskCommands};
                            end
                                
                            for i = 1:numel(taskCommands)
                                ns.task.runCommand(taskCommands{i}, ns.taskWorkspace);
                            end
                        else
                            ns.log('taskCommand group received without taskCommand signal');
                        end

                    case 'infoPoll'
                        % xpc has requested the mouse position
                        ns.showMouse(); % show the mouse so we know what to point with
                        ns.sendInfoPacket(); % send the data back to xpc
                        
                        %ns.log('Sending mouse position');
                        
                    otherwise
                        % add to the task workspace
                        ns.addToTaskWorkspace(group.name, group.signals);
                end
            end

            % run all eval commands at once
            if ~isempty(evalCommands)
                ns.evaluate(evalCommands);
            end
        end

        function sendInfoPacket(ns)
            % send information about the screen flip and 
            screenFlip = 1;
            [mouseX, mouseY, buttons] = ns.sd.getMouse();
            mouseClick = any(buttons);

            data = [uint8('<displayInfo>') uint8(screenFlip) typecast(mouseX, 'uint8') typecast(mouseY, 'uint8') uint8(mouseClick)];
            ns.com.writePacket(data);

            ns.lastInfoPollTime = tic;
        end

        function hideMouseIfNotPolled(ns)
            % if lastInfoPollTime was sufficiently long ago, then we hide the
            % mouse cursor

            pollExpireTimeSec = 0.1; % seconds for poll

            if isempty(ns.lastInfoPollTime) || toc(ns.lastInfoPollTime) >= pollExpireTimeSec
                ns.hideMouse();
            end
        end

        function evaluate(ns, cmdList)
            % assign these commonly used items to the workspace so they are accessible
            % by the network commands
            % cmdList is a cell array (or single string) of commands sent across the network
            
            % mgr is the ScreenObjectManager which draws everything
            mgr = ns.mgr;

            % sd is the ScreenDraw object
            sd = ns.sd;

            if ischar(cmdList)
                cmdList = {cmdList};
            end
            local.cmdList = cmdList;
            clear cmdList;

            % list of names not to overwrite or save as part of the network workspace
            local.excludedNames = {'mgr', 'ns', 'sd', 'local'};

            % expand the saved workspace 
            if ~isempty(ns.taskWorkspace)
                ns.restoreWorkspace(ns.taskWorkspace, local.excludedNames);
            end

            % attempt to evaluate
            local.iCmd = 1;
            while local.iCmd <= length(local.cmdList)
                local.cmd = local.cmdList{local.iCmd};
                try
                    eval(local.cmd);
                catch exc
                    fprintf('Error: %s\n', local.report);
                    % log the exception in the debugLog
                    local.report = exc.message;
                    % remove html tags like <a> from the report as they won't display well
                    local.report = regexprep(local.report, '<[^>]*>([^<>])*</[^>]*>', '$1');
                    ns.log('NetworkShell: error executing %s\n%s', local.cmd, local.report);
                    clear exc;
                end

                local.iCmd = local.iCmd + 1;
            end

            % now grab all the screen objects and store them in the manager
            %ns.saveFoundScreenObjectsInMgr(local.excludedNames);

            % save the workspace for next time
            ns.taskWorkspace = ns.saveWorkspace(local.excludedNames);
        end


        function clear(ns)
            % clear all objects of type ScreenObject from calling
            % workspace
            vars = evalin('caller', 'whos');
            varNames = {vars.name};

            for i = 1:length(varNames)
                if ismember(varNames{i}, {'ans'})
                    continue;
                end
                val = evalin('caller', varNames{i});
                if isa(val, 'ScreenObject')
                    evalin('caller', sprintf('clear(''%s'')', varNames{i}));
                end
            end
        end

        function saveFoundScreenObjectsInMgr(ns, excludedNames)
            % find all ScreenObjects in calling workspace and save them into .mgr
            vars = evalin('caller', 'whos');
            varNames = {vars.name};

            objList = [];

            for i = 1:length(varNames)
                %if ismember(varNames{i}, union(excludedNames, 'ans'))
                %    continue;
                %end

                val = evalin('caller', varNames{i});
                if isa(val, 'ScreenObject')
                    %fprintf('Adding to manager : %s\n', varNames{i});
                    objList = [objList val];
                end
            end

            ns.mgr.objList = objList;
        end

        function [objList objNames] = getWorkspaceScreenObjects(ns, excludeNames)
            % assemble a list of all the ScreenObject instances saved in
            % ns.taskWorkspace
            if ~exist('excludeNames', 'var')
                excludeNames = {};
            end

            objList = [];
            objNames = {};

            ws = ns.taskWorkspace;
            if isempty(ws)
                return;
            end

            varNames = fieldnames(ws);
            for i = 1:length(varNames)
                %if ismember(varNames{i}, union(excludeNames, 'ans'))
                %    continue;
                %end
                val = ws.(varNames{i});
                if isa(val, 'ScreenObject')
                    objList = [objList val];
                    objNames = [objNames varNames{i}];
                end
            end
        end

        function ws = saveWorkspace(ns, excludeNames)
            % save every variable in calling workspace into a struct
            % except for variables whos names are in excludeNames
            ws = struct();

            if ~exist('excludeNames', 'var')
                excludeNames = {};
            end

            vars = evalin('caller', 'whos');
            varNames = {vars.name};

            varNames = setdiff(varNames, excludeNames);

            for i = 1:length(varNames)
                %   fprintf('Saving to workspace : %s\n', varNames{i});

                % grab the value in the calling workspace
                val = evalin('caller', varNames{i});
                ws.(varNames{i}) = val;
            end
        end

        function restoreWorkspace(ns, ws, excludeNames)
            if ~exist('excludeNames', 'var')
                excludeNames = {};
            end

            varNames = ws.keys;
            for i = 1:length(varNames)
                %if ismember(varNames{i}, union(excludeNames, 'ans'))
                %    continue;
                %end

                %                fprintf('Restoring var %s\n', varNames{i});
                % write this variable into the calling workspace
                assignin('caller', varNames{i}, ws(varNames{i}));
            end
        end
    end

end
