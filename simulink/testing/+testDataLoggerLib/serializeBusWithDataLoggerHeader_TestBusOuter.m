function [out, valid] = serializeBusWithDataLoggerHeader_TestBusOuter(bus, groupType, groupName, timestamp)
%#codegen
% DO NOT EDIT: Auto-generated by 
%   BusSerialize.writeSerializeBusModelPackagedCode('testDataLogger', 'TestBusOuter')

    valid = uint8(0);
    headerLength = uint16(BusSerialize.computeDataLoggerHeaderLength(groupName));
    outSize = headerLength + testDataLoggerLib.getSerializedBusLength_TestBusOuter(bus);
    out = zeros(outSize, 1, 'uint8');
    offset = uint16(1);

    % Serialize data logger header
    header = BusSerialize.serializeDataLoggerHeader(groupType, groupName, uint32(1818341479), uint16(5), timestamp);
    out(1:headerLength) = uint8(header);
    offset = offset + headerLength;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Serialize fixed-sized val1
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % val1 bitFlags
    if(offset > numel(out)), return, end
    out(offset) = uint8(0);
    offset = offset + uint16(1);

    % val1 signal type
    if(offset > numel(out)), return, end
    out(offset) = uint8(4);
    offset = offset + uint16(1);

    % val1 concatenation dimension
    if(offset > numel(out)), return, end
    out(offset) = uint8(0);
    offset = offset + uint16(1);

    % val1 bitFlags
    if(offset > numel(out)), return, end
    out(offset) = uint8(0);

    % val1 name
    if(offset+uint16(2+4 -1) > numel(out)), return, end
    out(offset:(offset+uint16(1))) = typecast(uint16(4), 'uint8');
    offset = offset + uint16(2);
    out(offset:(offset+uint16(4-1))) = uint8('val1');
    offset = offset + uint16(4);

    % val1 units
    if(offset+uint16(2+2 -1) > numel(out)), return, end
    out(offset:(offset+uint16(1))) = typecast(uint16(2), 'uint8');
    offset = offset + uint16(2);
    out(offset:(offset+uint16(2-1))) = uint8('AU');
    offset = offset + uint16(2);

    % val1 data type id
    if(offset > numel(out)), return, end
    out(offset) = uint8(3); % data type is uint8
    offset = offset + uint16(1);

    % val1 dimensions
    if(offset > numel(out)), return, end
    if(offset+uint16(1+2*1-1) > numel(out)), return, end
    out(offset) = uint8(1);
    offset = offset + uint16(1);
    out(offset:(offset+uint16(2*1-1))) = typecast(uint16(numel(bus.val1)), 'uint8');
    offset = offset + uint16(2*1);

    % val1 data
    nBytes = uint16(1 * numel(bus.val1));
    if(offset+uint16(nBytes-1) > numel(out)), return, end
    if ischar(bus.val1) || islogical(bus.val1)
        out(offset:(offset+uint16(nBytes-1))) = typecast(uint8(bus.val1(:)), 'uint8');
    else
        out(offset:(offset+uint16(nBytes-1))) = typecast(bus.val1(:), 'uint8');
    end
    offset = offset + nBytes;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Serialize fixed-sized val2
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % val2 bitFlags
    if(offset > numel(out)), return, end
    out(offset) = uint8(0);
    offset = offset + uint16(1);

    % val2 signal type
    if(offset > numel(out)), return, end
    out(offset) = uint8(4);
    offset = offset + uint16(1);

    % val2 concatenation dimension
    if(offset > numel(out)), return, end
    out(offset) = uint8(0);
    offset = offset + uint16(1);

    % val2 bitFlags
    if(offset > numel(out)), return, end
    out(offset) = uint8(0);

    % val2 name
    if(offset+uint16(2+4 -1) > numel(out)), return, end
    out(offset:(offset+uint16(1))) = typecast(uint16(4), 'uint8');
    offset = offset + uint16(2);
    out(offset:(offset+uint16(4-1))) = uint8('val2');
    offset = offset + uint16(4);

    % val2 units
    if(offset+uint16(2+4 -1) > numel(out)), return, end
    out(offset:(offset+uint16(1))) = typecast(uint16(4), 'uint8');
    offset = offset + uint16(2);
    out(offset:(offset+uint16(4-1))) = uint8('char');
    offset = offset + uint16(4);

    % val2 data type id
    if(offset > numel(out)), return, end
    out(offset) = uint8(8); % data type is char
    offset = offset + uint16(1);

    % val2 dimensions
    if(offset > numel(out)), return, end
    if(offset+uint16(1+2*1-1) > numel(out)), return, end
    out(offset) = uint8(1);
    offset = offset + uint16(1);
    out(offset:(offset+uint16(2*1-1))) = typecast(uint16(numel(bus.val2)), 'uint8');
    offset = offset + uint16(2*1);

    % val2 data
    nBytes = uint16(1 * numel(bus.val2));
    if(offset+uint16(nBytes-1) > numel(out)), return, end
    if ischar(bus.val2) || islogical(bus.val2)
        out(offset:(offset+uint16(nBytes-1))) = typecast(uint8(bus.val2(:)), 'uint8');
    else
        out(offset:(offset+uint16(nBytes-1))) = typecast(bus.val2(:), 'uint8');
    end
    offset = offset + nBytes;

    % val2 nested bus element(1)
    nestedBytes = uint16(testDataLoggerLib.getSerializedBusLength_TestBusInner(bus.nested(1)));
    out(offset:(offset+nestedBytes-uint16(1))) = testDataLoggerLib.serializeBus_TestBusInner(bus.nested(1));
    offset = offset + nestedBytes;  %#ok<NASGU>

    valid = uint8(1);
end