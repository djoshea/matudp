function x = makecol(x)
    if isvector(x) && size(x, 2) > size(x, 1)
        x = x';
    end
end