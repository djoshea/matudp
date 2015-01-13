function outSize = getSerializedBusLength_TestBus(bus)

    outSize = uint16(0);
        outSize = outSize + uint16(1);     outSize = outSize + uint16(1);     outSize = outSize + uint16(1);     outSize = outSize + uint16(2 + 10);     outSize = outSize + uint16(2 + 2);     outSize = outSize + uint16(1);     outSize = outSize + uint16(1 + 2*2);     outSize = outSize + uint16(2 * size(bus.centerSize, 1) * size(bus.centerSize, 2)); 
        outSize = outSize + uint16(1);     outSize = outSize + uint16(1);     outSize = outSize + uint16(1);     outSize = outSize + uint16(2 + 16);     outSize = outSize + uint16(2 + 2);     outSize = outSize + uint16(1);     outSize = outSize + uint16(1 + 2*1);     outSize = outSize + uint16(1 * numel(bus.holdWindowCenter)); 
        outSize = outSize + uint16(1);     outSize = outSize + uint16(1);     outSize = outSize + uint16(1);     outSize = outSize + uint16(2 + 16);     outSize = outSize + uint16(2 + 4);     outSize = outSize + uint16(1);     outSize = outSize + uint16(1 + 2*1);     outSize = outSize + uint16(1 * numel(bus.holdWindowTarget)); 

end