function enumName = parseEnumDataTypeStr(enumStr)
% given a string like 'Enum: EnumType', returns 'EnumType'
% if enumStr is not a valid enum identifier string, returns ''

enumName = regexp(enumStr, 'Enum: (?<enumName>[^ ]+)', 'tokens', 'once');
if isempty(enumName)
    enumName = '';
else
    enumName = enumName{1};
end

end
