function outSize = getSerializedBusLength_TestBusOuter(bus)
%#codegen
% DO NOT EDIT: Auto-generated by 
%   writeGetSerializedBusLengthModelPackagedCode('testDataLogger', 'TestBusOuter')

    outSize = uint16(0);
    % element val1
    outSize = outSize + uint16(1); % bit flags
    outSize = outSize + uint16(1); % signal type
    outSize = outSize + uint16(1); % concatenation dimension
    outSize = outSize + uint16(2 + 4); % for name
    outSize = outSize + uint16(2 + 2); % for units
    outSize = outSize + uint16(1); % for data type id
    outSize = outSize + uint16(1 + 2*1); % for dimensions
    outSize = outSize + uint16(1 * numel(bus.val1)); % for val1 data 

    % element val2
    outSize = outSize + uint16(1); % bit flags
    outSize = outSize + uint16(1); % signal type
    outSize = outSize + uint16(1); % concatenation dimension
    outSize = outSize + uint16(2 + 4); % for name
    outSize = outSize + uint16(2 + 4); % for units
    outSize = outSize + uint16(1); % for data type id
    outSize = outSize + uint16(1 + 2*1); % for dimensions
    outSize = outSize + uint16(1 * numel(bus.val2)); % for val2 data 

    % element nested
    outSize = outSize + uint16(testDataLoggerLib.getSerializedBusLength_TestBusInner(bus.nested(1))); % for nested nested bus


end