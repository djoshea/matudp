function name = getBlockNameFromHandle(hBlock)
    name = getfullname(hBlock);
    % correct odd issue with newlines appearing instead of spaces
    name(name == char(10)) = char(32);
end
