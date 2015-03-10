classdef PolygonObstacle < ScreenObject
% A target defined by a 2-sigma contour around a multivariate normal distribution
% It is parameterized by a center (x0,y0), an area, and an eccentricity in the 
% interval [0,1) where 0 is a circle and -->1 approaches a line
% 

    properties(Constant)
        STATE_CONTOUR = 1;
        STATE_NORMAL = 2;
        STATE_COLLISION = 3;
        STATE_FLYING_AWAY = 4;
        STATE_VIBRATING = 5;
    end

    properties
        % polygon vertices defining obstacle (do not close)
        pointsX
        pointsY

        % 3 x 1 color vectors
        fillColor
        fillColorCollision
        
        contourColor
        contourWidth = 5;

        vibrating = false;
        vibrateSigma = 10;

        % used for flying away
        xOffset = 0;
        yOffset = 0;
        flyFromX = 0;
        flyFromY = 0;
        flyVelocity = 3;
    end

    properties
        state

        texDestRect % destination rectangle for texture, without center offset
        
        % texture pointers
        texPtrNormal % texture pointer
        texPtrCollision % texture pointer
        
        pendingUpdateTexture; % boolean flag indicating whether update needed to texture
    end

    methods 
        function contour(r)
            r.state = PolygonObstacle.STATE_CONTOUR;
        end

        function normal(r)
            r.state = PolygonObstacle.STATE_NORMAL;
        end

        function collision(r)
            r.state = PolygonObstacle.STATE_COLLISION;
        end

        function flyAway(r, fromX, fromY)
            r.state = PolygonObstacle.STATE_FLYING_AWAY;
            if ~exist('fromX', 'var')
                fromX = 0;
            end
            if ~exist('fromY', 'var')
                fromY = 0;
            end
            r.xOffset = 0;
            r.yOffset = 0;
            r.flyFromX = fromX;
            r.flyFromY = fromY;
            r.stopVibrating();
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
    end

    methods % Screen object fns
        function obj = PolygonObstacle()
            
            obj.pendingUpdateTexture = true;
            obj.state = PolygonObstacle.STATE_CONTOUR; 
        end 
        
        function str = describe(r)
            str = sprintf('(%g, %g) radius %g, ecc %g, theta %g', ...
                r.xc, r.yc, r.radius, r.ecc, r.theta);
        end
        
        function update(r, mgr, sd)
            if r.pendingUpdateTexture && ~isempty(r.pointsX) && ~isempty(r.pointsY)
                % build polygon mask image
                [im, X, Y] = buildObstaclePolygonImage(r.pointsX, r.pointsY);

                im = flipud(im);
                
                % normal image: default to dark red
                if isempty(r.fillColorCollision)
                    fillColor= [sd.cMax/2 0 0];
                else
                    fillColor= r.fillColor;
                end
                
                % make 1x1x3 version of that color
                fillColor = shiftdim(fillColor(:), -2);
                normalImage = repmat(fillColor, [size(im) 1]) .* repmat(im, [1 1 3]);
                normalImage(:, :, 4) = 255*im;
                
                if isempty(r.fillColorCollision)
                    fillColorCollision= [sd.cMax 0 0];
                else
                    fillColorCollision= r.fillColorCollision;
                end
                
                % make 1x1x3 version of that color
                fillColorCollision = shiftdim(fillColorCollision(:), -2);
                collisionImage = repmat(fillColorCollision, [size(im) 1]) .* repmat(im, [1 1 3]);
                collisionImage(:, :, 4) = 255*im;
                
                % compute texture destination rectangle
                minX = min(X(:));
                maxX = max(X(:));
                minY = min(Y(:));
                maxY = max(Y(:));
                r.texDestRect = [minX minY maxX maxY];

                if ~isempty(r.texPtrNormal)
                    sd.clearTexture(r.texPtrNormal);
                end
                r.texPtrNormal = sd.makeTexture(normalImage);
                
                if ~isempty(r.texPtrCollision)
                    sd.clearTexture(r.texPtrCollision);
                end
                r.texPtrCollision = sd.makeTexture(collisionImage);

                r.pendingUpdateTexture = false;

            end

            % update flying away offset
            if r.state == r.STATE_FLYING_AWAY
                % advance the offsets to make the target fly away
                meanX = mean(r.pointsX);
                meanY = mean(r.pointsY);
                deltaX = meanX + r.xOffset - r.flyFromX;
                deltaY = meanY + r.yOffset - r.flyFromY;

                if deltaX == 0 && deltaY == 0
                    % fly in random direction if not specified
                    ang = 2*pi*rand(1);
                    deltaX = cos(ang);
                    deltaY = sin(ang);
                end

                deltaVec = [deltaX deltaY] / norm([deltaX deltaY]) * r.flyVelocity;

                r.xOffset = r.xOffset + deltaVec(1);
                r.yOffset = r.yOffset + deltaVec(2);

                if r.getIsOffScreen(sd)
                    r.hide();
                    r.xOffset = 0;
                    r.yOffset = 0;
                end

            elseif r.vibrating
                r.xOffset = r.vibrateSigma * randn(1);
                r.yOffset = r.vibrateSigma * randn(1);

            else
                r.xOffset = 0;
                r.yOffset = 0;
            end
        end

        function tf = getIsOffScreen(r, sd)
            tf = false;
            %tf = tf || max([r.x1o r.x2o]) < sd.xMin;
            %tf = tf || min([r.x1o r.x2o]) > sd.xMax;
            %tf = tf || max([r.y1o r.y1o]) < sd.yMin;
            %tf = tf || min([r.y1o r.y2o]) > sd.yMax;
        end

        function draw(r, sd)
            drawContour = false;
            drawTexture = false;

            switch r.state
                case {PolygonObstacle.STATE_CONTOUR, PolygonObstacle.STATE_FLYING_AWAY}
                    drawContour = true;

                case PolygonObstacle.STATE_NORMAL
                    drawTexture = true;
                    texPtr = r.texPtrNormal;
                    drawContour = true;

                case PolygonObstacle.STATE_COLLISION
                    drawTexture = true;
                    texPtr = r.texPtrCollision;
                    drawContour = true;
            end
            
            if drawTexture
                destRect = r.texDestRect;
                % offset by flyaway offset
                destRect([1 3]) = destRect([1 3]) + r.xOffset;
                destRect([2 4]) = destRect([2 4]) + r.yOffset;
                sd.drawTexture(texPtr, destRect);
            end
            
            if drawContour
                state = sd.saveState(); 

                if isempty(r.contourColor)
                    r.contourColor = sd.white;
                end
                sd.penColor = r.contourColor;
                sd.penWidth = r.contourWidth;
                if drawContour
                    % offset by flyaway offset
                    sd.drawPoly(r.pointsX + r.xOffset, r.pointsY + r.yOffset);
                end

                sd.restoreState(state);
            end

        end
    end

    methods % Set access to auto-update textures
        function set.pointsX(r, pointsX)
            if isempty(r.pointsX) || ~isequal(r.pointsX, pointsX)
                r.pointsX = pointsX;
                r.pendingUpdateTexture = true;
            end
        end
        
        function set.pointsY(r, pointsY)
            if isempty(r.pointsY) || ~isequal(r.pointsY, pointsY)
                r.pointsY = pointsY;
                r.pendingUpdateTexture = true;
            end
        end

        function set.fillColor(r, fillColor)
            if isempty(r.fillColor) || ~isequal(r.fillColor, fillColor)
                r.fillColor= fillColor;
                r.pendingUpdateTexture = true;
            end
        end
        
        function set.fillColorCollision(r, fillColorCollision)
            if isempty(r.fillColorCollision) || ~isequal(r.fillColorCollision, fillColorCollision)
                r.fillColorCollision = fillColorCollision;
                r.pendingUpdateTexture = true;
            end
        end
    end

end

