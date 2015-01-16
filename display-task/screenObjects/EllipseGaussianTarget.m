classdef EllipseGaussianTarget < ScreenObject
% A target defined by a 2-sigma contour around a multivariate normal distribution
% It is parameterized by a center (x0,y0), an area, and an eccentricity in the 
% interval [0,1) where 0 is a circle and -->1 approaches a line
% 

    properties(Constant)
        STATE_CONTOUR = 1;
        STATE_NORMAL = 2;
        STATE_ACQUIRED = 3;
        STATE_SUCCESS = 4;
        STATE_FLYING_AWAY = 5;
        STATE_DIM = 6;
    end

    properties
        vibrating
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

        % ellipse geometry
        ecc % eccentricity [0 = circle, 1 = line)
        radius % radius of circle with equivalent area to 2-sigma contour
        theta % ccw angle from positive x axis

        centerRadius = 1.5;

        contourColor
        contourWidth = 1;
       
        centerDotRadius = 1;
    end

    properties
        state

        % contour points
        contourX
        contourY
        
        texDestRect % destination rectangle for texture, without center offset
        
        % texture pointers
        texPtrNormal % texture pointer
        texPtrAcquired % texture pointer
        texPtrDim % texture pointer
        texPtrSuccess % texture pointer
        pendingUpdateTexture;
    end

    methods 
        function contour(r)
            r.state = EllipseGaussianTarget.STATE_CONTOUR;
        end

        function normal(r)
            r.state = EllipseGaussianTarget.STATE_NORMAL;
        end

        function acquire(r)
            r.state = EllipseGaussianTarget.STATE_ACQUIRED;
        end

        function dim(r)
            r.state = EllipseGaussianTarget.STATE_DIM;
        end

        function unacquire(r)
            r.state = EllipseGaussianTarget.STATE_NORMAL;
        end

        function success(r)
            r.state = EllipseGaussianTarget.STATE_SUCCESS;
        end

        function flyAway(r, fromX, fromY)
            r.state = EllipseGaussianTarget.STATE_FLYING_AWAY;
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
        function obj = EllipseGaussianTarget()
            obj.xc = 0;
            obj.yc = 0;
            obj.ecc = 0;
            obj.theta = 0;
            obj.radius = 1;
            obj.pendingUpdateTexture = true;
            obj.state = EllipseGaussianTarget.STATE_CONTOUR; 
        end 
        
        function str = describe(r)
            str = sprintf('(%g, %g) radius %g, ecc %g, theta %g', ...
                r.xc, r.yc, r.radius, r.ecc, r.theta);
        end

        function update(r, mgr, sd)
            if r.pendingUpdateTexture
                area = r.radius^2 * pi; % area of equivalent circle with radius radius
                [im X Y contourX contourY] = buildEllipseImage('ecc', r.ecc, 'theta', r.theta, ...
                    'area', area, 'spacing', 0.2, 'showPlot', false, 'contourPoints', 300, ...
                    'contourFactor', 1, 'contourImageSize', 2.5);

                im = flipud(im);
                
                % store contour outlines
                r.contourX = contourX;
                r.contourY = contourY;

                % normal: darker green (actually same bright green)
                normalImage = zeros([size(im) 4]);
                normalImage(:,:,2) = im * sd.cMax;
                normalImage(:,:,4) = 1 * (im > 0);

                % acquired image: bright green 
                acqImage = zeros([size(im) 4]);
                acqImage(:,:,2) = im * sd.cMax;
                acqImage(:,:,4) = 1 * (im > 0);

                % dimmed image: dull green 
                dimImage = zeros([size(im) 4]);
                dimImage(:,:,2) = im * sd.cMax;
                dimImage(:,:,4) = 0.5 * (im > 0);

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

                if ~isempty(r.texPtrDim)
                    sd.clearTexture(r.texPtrDim);
                end
                r.texPtrDim = sd.makeTexture(dimImage);

                if ~isempty(r.texPtrSuccess)
                    sd.clearTexture(r.texPtrSuccess);
                end
                r.texPtrSuccess = sd.makeTexture(successImage);

                r.pendingUpdateTexture = false;
            end

            if r.state == r.STATE_FLYING_AWAY
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
                    r.state == STATE_NORMAL;
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
            drawContour = false;
            drawTexture = false;
            drawCenter = true;

            switch r.state
                case EllipseGaussianTarget.STATE_CONTOUR
                    drawContour = true;
                    drawCenter = true;

                case EllipseGaussianTarget.STATE_NORMAL
                    drawTexture = true;
                    drawCenter = true;
                    texPtr = r.texPtrNormal;
                   
                case EllipseGaussianTarget.STATE_ACQUIRED
                    drawTexture = true;
                    drawCenter = true;
                    texPtr = r.texPtrAcquired;

                case EllipseGaussianTarget.STATE_DIM
                    drawTexture = true;
                    drawCenter = true;
                    texPtr = r.texPtrDim;
                    
                case EllipseGaussianTarget.STATE_SUCCESS
                    drawTexture = true;
                    drawCenter = true;
                    texPtr = r.texPtrSuccess;

                case EllipseGaussianTarget.STATE_FLYING_AWAY
                    drawContour = true;
                    drawCenter = false;
            end
            
            if drawTexture
                destRect = r.texDestRect;
                destRect([1 3]) = destRect([1 3]) + r.xc + r.xOffset;
                destRect([2 4]) = destRect([2 4]) + r.yc + r.yOffset;
                sd.drawTexture(texPtr, destRect);
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
                    sd.drawPoly(r.contourX + r.xc + r.xOffset, r.contourY + r.yc + r.yOffset);
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
        function set.ecc(r, ecc)
            if isempty(r.ecc) || r.ecc ~= ecc
                r.ecc = ecc;
                r.pendingUpdateTexture = true;
            end
        end

        function set.theta(r, theta)
            if isempty(r.theta) || r.theta ~= theta 
                r.theta = theta;
                r.pendingUpdateTexture = true;
            end
        end

        function set.radius(r, radius)
            if isempty(r.radius) || r.radius ~= radius 
                r.radius = radius;
                r.pendingUpdateTexture = true;
            end
        end
    end

end

