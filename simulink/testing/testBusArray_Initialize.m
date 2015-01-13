function testBusArray_Initialize() 

    import BusSerialize.SignalSpec;
    import BusSerialize.createBusBaseWorkspace;
    sys = 'testBusArray';

    BusSerialize.defineEnum('TestEnum', {'val1', 'value2', 'val3_long'});
    P.centerSize = SignalSpec.Param(uint16([1 2; 3 4]), 'mm', 'isVariableByDim', [true, true], 'maxSize', [3 3]);
    P.enum = SignalSpec.ParamEnum('TestEnum');
    P.holdWindowTarget = SignalSpec.ParamStringVariable('hello', 30);
    [~, v] = createBusBaseWorkspace('TestBus', P);
    
    BusSerialize.updateCodeForEnums(sys, 'TestEnum');
    BusSerialize.updateCodeForBuses(sys, 'TestBus');
    
    V = [v; v; v];
    V(2).holdWindowTarget = 'world!';
    V(3).holdWindowTarget = 'this is longer!';
    
    V(2).enum = TestEnum.value2;
    V(3).enum = TestEnum.val3_long;
    assignin('base', 'V', V);
    
    sV = BusSerialize.serializeVariableLengthBusArray(sys, 'TestBus', V);
    assignin('base', 'serializedBusArray', sV);
    
end