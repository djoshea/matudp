function [str, valid] = enumToString_TestEnum(enumValue)
%#codegen
% DO NOT EDIT: Auto-generated by 
%   BusSerialize.writeEnumToStringModelPackagedCode('testBusArray', 'TestEnum')

    valid = uint8(1);
    coder.varsize('str', [1 9], [false true]);
    switch enumValue
        case TestEnum.val1
            str = uint8('val1');
        case TestEnum.value2
            str = uint8('value2');
        case TestEnum.val3_long
            str = uint8('val3_long');
        otherwise
            str = uint8('val1');
            valid = uint8(0);
    end
end