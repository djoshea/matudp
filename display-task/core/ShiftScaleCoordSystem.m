classdef ShiftScaleCoordSystem < CoordSystem

    properties
        screenIdx = NaN; % screen this was built for originally
        unitName = 'pixels';
        uxPerPx = 1; % pixels in x per unit of distance 
        uyPerPy = 1; % pixels in y per unit of distance
        px0 = 1; % position of x = 0 in pixels
        py0 = 1; % position of y = 0 in pixels 
        invX = false; % x units run in opposite direction as x pixels (which puts 0 at left of screen)
        invY = true; % y units run in opposite direction as y pixels (which puts 0 at top of screen)
    end
    
    methods(Static)
        function cs = buildCenteredForScreenSize(displayNumber, varargin)
            p = inputParser();
            p.addParamValue('pixelPitch', [], @(x) isempty(x) || isscalar(x) || numel(x) == 2); % pixel pitch in mm
            p.addParamValue('units', 'mm', @ischar);
            p.parse(varargin{:});
            
            if nargin < 1
                displayNumber = max(Screen('Screens'));
            end
            
            [pixW, pixH] = Screen('WindowSize', displayNumber);
            
            cs = ShiftScaleCoordSystem();
            cs.invY = true;
            cs.unitName = p.Results.units;            
            cs.px0 = floor(pixW/2);
            cs.py0 = floor(pixH/2);
            
            if ~isempty(p.Results.pixelPitch)
                pixelPitch = p.Results.pixelPitch;
                if isscalar(pixelPitch), pixelPitch(2) = pixelPitch; end
                cs.uxPerPx = pixelPitch(1);
                cs.uyPerPy = pixelPitch(2);
            else
                % ask OS for physical display size
                [mmW, mmH] = Screen('DisplaySize', displayNumber);
                cs.uxPerPx = mmW / pixW;
                cs.uyPerPy = mmH / pixH;
            end
            
            cs.screenIdx = displayNumber;
        end
    end
    
    methods(Access=protected)
        function cs = ShiftScaleCoordSystem()
            
        end
    end

    methods
        function lims = getLimitsRect(cs, si)
            [pixW, pixH] = Screen('WindowSize', cs.screenIdx);
            limX = cs.toUx(si, [0 pixW-1]);
            limY = cs.toUy(si, [0 pixH-1]);
            lims = [min(limX) min(limY) max(limX) max(limY)];
        end
        
        function px = toPx(cs, si, ux) %#ok<*INUSL>
            if cs.invX
                ux = -ux;
            end
            px = ux / cs.uxPerPx + cs.px0;
        end

        function py = toPy(cs, si, uy)
            if cs.invY
                uy = -uy;
            end
            py = uy / cs.uyPerPy + cs.py0;
        end

        function ux = toUx(cs, si, px)
            ux = (px - cs.px0) * cs.uxPerPx; 
            if cs.invX
                ux = -ux;
            end
        end

        function uy = toUy(cs, si, py)
            uy = (py - cs.py0) * cs.uyPerPy;
            if cs.invY
                uy = -uy;
            end
        end
        
        function applyTransform(cs, si)
            Screen('glTranslate', si.windowPtr, cs.px0, cs.py0);
            Screen('glScale', si.windowPtr, 1/cs.uxPerPx, -1/cs.uyPerPy);
        end
    end


end

