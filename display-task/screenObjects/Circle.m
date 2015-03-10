classdef Circle < Oval 
    % Define an circle with a specified radius
    
    properties
        radius
    end

    methods 
        function set.radius(r, val)
            r.height = val*2;
            r.width = val*2;
        end
    end
    
    methods
        function obj = Circle(xc, yc, radius)
            obj = obj@Oval(xc, yc, radius*2, radius*2);
        end
    end
end

