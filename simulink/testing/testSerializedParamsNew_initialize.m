% initialize script for testSerializedParamsNew

function testSerializedParamsNew_initialize()
    BusSerialize.TunableParameter.create('TestParam', uint16(eye(2)));
    BusSerialize.TunableParameter.createToggleSwitch('TestParamToggle');
    BusSerialize.TunableParameter.createPulseSwitch('TestParamPulse');
    
    % Build TaskStatisticsBus
    import BusSerialize.SignalSpec;
    c = struct();
    c.runTask = SignalSpec.ToggleSwitch();
    c.saveData = SignalSpec.ToggleSwitch();
    c.autoTimeoutActive = SignalSpec.ToggleSwitch(false);
    c.giveFreeJuice = SignalSpec.PulseSwitch(); % fed through change detection so that it acts a one-tick push button
    c.resetConditionBlock = SignalSpec.PulseSwitch(); % fed through change detection so that it acts a one-tick push button
    c.flushJuice = SignalSpec.ToggleSwitch();
    c.resetStats = SignalSpec.ToggleSwitch();
    BusSerialize.createBusBaseWorkspace('TaskControlBus', c);

    BusSerialize.TunableParameter.createBus('TunableTaskControl', 'TaskControlBus');
    
end
