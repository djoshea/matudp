function [im X Y contourX contourY f] = buildEllipseImage(varargin)
p = inputParser;
p.addParamValue('theta', 0, @isscalar);
p.addParamValue('area', 1, @(x) isscalar(x) && x >= 0);
p.addParamValue('ecc', 0, @(x) isscalar(x) && 0 <= x && x < 1);
% how many sigma out to draw contourX/Y
p.addParamValue('contourFactor', 2, @(x) isscalar(x) && x > 0);
% how many sigma out to generate the image
p.addParamValue('contourImageSize', 3, @(x) isscalar(x) && x > 0);
p.addParamValue('showPlot', true, @islogical);
p.addParamValue('spacing', 0.01, @(x) isscalar(x) && x > 0);
p.addParamValue('contourPoints', 300, @(x) isscalar(x) && x > 0);
p.addParamValue('buildImage', true, @islogical);
p.parse(varargin{:});

A = 1;
theta = p.Results.theta;
area = p.Results.area;
ecc = p.Results.ecc;
contourFactor = p.Results.contourFactor;
contourImageSize = p.Results.contourImageSize;
showPlot = p.Results.showPlot;
spacing = p.Results.spacing;
contourPoints = p.Results.contourPoints;
buildImage = p.Results.buildImage;

x0 = 0;
y0 = 0;

% calculate major / minor axes given size and eccentricity
S = area / pi;
sx = sqrt(S*sqrt(1-ecc^2));
sy = S/sx;

major = max([sx sy]);
minor = min([sx sy]);

sx = major;
sy = minor;

% elements of covariance matrix = [a b; b c]
% see http://en.wikipedia.org/wiki/Gaussian_function#Two-dimensional_Gaussian_function
a = cos(theta)^2 / (2*sx^2) + sin(theta)^2 / (2*sy^2);
b = sin(2*theta)/(4*sx^2) - sin(2*theta) / (4*sy^2);
c = sin(theta)^2 / (2*sx^2) + cos(theta)^2 / (2*sy^2);

% contour paramatric functions at sigma * contourFactor

fx = @(contourFactor, t) contourFactor*(major*cos(t)*cos(theta) - minor*sin(t)*sin(theta)) + x0;
fy = @(contourFactor, t) contourFactor*(major*cos(t)*sin(theta) + minor*sin(t)*cos(theta)) + y0;

if buildImage
    % normal pdf for computing image
    f = @(X, Y) A*exp(-(a.*(X-x0).^2 + 2.*b.*(X-x0).*(Y-y0) + c.*(Y-y0).^2));

    % calculate bounding box at contourFactor*sigma
    xExt = atan(-minor * tan(theta) / major) + [0 pi];
    xMin = min(fx(contourImageSize, xExt));
    xMax = max(fx(contourImageSize, xExt));

    yExt = atan(minor * cot(theta) / major) + [0 pi];
    yMin = min(fy(contourImageSize, yExt));
    yMax = max(fy(contourImageSize, yExt));

    % generate image
    [X Y] = ndgrid(xMin:spacing:xMax, yMin:spacing:yMax);
    im = f(X, Y);
    
    thresh = exp(-((contourImageSize)^2) / 2);
    im(im < thresh) = 0;
    
else
    X = [];
    Y = [];
    im = [];
end

% generat contours
t = linspace(0, 2*pi, contourPoints);
contourX = fx(contourFactor, t);
contourY = fy(contourFactor, t);

if showPlot
    cmapGreen = zeros(1000, 3);
    cmapGreen(:,2) = linspace(0,1, size(cmapGreen,1));
    
    cmapRed = zeros(1000, 3);
    cmapRed(:,1) = linspace(0,1, size(cmapRed,1));
    colormap(cmapRed);
    
    % show image with contour superimposed
    figure(1), clf;
    set(gcf, 'MenuBar', 'none', 'ToolBar', 'none', 'Color', [0 0 0], ...
        'NumberTitle', 'off', 'Name', 'Oriented Ellipse');
    fs = [xMax-xMin yMax-yMin];
    fs = fs ./ prod(fs) * 100;
    %figsize(fs(2), fs(1));
    
    h = pcolor(X, Y, im);
    set(h, 'EdgeColor', 'none');
    hold on
    plot(fx(2, t), fy(2, t), 'w-', 'LineWidth', 1);
    %plot(contourX, contourY, 'w-');
%     plot([xMin xMin], [yMin yMax], 'r-');
%     plot([xMax xMax], [yMin yMax], 'r-');
%     plot([xMin xMax], [yMin yMin], 'r-');
%     plot([xMin xMax], [yMax yMax], 'r-');
    box off

    xMargin = 0.0*(xMax-xMin);
    yMargin = 0.0*(yMax-yMin);
    xlim([xMin-xMargin xMax+xMargin])
    ylim([yMin-yMargin yMax+yMargin])
    
    set(gcf, 'WindowButtonMotionFcn', @mouseMoveFn);
    set(get(gca, 'Children'), 'HitTest', 'off');
    title('Ellipse');
     
    axis equal;
    axis tight;
    axis off;
    drawnow;

%      figure(2), clf;
%      set(gcf, 'MenuBar', 'none', 'ToolBar', 'none');
%      r = double(insideContour(X, Y, 2));
%      h = pcolor(X, Y, r);
%      set(h, 'EdgeColor', 'none');
%      hold on
%      plot(fx(2, t), fy(2, t), 'w-', 'LineWidth', 1);
%      box off;
%      xlim([xMin-xMargin xMax+xMargin])
%      ylim([yMin-yMargin yMax+yMargin])
%      axis equal;
%      drawnow;
     
end

function tf = insideContour(x, y, threshFactor)
    thresh = A*exp(-threshFactor^2 / 2);
    vals = f(x, y);
    
    tf = false(size(x));
    tf(vals > thresh) = true;     
end
    

function mouseMoveFn(src, event)
    pt = get(gca, 'CurrentPoint');
    x = pt(1,1);
    y = pt(1,2);
    if insideContour(x, y, 2)
        str = 'Inside Ellipse!';
        colormap(cmapGreen);
    else
        str = 'Outside Ellipse';
        colormap(cmapRed);
    end
    title(sprintf('[%.2f, %.2f] %s', x, y, str));
end

end


