function [out, valid] = serializeBus_TestBus(bus)

    valid = uint8(0);
    coder.varsize('out', 124);
    outSize = testPacketSendLocalLib.getSerializedBusLength_TestBus(bus);
    out = zeros(outSize, 1, 'uint8');
    offset = uint16(1);

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

        if(offset+uint16(2+10 -1) > numel(out)), return, end
    out(offset:(offset+uint16(1))) = typecast(uint16(10), 'uint8');
    offset = offset + uint16(2);
    out(offset:(offset+uint16(10-1))) = uint8('centerSize');
    offset = offset + uint16(10);

        if(offset+uint16(2+2 -1) > numel(out)), return, end
    out(offset:(offset+uint16(1))) = typecast(uint16(2), 'uint8');
    offset = offset + uint16(2);
    out(offset:(offset+uint16(2-1))) = uint8('mm');
    offset = offset + uint16(2);

        if(offset > numel(out)), return, end
    out(offset) = uint8(5);
    offset = offset + uint16(1);

        if(offset > numel(out)), return, end
    if(offset+uint16(1+2*2-1) > numel(out)), return, end
    out(offset) = uint8(2);
    offset = offset + uint16(1);
    out(offset:(offset+uint16(2*2-1))) = typecast(uint16(size(bus.centerSize)), 'uint8');
    offset = offset + uint16(2*2);

        nBytes = uint16(2 * size(bus.centerSize, 1) * size(bus.centerSize, 2));
    if(offset+uint16(nBytes-1) > numel(out)), return, end
    if ischar(bus.centerSize) || islogical(bus.centerSize)
        out(offset:(offset+uint16(nBytes-1))) = typecast(uint8(bus.centerSize(:)), 'uint8');
    else
        out(offset:(offset+uint16(nBytes-1))) = typecast(bus.centerSize(:), 'uint8');
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

        if(offset+uint16(2+16 -1) > numel(out)), return, end
    out(offset:(offset+uint16(1))) = typecast(uint16(16), 'uint8');
    offset = offset + uint16(2);
    out(offset:(offset+uint16(16-1))) = uint8('holdWindowCenter');
    offset = offset + uint16(16);

        if(offset+uint16(2+2 -1) > numel(out)), return, end
    out(offset:(offset+uint16(1))) = typecast(uint16(2), 'uint8');
    offset = offset + uint16(2);
    out(offset:(offset+uint16(2-1))) = uint8('mm');
    offset = offset + uint16(2);

        if(offset > numel(out)), return, end
    out(offset) = uint8(3);
    offset = offset + uint16(1);

        if(offset > numel(out)), return, end
    if(offset+uint16(1+2*1-1) > numel(out)), return, end
    out(offset) = uint8(1);
    offset = offset + uint16(1);
    out(offset:(offset+uint16(2*1-1))) = typecast(uint16(numel(bus.holdWindowCenter)), 'uint8');
    offset = offset + uint16(2*1);

        nBytes = uint16(1 * numel(bus.holdWindowCenter));
    if(offset+uint16(nBytes-1) > numel(out)), return, end
    if ischar(bus.holdWindowCenter) || islogical(bus.holdWindowCenter)
        out(offset:(offset+uint16(nBytes-1))) = typecast(uint8(bus.holdWindowCenter(:)), 'uint8');
    else
        out(offset:(offset+uint16(nBytes-1))) = typecast(bus.holdWindowCenter(:), 'uint8');
    end
    offset = offset + nBytes;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        if(offset > numel(out)), return, end
    out(offset) = uint8(1);
    offset = offset + uint16(1);

        if(offset > numel(out)), return, end
    out(offset) = uint8(2);
    offset = offset + uint16(1);

        if(offset > numel(out)), return, end
    out(offset) = uint8(0);
    offset = offset + uint16(1);

        if(offset > numel(out)), return, end
    out(offset) = uint8(1);

        if(offset+uint16(2+16 -1) > numel(out)), return, end
    out(offset:(offset+uint16(1))) = typecast(uint16(16), 'uint8');
    offset = offset + uint16(2);
    out(offset:(offset+uint16(16-1))) = uint8('holdWindowTarget');
    offset = offset + uint16(16);

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
    out(offset:(offset+uint16(2*1-1))) = typecast(uint16(numel(bus.holdWindowTarget)), 'uint8');
    offset = offset + uint16(2*1);

        nBytes = uint16(1 * numel(bus.holdWindowTarget));
    if(offset+uint16(nBytes-1) > numel(out)), return, end
    if ischar(bus.holdWindowTarget) || islogical(bus.holdWindowTarget)
        out(offset:(offset+uint16(nBytes-1))) = typecast(uint8(bus.holdWindowTarget(:)), 'uint8');
    else
        out(offset:(offset+uint16(nBytes-1))) = typecast(bus.holdWindowTarget(:), 'uint8');
    end
    offset = offset + nBytes; 
    valid = uint8(1);
end