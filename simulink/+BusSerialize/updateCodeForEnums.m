function updateCodeForEnums(enumNames)
% loop through buses and update all code associated with them

if ischar(enumNames)
    enumNames = {enumNames};
end

for i = 1:numel(enumNames)
    BusSerialize.writeEnumToStringCode(enumNames{i});
    BusSerialize.writeStringToEnumCode(enumNames{i});
end