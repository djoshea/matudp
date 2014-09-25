function setBlockPosition(block, x, y, width, height)
% sets a block's width and height. If any parameter is specified as NaN or
% not provided, keeps the existing value for that size dimension.

if blockExists(block)
    posOrig = get_param(block, 'Position');
    pos = posOrig;
    
    if ~exist('width', 'var') || isnan(width)
        width = pos(3) - pos(1);
    end
    if ~exist('height', 'var') || isnan(height)
        height = pos(4) - pos(2);
    end
    
    if ~isnan(x)
        pos(1) = x;
    end
    if ~isnan(y)
        pos(2) = y;
    end
   
    pos(3) = pos(1) + width;
    pos(4) = pos(2) + height;
    
    % allow for some small deviations as this isn't critical and happens
    % spontaneously in simulink
    if max(abs(pos - posOrig)) > 5
        setBlockParam(block, 'Position', pos);
    end
end

