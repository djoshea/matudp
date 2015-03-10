function [TestBusVal, TestBusInnerVal, TestBusOuterVal] = testSerializedParams_Initialize()

    import BusSerialize.SignalSpec;
    import BusSerialize.createBusBaseWorkspace;

    P.centerSize = SignalSpec.Param(uint16([1 2; 3 4]), 'mm', 'isVariableByDim', [true, true], 'maxSize', [3 3]);
    P.holdWindowCenter = SignalSpec.Param(uint8(15), 'mm');
    P.holdWindowTarget = SignalSpec.ParamStringVariable('hello', 30);
    [~, TestBusVal] = createBusBaseWorkspace('TestBus', P);

    P1.centerSize = SignalSpec.Param(uint8([1 2]), 'mm');
    P1.holdWindowCenter = SignalSpec.Param(uint8(2), 'mm');
    P1.holdWindowTarget = SignalSpec.Param(uint16(3), 'mm');

    [~, TestBusInnerVal] = createBusBaseWorkspace('TestBusInner', P1);

    BusSerialize.defineEnum('TestEnum', {'eval1', 'eval2', 'eval3_longer'});
    
    O.val1 = SignalSpec.Param(uint8(1), 'AU');
    O.val2 = SignalSpec.ParamString('hello');
    O.valEnum = SignalSpec.ParamEnum('TestEnum');
    O.nested = SignalSpec.Bus('TestBusInner', TestBusInnerVal);
    [~, TestBusOuterVal] = createBusBaseWorkspace('TestBusOuter', O);

    BusSerialize.updateCodeForBuses('testSerializedParams', {'TestBus', 'TestBusOuter'});
    BusSerialize.updateCodeForEnums('testSerializedParams', {'TestEnum'});
    
    BusSerialize.createSerializedBusTunableParameter('TestBusOuter', 'ParamTestBusOuter');
    
P1 = testSerializedParamsLib.initializeBus_TestBusInner();

P1.centerSize = uint8([1 2])';
P1.holdWindowCenter = uint8(2);
P1.holdWindowTarget = uint16(30);

bus.val1 = uint8(3);
bus.val2 = uint8('hello')';
bus.valEnum = TestEnum.eval3_longer;
bus.nested = P1;

A = testSerializedParamsLib.serializeBus_TestBusOuter(bus);
end
