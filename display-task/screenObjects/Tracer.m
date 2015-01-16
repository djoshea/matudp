classdef Tracer < ScreenObject

    properties
        xc
        yc
        xv
        yv
        color
        radius = 2;
        acc = [0 -.10];
    end

    methods
        function obj = Tracer(xc, yc, xv, yv)
            obj.xc = xc;
            obj.yc = yc;
            obj.xv = xv;
            obj.yv = yv;
        end

        function str = describe(r)
            str = sprintf('Tracer : (%g by %g, %g by %g)', ...
                r.xc, r.xv, r.yc, r.yv);
        end

        function update(r, mgr, sd);
            % acceleration
            r.xv = r.xv + r.acc(1);
            r.yv = r.yv + r.acc(2);

            % velocity 
            r.xc = r.xc + r.xv;
            r.yc = r.yc + r.yv;

            if r.xc > sd.xMax || r.xc < sd.xMin || r.yc > sd.yMax || r.yc < sd.yMin
                %mgr.remove(r);
                delete(r);
            end
        end

        function draw(r, sd)
            state = sd.saveState(); 
            sd.penColor = r.color;
            sd.fillColor = r.color;
            sd.drawRect(r.xc-r.radius/2, r.yc-r.radius/2, r.xc+r.radius/2, r.yc+r.radius/2, true); 
            sd.restoreState(state);
        end
       
    end

end

