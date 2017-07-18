classdef FullField < Rectangle
    
    methods
        function r = FullField()
            r = r@Rectangle(0,0,200,200);
            r.fill = true;
            r.fillColor = [1 1 1];
            r.borderWidth = 0;
            r.hide();
        end
        
        function str = describe(r)
            str = sprintf('FullField');
        end

        function update(r, mgr, sd)
            update@Rectangle(r, sd);
        end
        
        function draw(r, sd)
            draw@Rectangle(r, sd);
        end
    end
end
