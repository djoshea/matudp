function outSize = getSerializedBusLength_TestBusOuter(bus)

    outSize = uint16(0);
        outSize = outSize + uint16(1);     outSize = outSize + uint16(1);     outSize = outSize + uint16(1);     outSize = outSize + uint16(2 + 4);     outSize = outSize + uint16(2 + 2);     outSize = outSize + uint16(1);     outSize = outSize + uint16(1 + 2*1);     outSize = outSize + uint16(1 * numel(bus.val1)); 
        outSize = outSize + uint16(1);     outSize = outSize + uint16(1);     outSize = outSize + uint16(1);     outSize = outSize + uint16(2 + 4);     outSize = outSize + uint16(2 + 4);     outSize = outSize + uint16(1);     outSize = outSize + uint16(1 + 2*1);     outSize = outSize + uint16(1 * numel(bus.val2)); 
        outSize = outSize + uint16(testPacketSendLocalLib.getSerializedBusLength_TestBusInner(bus.nested(1))); 

end