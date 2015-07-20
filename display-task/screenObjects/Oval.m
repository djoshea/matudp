classdef Oval < ScreenObject
    %
    % Define an oval target with a specified rectangle.
    
    properties
        xc
        yc
        width
        height
        borderColor
        borderWidth = 0;
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
        function obj = Oval(xc, yc, width, height)
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
            str = sprintf('(%g, %g) size %g x %g', ...
                r.xc, x.yc, r.width, r.height);
        end
        
        function update(r, mgr, sd)
            
        end
        
        function draw(r, sd)
            state = sd.saveState();
            sd.penColor = r.borderColor;
            sd.penWidth = r.borderWidth;
            sd.fillColor = r.fillColor;
            sd.drawOval(r.x1, r.y1, r.x2, r.y2, r.fill);
            sd.restoreState(state);
        end
        
        function borderColor = get.borderColor(r)
            % fill color defaults to frame color unless specified otherwise
            if isempty(r.borderColor) && r.fill
                borderColor = r.fillColor;
            else
                borderColor = r.borderColor;
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
    end
    
end

