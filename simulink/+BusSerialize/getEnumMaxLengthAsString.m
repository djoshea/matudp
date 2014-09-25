function maxLen = getEnumMaxLengthAsString(enumName)
% get the maximum length of each enum's members as strings

    vals = BusSerialize.getEnumAsValueStruct(enumName);
    lens = cellfun(@numel, fieldnames(vals));
    maxLen = max(lens);
    
end
    
    
    