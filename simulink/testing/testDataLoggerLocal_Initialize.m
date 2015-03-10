function testDataLoggerLocal_Initialize()

    import BusSerialize.SignalSpec;
    import BusSerialize.createBusBaseWorkspace;

    d.dataStore = SignalSpec.ParamStringVariable('testStore', 30);
    d.subject = SignalSpec.ParamStringVariable('testSubj', 30);
    d.protocol = SignalSpec.ParamStringVariable('testProto', 30);
    d.protocolVersion = SignalSpec.Param(uint32(20140428), '');
    d.saveTag = SignalSpec.Param(uint32(1), '');
    d.nextTrial = SignalSpec.Param(uint8(1), '');

    [~, dataLoggerInfo] = createBusBaseWorkspace('DataLoggerControlBus', d);
    
    dataLoggerInfo.dataStore = uint8(dataLoggerInfo.dataStore);
    dataLoggerInfo.subject = uint8(dataLoggerInfo.subject);
    dataLoggerInfo.protocol = uint8(dataLoggerInfo.protocol);
    
    assignin('base', 'dataLoggerInfo', dataLoggerInfo);
    
    BusSerialize.updateCodeForBuses(gcs, {'DataLoggerControlBus'});
    
    % really large data
    P.centerSize = SignalSpec.Param(ones(255, 20, 'uint8'), 'mm', ...
        'isVariableByDim', [true, true], 'maxSize', [255 25]);
    P.holdWindowCenter = SignalSpec.Param(uint8(15), 'mm');
    P.holdWindowTarget = SignalSpec.ParamStringVariable('hello', 30);
    [~, TestBusVal] = createBusBaseWorkspace('TestBus', P);

    P1.centerSize = SignalSpec.Param(uint8([1 2]), 'mm');
    P1.holdWindowCenter = SignalSpec.Param(uint8(2), 'mm');
    P1.holdWindowTarget = SignalSpec.Param(uint16(3), 'mm');

    [~, TestBusInnerVal] = createBusBaseWorkspace('TestBusInner', P1);

    O.val1 = SignalSpec.Param(uint8(1), 'AU');
    O.val2 = SignalSpec.ParamString('hello');
    O.nested = SignalSpec.Bus('TestBusInner', TestBusInnerVal);
    [~, TestBusOuterVal] = createBusBaseWorkspace('TestBusOuter', O);

    BusSerialize.updateCodeForBuses(gcs, {'TestBus', 'TestBusOuter'});

end