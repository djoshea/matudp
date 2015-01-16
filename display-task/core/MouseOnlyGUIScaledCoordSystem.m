classdef MouseOnlyGUIScaledCoordSystem < CoordSystem
    % this coordinate system starts with a shift scale coord system which maps the
    % entire screen to real world (i.e. Polaris) coordinates. Then it scales this
    % such that the entire screen as it would be drawn is scaled into a partial-screen
    % GUI window for debugging. This means that the entire display seen in the rig
    % appears in the smaller GUI window, but of course the screen no longer lines up with
    % the real world Polaris coordinates. This is only useful for debugging with the mouse
    % as it forces the mouse to line up with the on screen display despite being sent
    % to xpc and scaled

    properties
        csFull % original coordinate system to scale
        screenRectFull % cache the window size of the original screen's full rectangle
    end

    methods
        function cs = MouseOnlyGUIScaledCoordSystem(csFull)
            assert(nargin == 1 && isa(csFull, 'ShiftScaleCoordSystem'), ...
                'Usage: MouseOnlyGUIScaledCoordSystem(ShiftScaleCoordSystem csFullScreen)');
            cs.csFull = csFull;
            % cache the full size of the screen that the original
            % coordinate system is based on
            [w,h] = Screen('WindowSize', csFull.screenIdx);
            cs.screenRectFull = [0, 0, w, h];
        end

        function scaled = scale(cs, value, rangeOrig, rangeNew) %#ok<INUSL>
            scaled = (value - rangeOrig(1)) / diff(rangeOrig) * diff(rangeNew) + rangeNew(1);
        end
        
        function lims = getLimitsRect(cs, si)
            lims = cs.csFull.getLimitsRect(si);
        end

        function px = toPx(cs, si, ux)
            % have the original coordinate system translate this into full screen pixels
            pxFull = cs.csFull.toPx(si, ux);
            rectFull = cs.screenRectFull;
            rectWindow = si.screenRect;

            % and then scale down to partial window pixels relative to window origin
            px = cs.scale(pxFull, [rectFull(1) rectFull(3)], [0 rectWindow(3)-rectWindow(1)]);
        end

        function py = toPy(cs, si, uy)
            % have the original coordinate system translate this into full screen pixels
            pyFull = cs.csFull.toPy(si, uy);
            rectFull = cs.screenRectFull;
            rectWindow = si.screenRect;

            % and then scale down to partial window pixels relative to window origin
            py = cs.scale(pyFull, [rectFull(2) rectFull(4)], [0 rectWindow(4)-rectWindow(2)]);
        end

        function ux = toUx(cs, si, px)
            % scale pixels in the partial window relative to window origin to pixels in the full screen 
            
            rectFull = cs.screenRectFull;
            rectWindow = si.screenRect;
            pxFull = cs.scale(px, [0 rectWindow(3)-rectWindow(1)], [rectFull(1) rectFull(3)]);
            
            % then have the original coordinate system translate this into real world units 
            ux = cs.csFull.toUx(si, pxFull);
        end

        function uy = toUy(cs, si, py)
            % scale pixels in the partial window relative to window origin to pixels in the full screen 
            rectFull = cs.screenRectFull;
            rectWindow = si.screenRect;
            pyFull = cs.scale(py, [0 rectWindow(4)-rectWindow(2)], [rectFull(2) rectFull(4)]);
            
            % then have the original coordinate system translate this into real world units 
            uy = cs.csFull.toUy(si, pyFull);
        end
             
        function applyTransform(cs, si)
            rectWindow = si.screenRect;
            rectFull = cs.screenRectFull;
            
            rectScaleX = (rectWindow(3) - rectWindow(1)) / (rectFull(3) - rectFull(1));
            rectScaleY = (rectWindow(4) - rectWindow(2)) / (rectFull(4) - rectFull(2));
            
            % pick single scaling factor to maintain aspect ratio
            rectScale = min(rectScaleX, rectScaleY);
            
            % want 0, 0 in user coordinates, which would be at px0, py0 on
            % the original screen, to now be shifted and scaled to lie in
            % our new window
            
            deltaX = cs.csFull.px0 - (rectFull(3)-rectFull(1))/2 + (rectWindow(3) - rectWindow(1))/2;
            deltaY = cs.csFull.px0 - (rectFull(3)-rectFull(1))/2 + (rectWindow(4) - rectWindow(2))/2;
            Screen('glTranslate', si.windowPtr, deltaX, deltaY);
            
            Screen('glScale', si.windowPtr, 1/cs.csFull.uxPerPx * rectScale, -1/cs.csFull.uyPerPy * rectScale);
        end
    end


end

