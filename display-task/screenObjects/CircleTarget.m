classdef CircleTarget < OvalTarget
    % Define an circle with a specified radius
    
    properties
        radius
    end

    methods 
        function set.radius(r, val)
            r.height = val*2;
            r.width = val*2;
        end
        
        function rad = get.radius(r)
            rad = r.height;
        end 
    end
    
    methods
        function obj = CircleTarget(xc, yc, radius)
            obj = obj@OvalTarget(xc, yc, radius*2, radius*2);
        end
    end
end

