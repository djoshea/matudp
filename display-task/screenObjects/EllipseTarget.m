classdef EllipseTarget < Target 
% 
% 

    methods
        function obj = EllipseTarget(xc, yc, width, height)
            obj = obj@Target(xc,yc,width,height);
        end 
        
        function draw(r, sd)
            state = sd.saveState(); 
            sd.penColor = r.color;
            sd.fillColor = r.fillColor;
            sd.penWidth = r.borderWidth;
            sd.drawOval(r.x1o, r.y1o, r.x2o, r.y2o, r.fill); 
            sd.restoreState(state);
        end
       
    end

end

