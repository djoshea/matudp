function [im X Y px py] = buildRectangleGradientImage(varargin)
    p = inputParser;
    p.addParamValue('theta', 0, @isscalar);
    p.addParamValue('depth', 1, @(x) isscalar(x) && x >= 0);
    p.addParamValue('width', 1, @(x) isscalar(x) && x >= 0);
    p.addParamValue('spacing', 0.01, @(x) isscalar(x) && x > 0);
    p.parse(varargin{:});

    theta = p.Results.theta;
    depth = p.Results.depth;
    width= p.Results.width;
    spacing = p.Results.spacing;

    x0 = 0;
    y0 = 0;

    rot = [cos(theta), -sin(theta); sin(theta), cos(theta)];
    c = rot * [-width/2 width/2 width/2 -width/2; ...
               -depth/2 -depth/2 depth/2 depth/2 ];

    px = c(1, :); 
    py = c(2, :);

    [im, X, Y] = buildObstaclePolygonImage(px, py, 'spacing', spacing);
end
