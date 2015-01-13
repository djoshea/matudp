import BusSerialize.SignalSpec;

e.buffer = SignalSpec.ParamVectorVariable(uint8(0), 100);
e.len = SignalSpec.Param(uint32(0));
BusSerialize.createBusBaseWorkspace('TestForBus', e);

BusSerialize.updateCodeForBuses('testForEach', 'TestForBus');