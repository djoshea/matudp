function str = ipStringFromAddress(vec)
    if ischar(vec)
        str = vec;
    else
        assert(numel(vec) == 4, 'Must be vector'); 
        str = sprintf('%d.%d.%d.%d', vec(1), vec(2), vec(3), vec(4));
    end
end