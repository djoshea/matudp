function [x, y, width, height] = getBlockPosition(block)
% [x, y, width, height] = getBlockPosition(block)
% Gets a block's x,y position and width and height

if blockExists(block)
    pos = get_param(block, 'Position');
    x = pos(1);
    y = pos(2);
    width = pos(3) - pos(1);
    height = pos(4) - pos(2);
else
    x = NaN;
    y = NaN;
    width = NaN;
    height = NaN;
end

end
