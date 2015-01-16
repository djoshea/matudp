classdef Cross < ScreenObject

    properties
        xc
        yc
        width
        height
        color
        lineWidth = 1;
    end

    methods
        function obj = Cross(xc, yc, width, height)
            obj.xc = xc;
            obj.yc = yc;
            obj.width = width;
            obj.height = height;
        end

        function str = describe(r)
            str = sprintf('(%g, %g) size %g x %g', ...
                r.xc, r.yc, r.width, r.height);
        end

        function update(r, mgr, sd)

        end

        function draw(r, sd)
            state = sd.saveState(); 
            if isempty(r.color)
                r.color = sd.white;
            end
            sd.penColor = r.color;
            sd.penWidth = r.lineWidth;
            sd.drawCross(r.xc, r.yc, r.width, r.height); 
            sd.restoreState(state);
        end
       
    end

end

