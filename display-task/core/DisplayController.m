classdef DisplayController < handle

    properties
        name % name of display controller for display purposes
        cxt % display context 

        si % screen info object
        sd % screen draw object
        mgr % screen object manager

        task = DisplayTask(); % currently active DisplayTask object

        taskWorkspace % workspace of variables created by network commands
                     % struct with .groupName containing group signals as struct

        com % UDP Communication object
        suppressErrors = false;
        catchErrors = true;
    end

    properties % debug Screen Objects
        logWidth
        logHeight
        logYGap
        logYOffset 
        logXOffset

        debugLog % debugging log
        objListLog % list of ScreenObjects currently displayed
        frameRateMsg 
        execTimeMsg 
    end

    methods
        function dc = DisplayController(context)
            if nargin < 1
                context = DisplayContext();
            end
            dc.cxt = context;
            dc.name = 'DisplayController';
            dc.taskWorkspace = struct();
        end

        function delete(dc)
            dc.postRun();
        end
    end

    methods(Sealed)
        function run(dc, returnControl)
            if nargin == 1
                returnControl = false;
            end
            % run(ScreenDraw sd, ScreenObjectManager mgr)
            % DO NOT OVERRIDE THIS METHOD, override runController INSTEAD

            if ~dc.cxt.useFullScreen
                % specify bounds of screen when using partial window (for debugging)
                screenRect = dc.cxt.screenRect;
            else
                % empty means use full screen
                screenRect = [];
            end
            
            % initialize the screen info with the screen index, coordinate system, 
            % and screenRect (if the display context is not full screen)
            dc.si = ScreenInfo(dc.cxt.screenIdx, dc.cxt.cs, screenRect);
            
            dc.sd = ScreenDraw(dc.si);
            dc.mgr = ScreenObjectManager(dc.sd);

            if ~isempty(dc.cxt.networkTargetIP) && ~isempty(dc.cxt.networkTargetPort)
                dc.com = UdpCommunication(dc.cxt);
                dc.com.open();
            end

            dc.preRun();

            if ~returnControl
                if dc.catchErrors
                    try
                        dc.runLoop(true);
                    catch exc
                        dc.postRun(); 

                        if ~dc.suppressErrors
                            dc.postRun();
                            rethrow(exc);
                        else
                            fprintf(2, exc.getReport());
                        end
                    end
                else
                    dc.runLoop(true);
                end

                dc.postRun();
            end
        end

        function log(dc, message, varargin)
            % accepts printf like arguments
            timeStr = datestr(now, 'HH:MM:SS.FFF');
            messageStr = sprintf(message, varargin{:});
            str = sprintf('[ %12s ] : %s', timeStr, messageStr);
            if ~isempty(dc.debugLog)
                dc.debugLog.add(str);
            end
        end

        function task = setTask(dc, task, taskVersion)
            % setTask(DisplayTask task) or setTask('NameOfDisplayTaskClass')
            if nargin < 3
               taskVersion = NaN;
            end
            
            newTask = false;
            if ischar(task)
                % provided task name, check whether current task is same type
                if ~isa(dc.task, task)
                    % not currently using this task, create a new one
                    fprintf('Setting task to %s\n', task);
                    newTask = true;
                    task = eval(task);
                    task.version = taskVersion;
                end
            else
                if ~isa(dc.task, class(task))
                    newTask = true;
                end
            end

            if newTask
                assert(isa(task, 'DisplayTask'), 'Task must be a DisplayTask instance');
                
                % clear everything out of ScreenObjectManager
                dc.mgr.flush();
                
                % cleanup old task
                if ~isempty(dc.task)
                    dc.task.cleanup();
                end

                % assign task as the new active task and call its initialization function
                dc.task = task;
                dc.task.dc = dc; % provide it with access to the display controller
                
                % do this only if we're already running
                if ~isempty(dc.si)
                    dc.task.initialize();
                end

                dc.log('New task : %s', class(task));
            end

            % return the task object
            task = dc.task;
        end

        function addToTaskWorkspace(ns, name, value)
            ns.taskWorkspace.(name) = value;
        end

    end

    methods(Sealed)
        function postRun(dc)
            dc.sd.close();
            Screen('CloseAll');
            if ~isempty(dc.com)
                dc.com.close();
            end
            dc.cleanup();
        end

        function preRun(dc)
            dc.logWidth = 200;
            dc.logHeight = 80;
            dc.logYGap = 10;
            dc.logYOffset = dc.sd.yMax;
            dc.logXOffset = dc.sd.xMax - dc.logWidth - dc.logYGap;

            dc.addDebugScreenObjects();

            % initialize with a black screen
            dc.sd.open();
            dc.sd.fillBlack();
            dc.sd.hideCursor();
            dc.sd.flip();

            dc.initialize();
            
            if ~isempty(dc.task)
                dc.task.initialize();
            end
        end

        function addDebugScreenObjects(dc)
            % display frame rate on screen
           % dc.frameRateMsg = ScreenMessage(dc.sd.xMin+10, dc.sd.yMax-10);
           % dc.frameRateMsg.show();
           % dc.mgr.add(dc.frameRateMsg);
            
            dc.execTimeMsg = ScreenMessage(dc.sd.xMin+10, dc.sd.yMax-20);
            %dc.execTimeMsg.show();
            %dc.mgr.add(dc.execTimeMsg);

            % debug log 
            dc.debugLog = dc.addLog('Debug Log:');
            dc.debugLog.titleColor = dc.sd.white;
            dc.debugLog.entrySpacing = 2;
            dc.debugLog.titleSpacing = 3;
            dc.mgr.remove(dc.debugLog);
            
            % log of all the active objects
            %dc.objListLog = dc.addLog('ScreenObject List:')
            %dc.objListLog.titleColor = dc.sd.white;
            %dc.objListLog.entrySpacing = 2;
            %dc.objListLog.titleSpacing = 3;
        end

        function hLog = addLog(dc, title)
            hLog = ScreenLog(dc.logXOffset, dc.logYOffset, dc.logWidth, dc.logHeight, ...
                title);
            dc.mgr.add(hLog);

            dc.logYOffset = dc.logYOffset - dc.logHeight - dc.logYGap;
        end

        function runLoop(dc, runUntilAbort)
            if nargin == 1
                runUntilAbort = false;
            end

            execTimeBuf = nan(1,30);
            maxExecTime = 0;
            while ~dc.checkAbort()
                
                % reload transformation each time if not full screen
                if ~dc.cxt.useFullScreen
                    Screen('glLoadIdentity', dc.si.windowPtr);
                    dc.cxt.cs.applyTransform(dc.si);
                end
                
                tStart = tic;

                % create a list of all ScreenObjects in the network shell workspace
                %dc.objListLog.flush();
                %[objList objNames] = dc.getWorkspaceScreenObjects();
                %for i = 1:length(objList)
                %    desc = sprintf('%10s : %10s %s', objNames{i}, class(objList(i)), objList(i).describe());
                %    dc.objListLog.add(desc);
                %end

                % call the display controller child class) update()
                dc.update();

                if ~isempty(dc.task)
                    dc.task.update(dc.taskWorkspace);
                end

                % update and draw all of the screen objects
                dc.mgr.updateAll();
                dc.mgr.drawAll();
                
                dc.sd.flip();
                
                execTime = toc(tStart);
                maxExecTime = max([execTime maxExecTime]);

                %dc.execTimeMsg.message = sprintf('ET: %5.0f ms / MaxET: %5.0f ms', execTime * 1000, maxExecTime * 1000);
                execTimeBuf = [execTimeBuf(2:end) toc(tStart)];

                % compute execution time between flips
                
                %frameRate = 1/mean(execTimeBuf);
                %if ~isnan(frameRate)
                %    dc.frameRateMsg.message = sprintf('Rate: %6.2f Hz', frameRate);
                %end

                if ~runUntilAbort
                    break;
                end
            end
        end

        function abort = checkAbort(dc)
            % abort on escape
            [~, ~, keyCodes] = KbCheck;
            abort = keyCodes(KbName('escape'));             
%             if dc.cxt.useFullScreen
%                 abort = KbCheck;
%             else
%                 abort = false;
%             end
        end
    end
    
    methods
        function makeDebugScaledController(dc)
            dc.cxt.makeDebugScaledContext();
            dc.suppressErrors = false;
            dc.catchErrors = false;
        end
    end

    methods(Access=protected)
        function initialize(dc) %#ok<MANU>
            %   Perform any initializations needed by the dc
        end

        function update(dc)
            %   Run a single frames worth of updating screen objects,
            %   no need to call mgr.drawAll, flip, or wrap in try catch
            dc.log('DisplayController.update()');
        end

        function cleanup(dc) %#ok<MANU>
            %   cleanup when the dc is terminated or in the event of an error 
        end

        function showMouse(dc)
            % show the mouse cursor 
            if ~dc.sd.cursorVisible
                dc.sd.showCursor();
            end
        end

        function hideMouse(dc)
            % hide the mouse cursor 
            if dc.sd.cursorVisible
                dc.sd.hideCursor();
            end
        end
    end


end
