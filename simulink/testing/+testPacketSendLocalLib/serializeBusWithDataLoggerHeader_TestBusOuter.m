function [out, valid] = serializeBusWithDataLoggerHeader_TestBusOuter(bus, groupType, groupName, groupMeta)

    valid = uint8(0);
    headerLength = uint16(BusSerialize.computeDataLoggerHeaderLength(groupName, groupMeta));
    outSize = headerLength + testPacketSendLocalLib.getSerializedBusLength_TestBusOuter(bus);
    out = zeros(outSize, 1, 'uint8');
    offset = uint16(1);

        header = BusSerialize.serializeDataLoggerHeader(groupType, groupName, groupMeta, uint32(812220335), uint16(5));
    out(1:headerLength) = uint8(header);
    offset = offset + headerLength;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        if(offset > numel(out)), return, end
    out(offset) = uint8(0);
    offset = offset + uint16(1);

        if(offset > numel(out)), return, end
    out(offset) = uint8(2);
    offset = offset + uint16(1);

        if(offset > numel(out)), return, end
    out(offset) = uint8(0);
    offset = offset + uint16(1);

        if(offset > numel(out)), return, end
    out(offset) = uint8(0);

        if(offset+uint16(2+4 -1) > numel(out)), return, end
    out(offset:(offset+uint16(1))) = typecast(uint16(4), 'uint8');
    offset = offset + uint16(2);
    out(offset:(offset+uint16(4-1))) = uint8('val1');
    offset = offset + uint16(4);

        if(offset+uint16(2+2 -1) > numel(out)), return, end
    out(offset:(offset+uint16(1))) = typecast(uint16(2), 'uint8');
    offset = offset + uint16(2);
    out(offset:(offset+uint16(2-1))) = uint8('AU');
    offset = offset + uint16(2);

        if(offset > numel(out)), return, end
    out(offset) = uint8(3);
    offset = offset + uint16(1);

        if(offset > numel(out)), return, end
    if(offset+uint16(1+2*1-1) > numel(out)), return, end
    out(offset) = uint8(1);
    offset = offset + uint16(1);
    out(offset:(offset+uint16(2*1-1))) = typecast(uint16(numel(bus.val1)), 'uint8');
    offset = offset + uint16(2*1);

        nBytes = uint16(1 * numel(bus.val1));
    if(offset+uint16(nBytes-1) > numel(out)), return, end
    if ischar(bus.val1) || islogical(bus.val1)
        out(offset:(offset+uint16(nBytes-1))) = typecast(uint8(bus.val1(:)), 'uint8');
    else
        out(offset:(offset+uint16(nBytes-1))) = typecast(bus.val1(:), 'uint8');
    end
    offset = offset + nBytes;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        if(offset > numel(out)), return, end
    out(offset) = uint8(0);
    offset = offset + uint16(1);

        if(offset > numel(out)), return, end
    out(offset) = uint8(2);
    offset = offset + uint16(1);

        if(offset > numel(out)), return, end
    out(offset) = uint8(0);
    offset = offset + uint16(1);

        if(offset > numel(out)), return, end
    out(offset) = uint8(0);

        if(offset+uint16(2+4 -1) > numel(out)), return, end
    out(offset:(offset+uint16(1))) = typecast(uint16(4), 'uint8');
    offset = offset + uint16(2);
    out(offset:(offset+uint16(4-1))) = uint8('val2');
    offset = offset + uint16(4);

        if(offset+uint16(2+4 -1) > numel(out)), return, end
    out(offset:(offset+uint16(1))) = typecast(uint16(4), 'uint8');
    offset = offset + uint16(2);
    out(offset:(offset+uint16(4-1))) = uint8('char');
    offset = offset + uint16(4);

        if(offset > numel(out)), return, end
    out(offset) = uint8(3);
    offset = offset + uint16(1);

        if(offset > numel(out)), return, end
    if(offset+uint16(1+2*1-1) > numel(out)), return, end
    out(offset) = uint8(1);
    offset = offset + uint16(1);
    out(offset:(offset+uint16(2*1-1))) = typecast(uint16(numel(bus.val2)), 'uint8');
    offset = offset + uint16(2*1);

        nBytes = uint16(1 * numel(bus.val2));
    if(offset+uint16(nBytes-1) > numel(out)), return, end
    if ischar(bus.val2) || islogical(bus.val2)
        out(offset:(offset+uint16(nBytes-1))) = typecast(uint8(bus.val2(:)), 'uint8');
    else
        out(offset:(offset+uint16(nBytes-1))) = typecast(bus.val2(:), 'uint8');
    end
    offset = offset + nBytes;

        nestedBytes = uint16(testPacketSendLocalLib.getSerializedBusLength_TestBusInner(bus.nested(1)));
    out(offset:(offset+nestedBytes-uint16(1))) = testPacketSendLocalLib.serializeBus_TestBusInner(bus.nested(1));
    offset = offset + nestedBytes;  
    valid = uint8(1);
end