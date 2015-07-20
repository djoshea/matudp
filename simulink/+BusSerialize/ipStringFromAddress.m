function str = ipStringFromAddress(vec)
    if ischar(vec)
        str = vec;
    elseif isscalar(vec)
        r = vec;
        v1 = floor(r / 16777216);
        r = r - v1 * 16777216;
        v2 = floor(r / 65536);
        r = r - v2 * 65536;
        v3 = floor(r / 256);
        r = r - v3 * 256;
        v4 = r;
        str = sprintf('%d.%d.%d.%d', v1, v2, v3, v4);
    else
        assert(numel(vec) == 4, 'Input must be char, scalar, or vector'); 
        str = sprintf('%d.%d.%d.%d', vec(1), vec(2), vec(3), vec(4));
    end
end