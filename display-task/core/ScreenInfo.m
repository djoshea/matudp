classdef ScreenInfo < handle
    
    properties(SetAccess=protected)
        screenIdx
        windowPtr

        isOpen = false; % indicates whether the screen has been opened already

        isFullScreen

        screenRectCached

        % color scale
        cMax
        cMin
        
        oldPrefVisualDebugLevel
        oldPrefSkipSyncTests
        oldPrefMaxStdDevVBL
    end
    
    properties
        multisample = 4;
        initBlack = true;
        skipSyncTests = false;
        maxStdDevVBL = 1.8;
    end
    
    properties
        cs % CoordSystem
    end
    
    properties(Dependent)
        window
        
        screenRect % screen pixel coordinates of window, adjusts dynamically when not in full screen
    end

    properties(SetAccess=protected)
        pxWidth
        pxHeight
        
        uxMin % min x value in units of coordSystem
        uxMax % max x value in units of coordSystem
        uxSignRight % delta for rightward moving x coordinates (-1 or 1)
        uyMin % min y value in units of coordSystem
        uyMax % max y value in units of coordSystem
        uySignDown % delta for downward moving y coordinates (-1 or 1)
    end
    
    methods
        function si = ScreenInfo(screenIdx, cs, screenRect)
            if nargin < 1
                error('Usage: ScreenInfo(screenIdx)');
            end
            si.screenIdx = screenIdx;
            si.cs = cs;

            if exist('screenRect', 'var') && ~isempty(screenRect)
                % typically specified for partial debug screen windows only
                si.screenRectCached = screenRect;
                si.isFullScreen = false;
            else
                si.isFullScreen = true;
            end

            si.update();
        end
        
        function update(si)
            if si.isFullScreen
                si.screenRectCached = Screen('Rect', si.screenIdx);
            end
            
            si.cMin = 0;% BlackIndex(si.screenIdx); % pixel value for black
            si.cMax = 1;% WhiteIndex(si.screenIdx); % pixel value for white
        end
        
        function delete(si)
            si.close();
        end
        
        function open(si)
            si.setPrefs();

            if si.initBlack
                initColor = [si.cMin si.cMin si.cMin];
            else
                initColor = [si.cMax si.cMax si.cMax];
            end

            if si.isFullScreen
                si.windowPtr = Screen(si.screenIdx, 'OpenWindow', initColor, ...
                    [], [], [], [], si.multisample);
            else
                % according to http://tech.groups.yahoo.com/group/psychtoolbox/message/13817   
                % setting specialFlags = 32 makes the call to GlobalRect query the window
                % manager so that when you move the gui window around or resize it, the rect
                % returned remains accurate
                specialFlags = 32;
                si.windowPtr = Screen(si.screenIdx, 'OpenWindow', initColor, ...
                    si.screenRect, [], [], [], si.multisample, [], specialFlags );
            end
            
            Screen(si.windowPtr, 'ColorRange', 1.0); 
            Screen(si.windowPtr, 'BlendFunction', GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            
            lims = si.cs.getLimitsRect(si);
            si.uxMin = lims(1);
            si.uxMax = lims(3);
            si.uyMin = lims(2);
            si.uyMax = lims(4);
            si.uxSignRight = sign(diff(si.cs.toUx(si, [0 1])));
            si.uySignDown = sign(diff(si.cs.toUy(si, [0 1])));
                   
            % apply scaling and translation to align openGL coordinates
            % with coordinate system
            si.cs.applyTransform(si);
            
            si.isOpen = true;
        end
        
        function close(si)
            Screen('CloseAll')
            si.restorePrefs();
            si.isOpen = false;
        end
        
        function setPrefs(si)
            if si.initBlack
                si.oldPrefVisualDebugLevel = Screen('Preference', 'VisualDebugLevel', 1);
            end
            if si.skipSyncTests
                si.oldPrefSkipSyncTests = Screen('Preference', 'SkipSyncTests', 2 );
            else
                si.oldPrefSkipSyncTests = Screen('Preference', 'SkipSyncTests', 0 );
            end
            if ~isempty(si.maxStdDevVBL)
                si.oldPrefMaxStdDevVBL = Screen('Preference','SyncTestSettings', si.maxStdDevVBL);
            end
        end
        
        function restorePrefs(si)
            if ~isempty(si.oldPrefSkipSyncTests)
                Screen('Preference', 'SkipSyncTests', si.oldPrefSkipSyncTests );
            end
            if ~isempty(si.oldPrefVisualDebugLevel)
                Screen('Preference', 'VisualDebugLevel', si.oldPrefVisualDebugLevel);
            end
            if ~isempty(si.oldPrefMaxStdDevVBL)
                Screen('Preference','SyncTestSettings', si.oldPrefMaxStdDevVBL);
            end
        end
        
    end
    
    methods
        function window = get.window(si)
            assert(~isempty(si.windowPtr), 'Call .open() first!');
            window = si.windowPtr;
        end

        function rect = get.screenRect(si)
            % get the global pixel coordinates of the window's boundaries
            % for full screen windows this is the [0 0 pixelsInX pixelsInY] size of the monitor
            % for partial screen windows this is the coordinates occupied on screen, 
            % which may change if the window is moved or resized while running
            
            if si.isFullScreen || ~si.isOpen
                % in full screen mode, this doesn't change, so used the rect cached during .update()
                % also, if the screen hasn't been opened yet, then it must be its initial size
                rect = si.screenRectCached;
            else
                % if not in full screen mode, the window may be resized, so query the rect directly
                rect = Screen('GlobalRect', si.windowPtr);
            end
        end

        function set.cs(si, cs)
            assert(isa(cs, 'CoordSystem'), 'Must be of class CoordSystem');
            si.cs = cs;
        end
        
    end
    
end
