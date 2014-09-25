function dlInfo = createDataLoggerControlBuses()
    % creates the two buses needed by the data logger
    
    import BusSerialize.SignalSpec;
    
    % create data logger info bus
    d = struct();
    d.dataStore = SignalSpec.ParamStringVariable('TestStore', 30);
    d.subject = SignalSpec.ParamStringVariable('TestSubject', 30);
    d.protocol = SignalSpec.ParamStringVariable('TestProtocol', 30);
    d.protocolVersion = SignalSpec.Param(uint32(20140101), '');
    d.saveTag = SignalSpec.Param(uint32(1), '');
    [~, dlInfo] = BusSerialize.createBusBaseWorkspace('DataLoggerInfoBus', d);
    
    % create data logger next trial bus
    d = struct();
    d.nextTrial = SignalSpec.Param(uint32(0));
    BusSerialize.createBusBaseWorkspace('DataLoggerNextTrialBus', d);
    
    % create note type enum and NoteBus
    noteTypes = { 'Info', 'Debug', 'Warning', 'Error', 'ParameterChange', 'Epoch', 'Meta' };    
    BusSerialize.defineEnum('NoteType', noteTypes, 'description', ...
        'List of note types defined for NoteBus');
    n = struct();
    n.noteType = SignalSpec.ParamEnum('NoteType');
    n.note = SignalSpec.ParamStringVariable('', 50000);
    BusSerialize.createBusBaseWorkspace('NoteBus', n);
    
    % author bus code
    BusSerialize.updateCodeForEnums({'NoteType'});
    BusSerialize.updateCodeForBuses({'DataLoggerInfoBus', 'DataLoggerNextTrialBus', 'NoteBus'});
    
    % create tunable parameters in base workspace
    BusSerialize.TunableParameter.create('TunableNextTrialId', uint32(0));
    BusSerialize.TunableParameter.createBus('TunableDataLoggerInfo', 'DataLoggerInfoBus');
    BusSerialize.TunableParameter.createBus('TunableNote', 'NoteBus');
    
end
