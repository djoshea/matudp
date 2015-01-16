classdef RectangleGradientTarget < ScreenObject

    properties
        filled = false;
        acquired = false;
        successful = false;
        dimTo = 1;
        flyingAway = false;
        vibrating = false;

        % when vibrating
        vibrateSigma = 10;

        % used for flying away
        xOffset = 0;
        yOffset = 0;
        flyFromX = 0;
        flyFromY = 0;
        flyVelocity = 3;
    end

    properties
        % center coordinates in ux
        xc 
        yc

        % if theta is 0, width is horizontal, rotates CCW in radians
        theta = 0;
        width
        depth

        contourColor
        contourWidth = 1;
    end

    properties
        % contour points
        pointsX
        pointsY
        
        texDestRect % destination rectangle for texture, without center offset
        
        % texture pointers
        texPtrNormal % texture pointer
        texPtrAcquired % texture pointer
        texPtrSuccess % texture pointer
        pendingUpdateTexture;
    end

    methods 
        function contour(r)
            r.filled = false;
        end

        function normal(r)
            r.filled = true;
            r.acquired = false;
            r.successful = false;
            r.dimTo = 1;
            r.flyingAway = false;
            r.vibrating = false;
        end

        function fill(r)
            r.filled = true;
        end

        function acquire(r)
            r.acquired = true;
        end

        function dim(r, to)
            if nargin < 2
                to = 0.5;
            end
            r.dimTo = to;
        end

        function undim(r)
            r.dimTo = 1;
        end

        function unacquire(r)
            r.acquired = false;
        end

        function success(r)
            r.successful = true;
        end

        function flyAway(r, fromX, fromY)
            r.flyingAway = true;
            r.filled = false;

            if ~exist('fromX', 'var')
                fromX = 0;
            end
            if ~exist('fromY', 'var')
                fromY = 0;
            end
            r.flyFromX = fromX;
            r.flyFromY = fromY;
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
        function obj = RectangleGradientTarget()
            obj.xc = 0;
            obj.yc = 0;
            obj.width = 0;
            obj.theta = 0;
            obj.depth = 0;
            obj.pendingUpdateTexture = true;
        end 
        
        function str = describe(r)
            str = sprintf('(%g, %g) width %g, depth %g, theta %g', ...
                r.xc, r.yc, r.width, r.depth, r.theta);
        end

        function update(r, mgr, sd)
            if r.pendingUpdateTexture || isempty(r.pointsX)
                
                % don't pass theta along here, we'll rotate the texture
                % using DrawTexture
                [im, X, Y] = buildRectangleGradientImage('theta', 0, ...
                    'width', r.width, 'depth', r.depth, 'spacing', 0.5); 
                im = flipud(im);

                % normal: darker green (actually same bright green)
                normalImage = zeros([size(im) 4]);
                normalImage(:,:,2) = im * sd.cMax;
                normalImage(:,:,4) = 1 * (im > 0);

                % acquired image: bright green 
                acqImage = zeros([size(im) 4]);
                acqImage(:,:,2) = im * sd.cMax;
                acqImage(:,:,4) = 1 * (im > 0);

                % success image: white
                successImage = repmat(im * sd.cMax, [1 1 4]);
                successImage(:,:,4) = 1 * (im > 0);

                minX = min(X(:));
                maxX = max(X(:));
                minY = min(Y(:));
                maxY = max(Y(:));
                r.texDestRect = [minX minY maxX maxY];

                if ~isempty(r.texPtrNormal)
                    sd.clearTexture(r.texPtrNormal);
                end
                r.texPtrNormal = sd.makeTexture(normalImage);

                if ~isempty(r.texPtrAcquired)
                    sd.clearTexture(r.texPtrAcquired);
                end
                r.texPtrAcquired = sd.makeTexture(acqImage);

                if ~isempty(r.texPtrSuccess)
                    sd.clearTexture(r.texPtrSuccess);
                end
                r.texPtrSuccess = sd.makeTexture(successImage);

                r.pendingUpdateTexture = false;
            end
            
            % update these always in case they're changing
            [r.pointsX, r.pointsY] = buildRectanglePoints('theta', r.theta, ...
                'width', r.width, 'depth', r.depth);

            if r.flyingAway
                % advance the offsets to make the target fly away
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
                    r.state = r.STATE_NORMAL;
                    r.hide(); 
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
            drawCenter = false;
            drawTexture = r.filled;
            drawContour = ~r.filled;
            
            if r.successful
                texPtr = r.texPtrSuccess;
            elseif r.acquired
                texPtr = r.texPtrAcquired;
            else
                texPtr = r.texPtrNormal;
            end
            
            if drawTexture
                % auto update when width / height changes
                destRect = r.texDestRect;
                destRect(3) = destRect(1) + r.width;
                destRect(4) = destRect(2) + r.depth;
                destRect([1 3]) = destRect([1 3]) + r.xc + r.xOffset;
                destRect([2 4]) = destRect([2 4]) + r.yc + r.yOffset;
                %drawTexture(textureIndex, rect, angle, filterMode, globalAlpha, modulateColor)
                sd.drawTexture(texPtr, destRect, r.theta, [], r.dimTo);
            end
            
            if drawContour || drawCenter
                state = sd.saveState(); 

                if isempty(r.contourColor)
                    r.contourColor = sd.white;
                end
                sd.penColor = r.contourColor;
                sd.fillColor = r.contourColor;
                sd.penWidth = r.contourWidth;
                if drawContour
                    sd.drawPoly(r.pointsX + r.xc + r.xOffset, r.pointsY + r.yc + r.yOffset);
                end

                if drawCenter
                    sd.fillColor = [1 1 1];
                    sd.penColor = [1 1 1];
                    sd.drawCircle(r.xc + r.xOffset, r.yc + r.yOffset, r.centerDotRadius, true);
                end

                sd.restoreState(state);
            end

        end
    end

    methods % Set access to auto-update textures
        function set.width(r, width)
            if isempty(r.width) || r.width ~= width
                r.width = width;
                r.pendingUpdateTexture = true;
            end
        end

        function set.depth(r, depth)
            if isempty(r.depth) || r.depth ~= depth
                r.depth = depth;
                r.pendingUpdateTexture = true;
            end
        end

        function set.theta(r, theta)
            if isempty(r.theta) || r.theta ~= theta 
                r.theta = theta;
                r.pendingUpdateTexture = true;
            end
        end
    end

end

