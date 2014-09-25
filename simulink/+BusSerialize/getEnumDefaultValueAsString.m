function defString = getEnumDefaultValueAsString(enumName)
% get the default value for enum as a char array

    defString = char(eval(sprintf('%s.getDefaultValue()', enumName)));
    
end
    
    
    