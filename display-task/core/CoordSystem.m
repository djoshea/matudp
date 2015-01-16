classdef CoordSystem

    methods(Abstract)
        % si is ScreenInfo instance describing the screen
        
        % convert x coordinate into pixel location in x
        px = toPx(cs, si, ux);

        % convert y coordinate into pixel location in y
        py = toPy(cs, si, uy);

        % convert pixel location in x into x coordinate
        ux = toUx(cs, si, px);

        % convert pixel location in y into y coordinate
        uy = toUy(cs, si, py);
        
        % return xMin, yMin, xMax, yMax in user coordinates
        lims = getLimitsRect(cs, si);
        
        % apply the transformation to the current gl context
        applyTransform(cs, si)
    end
        
end
