classdef ManualShell < DisplayController
% This class runs a shell which responds similarly to NetworkShell
% but is driven via manual command entry.

    properties
        netWorkspace % workspace of variables created by network commands
                     % containers.Map groupName -> group signals
    end

    methods
        function ns = ManualShell()
            ns.name = 'ManualShell';
            ns.netWorkspace = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end
    end

    methods(Access=protected)

        function initialize(ns)
            ns.setTask('DisplayTask');
        end

        function cleanup(ns)

        end

        function update(ns)
            NEW_PROMPT = 1;
            WAIT_CHAR = 2;

            BACKSPACE = 127;
            NEW_LINE = 13;

            persistent pState;
            % buffer for storing command text
            persistent pBuffer;
            persistent idxBuffer;
            if isempty(pState)
                pState = NEW_PROMPT;
                pBuffer = '';
                idxBuffer = 1;
            end

            if pState == NEW_PROMPT
                fprintf('Shell >> ');
                pState = WAIT_CHAR;
                pBuffer = '';
            end

            if pState == WAIT_CHAR && CharAvail()
                % new character entered
                ch = GetChar();
                if ch == BACKSPACE
                    if ~isempty(pBuffer)
                        pBuffer = pBuffer(1:end-1);
                        fprintf('\b \b');
                    end

                elseif ch == NEW_LINE
                    % run the command
                    if strcmp(pBuffer, 'q') 
                        error('Aborting');
                    elseif ~isempty(pBuffer)
                        fprintf('\n', pBuffer);
                        ns.evaluate({pBuffer});
                    end
                    pState = NEW_PROMPT;

                else
                    fprintf(ch);
                    pBuffer = [pBuffer ch];
                end
            end
        end

        function commands = readXpc(ns);
            [tags groups] = ns.xcom.readTaggedPacketsParseData();

            % assign each dataSerializer sent group into the virtual workspace
            groupNames = fieldnames(groups);
            for iG = 1:length(groupNames)
                name = groupNames{iG};

                if strcmp(name, 'handInfo')
                    % if this contains the handInfo bus, call the task update directly
                    %ns.log('Updating hand position');
                    ns.task.updateHand(groups.(name));
                end

                if strcmp(name, 'infoPoll')
                    % xpc has requested the mouse position
                    ns.showMouse(); % show the mouse so we know what to point with
                    ns.sendInfoPacket(); % send the data back to xpc
                    
                    %ns.log('Sending mouse position');
                end

%                 if ~ismember(name, {'handInfo', 'infoPoll'})
%                     %fprintf('Receiving data group %s\n', name);
%                     if strcmp(name, 'P')
%                         fprintf('Target declared at (%.1f, %.1f)\n', groups.P.targetX, groups.P.targetY);
%                     end
%                     if strcmp(name, 'requestNewTrialParams')
%                         d = groups.requestNewTrialParams;
%                         fprintf('New target at (%.1f, %.1f)\n', d.targetX, d.targetY);
%                     end
%                 end
                ns.addToWorkspace(name, groups.(name));
            end

            % parse out the commands
            nTags = length(tags);
            commands = {};
            for iTag = 1:nTags
                tag = tags(iTag);

                switch tag.type
                    case 'eval'
                        % evaluate a command directly in the network workspace
                        commands{end+1} = tag.str;
                        ns.netLog.add(tag.str);

                    case 'setTask'
                        ns.setTask(tag.str);

                    case 'taskCommand'
                        % calls .runCommand on the current DisplayTask
                        % runCommand receives the name of the command and a containers.Map
                        % handle that contains the current net workspace (groups received via
                        % 'ds' tags)
                        ns.task.runCommand(tag.str, ns.netWorkspace);
                    otherwise
                        ns.log('Unknown tag <%s> received', tag.type);
                end
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
            if ~isempty(ns.netWorkspace)
                ns.restoreWorkspace(ns.netWorkspace, local.excludedNames);
            end

            % attempt to evaluate
            local.iCmd = 1;
            while local.iCmd <= length(local.cmdList)
                local.cmd = local.cmdList{local.iCmd};
                try
                    eval(local.cmd);
                catch exc
                    % log the exception in the debugLog
                    local.report = exc.message;
                    fprintf('Error: %s\n', local.report);
                    % remove html tags like <a> from the report as they won't display well
                 %   local.report = regexprep(local.report, '<[^>]*>([^<>])*</[^>]*>', '$1');
                 %   ns.log('NetworkShell: error executing %s\n%s', local.cmd, local.report);
                    clear exc;
                end

                local.iCmd = local.iCmd + 1;
            end

            % now grab all the screen objects and store them in the manager
            ns.saveFoundScreenObjectsInMgr(local.excludedNames);

            % save the workspace for next time
            ns.netWorkspace = ns.saveWorkspace(local.excludedNames);
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
            % ns.netWorkspace
            if ~exist('excludeNames', 'var')
                excludeNames = {};
            end

            objList = [];
            objNames = {};

            ws = ns.netWorkspace;
            if isempty(ws)
                return;
            end

            varNames = ws.keys;
            for i = 1:length(varNames)
                %if ismember(varNames{i}, union(excludeNames, 'ans'))
                %    continue;
                %end
                val = ws(varNames{i});
                if isa(val, 'ScreenObject')
                    objList = [objList val];
                    objNames = [objNames varNames{i}];
                end
            end
        end

        function ws = saveWorkspace(ns, excludeNames)
            % save every variable in calling workspace into a key-value map
            % except for variables whos names are in excludeNames
            ws = containers.Map('KeyType', 'char', 'ValueType', 'any');

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
                ws(varNames{i}) = val;
            end
        end

        function addToWorkspace(ns, name, value)
            ns.netWorkspace(name) = value;
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
