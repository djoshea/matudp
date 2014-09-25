function addBlockSafe(bSrc, bDest, varargin)
% calls add_block(...) if bDest does not exist, otherwise calls set_param
% to ensure the properties are set correctly

if ~blockExists(bDest)
    add_block(bSrc, bDest, varargin{:});
else
    if length(varargin) > 1
        setBlockParam(bDest, varargin{:});
    end
end

end