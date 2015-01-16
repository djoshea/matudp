function x = makerow(x)
    if isvector(x) && size(x, 1) > size(x, 2)
        x = x';
    end
end