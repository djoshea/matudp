classdef Rectangle < ScreenObject

    properties
        xc
        yc
        width
        height
        color
        borderWidth = 1;
        fillColor
        fill = false;
    end

    properties(Dependent)
        x1
        y1
        x2
        y2
    end

    methods
        function obj = Rectangle(xc, yc, width, height)
            obj.xc = xc;
            obj.yc = yc;
            obj.width = width;
            obj.height = height;
        end

        function str = describe(r)
            plusMinus = char(177);
            if r.fill
                fillStr = 'filled';
            else
                fillStr = 'unfilled';
            end
            str = sprintf('(%g, %g) size %g x %g, %s', ...
                r.xc, r.yc, r.width, r.height, fillStr);
        end

        function update(r, mgr, sd)

        end

        function draw(r, sd)
            state = sd.saveState(); 
            sd.penColor = r.color;
            sd.fillColor = r.fillColor;
            sd.penWidth = r.borderWidth;
            sd.drawRect(r.x1, r.y1, r.x2, r.y2, r.fill); 
            sd.restoreState(state);
        end
       
        function color = get.fillColor(r)
            % fill color defaults to frame color unless specified otherwise
            if isempty(r.fillColor) && r.fill
                color = r.color;
            else
                color = r.fillColor;
            end
        end

        function x1 = get.x1(r)
            x1 = r.xc - r.width/2;
        end

        function y1 = get.y1(r)
            y1 = r.yc - r.height/2;
        end

        function x2 = get.x2(r)
            x2 = r.xc + r.width/2;
        end

        function y2 = get.y2(r)
            y2 = r.yc + r.height/2;
        end

        function tf = getIsOffScreen(r, sd)
            tf = false;
            tf = tf || max([r.x1 r.x2]) < sd.xMin;
            tf = tf || min([r.x1 r.x2]) > sd.xMax;
            tf = tf || max([r.y1 r.y1]) < sd.yMin;
            tf = tf || min([r.y1 r.y2]) > sd.yMax;
        end
    end

end

