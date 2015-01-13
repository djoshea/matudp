function outSize = getSerializedBusLength_TestBusInner(bus)

    outSize = uint16(0);
        outSize = outSize + uint16(1);     outSize = outSize + uint16(1);     outSize = outSize + uint16(1);     outSize = outSize + uint16(2 + 10);     outSize = outSize + uint16(2 + 2);     outSize = outSize + uint16(1);     outSize = outSize + uint16(1 + 2*1);     outSize = outSize + uint16(1 * numel(bus.centerSize)); 
        outSize = outSize + uint16(1);     outSize = outSize + uint16(1);     outSize = outSize + uint16(1);     outSize = outSize + uint16(2 + 16);     outSize = outSize + uint16(2 + 2);     outSize = outSize + uint16(1);     outSize = outSize + uint16(1 + 2*1);     outSize = outSize + uint16(1 * numel(bus.holdWindowCenter)); 
        outSize = outSize + uint16(1);     outSize = outSize + uint16(1);     outSize = outSize + uint16(1);     outSize = outSize + uint16(2 + 16);     outSize = outSize + uint16(2 + 2);     outSize = outSize + uint16(1);     outSize = outSize + uint16(1 + 2*1);     outSize = outSize + uint16(2 * numel(bus.holdWindowTarget)); 

end