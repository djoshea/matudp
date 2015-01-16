classdef Target < Rectangle 
% 
% 
    properties
        vibrating
        vibrateSigma;
        xOffset = 0;
        yOffset = 0;

        flyingAway = false;
        flyFromX
        flyFromY
        flyVelocity = 20;
    end

    properties(Dependent)
        x1o
        x2o
        y1o
        y2o
    end

    methods
        function obj = Target(xc, yc, width, height)
            obj = obj@Rectangle(xc,yc,width,height);
            obj.vibrateSigma = 5;
        end
        
        %         
        function str = describe(r)
            if r.fill
                fillStr = 'filled';
            else
                fillStr = 'unfilled';
            end
            if r.vibrating
                vibrateStr = 'vibrating';
            else
                vibrateStr = 'stationary';
            end
            if r.flyingAway
                flyStr = sprintf('flying from (%d, %d)', r.flyFromX, r.flyFromY);
            else
                flyStr = 'not flying';
            end
            str = sprintf('(%g, %g) size %g x %g, %s, %s, %s', ...
                r.xc, r.yc, r.width, r.height, fillStr, vibrateStr, flyStr);
        end

        function vibrate(r, sigma)
            if nargin >= 2
                r.vibrateSigma = sigma;
            end
            r.vibrating = true;
        end

        function stopVibrating(r)
            r.vibrating = false;
        end

        function flyAway(r, fromX, fromY)
            if ~exist('fromX', 'var')
                fromX = 0;
            end
            if ~exist('fromY', 'var')
                fromY = 0;
            end
            r.vibrating = false;
            r.flyingAway = true;
            r.flyFromX = fromX;
            r.flyFromY = fromY;
        end

        function x1 = get.x1o(r)
            x1 = r.xc + r.xOffset - r.width/2;
        end

        function y1 = get.y1o(r)
            y1 = r.yc + r.yOffset - r.height/2;
        end

        function x2 = get.x2o(r)
            x2 = r.xc + r.xOffset + r.width/2;
        end

        function y2 = get.y2o(r)
            y2 = r.yc + r.yOffset + r.height/2;
        end

        function tf = getIsOffScreen(r, sd)
            tf = false;
            tf = tf || max([r.x1o r.x2o]) < sd.xMin;
            tf = tf || min([r.x1o r.x2o]) > sd.xMax;
            tf = tf || max([r.y1o r.y1o]) < sd.yMin;
            tf = tf || min([r.y1o r.y2o]) > sd.yMax;
        end

        function update(r, mgr, sd)
            if r.vibrating
                r.xOffset = r.vibrateSigma * randn(1);
                r.yOffset = r.vibrateSigma * randn(1);
            else
                if r.flyingAway
                    deltaX = r.xc + r.xOffset - r.flyFromX;
                    deltaY = r.yc + r.yOffset - r.flyFromY;

                    if deltaX == 0 && deltaY == 0
                        ang = 2*pi*rand(1);
                        deltaX = cos(ang);
                        deltaY = sin(ang);
                    end

                    deltaVec = [deltaX deltaY] / norm([deltaX deltaY]) * r.flyVelocity;

                    r.xOffset = r.xOffset + deltaVec(1);
                    r.yOffset = r.yOffset + deltaVec(2);

                    if r.getIsOffScreen(sd)
                        r.flyingAway = false;
                        r.hide(); 
                    end
                else
                    r.xOffset = 0;
                    r.yOffset = 0;
                end
            end
        end

        function draw(r, sd)
            state = sd.saveState(); 
            sd.penColor = r.color;
            sd.fillColor = r.fillColor;
            sd.penWidth = r.borderWidth;
            sd.drawRect(r.x1o, r.y1o, r.x2o, r.y2o, r.fill); 
            sd.restoreState(state);
        end
       
    end

end

