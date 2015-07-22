function [im, X, Y] = buildObstaclePolygonImage(px, py, varargin)

p = inputParser;
p.addParamValue('spacing', 0.2, @isscalar);
p.parse(varargin{:});

spacing = p.Results.spacing;
minX = min(px);
maxX = max(px);
minY = min(py);
maxY = max(py);

%x = minX-spacing:spacing:maxX+spacing;
%y = minY-spacing:spacing:maxY+spacing;

nPoints = ceil((maxX-minX) / spacing + 1);
x = linspace(minX, maxX, nPoints);
nPoints = ceil((maxY-minY) / spacing + 1);
y = linspace(minY, maxY, nPoints);
nx = numel(x);
ny = numel(y);

[X Y] = ndgrid(x,y);

pxShift = (px - minX)/spacing;
pyShift = (py - minY)/spacing;
im = flipud(poly2mask(pxShift, pyShift, ny, nx));


end
