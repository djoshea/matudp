function initializeCerebus()

import BusSerialize.SignalSpec;

CerebusInfo.MaxChannels = 128;
CerebusInfo.MaxSpikesPerTick = CerebusInfo.MaxChannels;
CerebusInfo.WaveformSamples = 48;
CerebusInfo.MaxContinuousSamplesPerTick = 60;

assignin('base', 'CerebusInfo', CerebusInfo);

% CerebusStatisticsBus
s = struct();
s.numDroppedPackets = BusSerialize.SignalSpec.Param(uint32(0), 'packets');
s.lastPacketNumber= BusSerialize.SignalSpec.Param(int32(0), '');
s.lastClock = BusSerialize.SignalSpec.Param(uint32(0), 'ms/30');
s.clockOffset = BusSerialize.SignalSpec.TimestampOffset(single(0));
BusSerialize.createBusBaseWorkspace('CerebusStatisticsBus', s);
clear s;

% SpikeDataBus (to send to data logger)
s = struct();
s.spikeTimeOffsets = BusSerialize.SignalSpec.TimestampOffsetVectorVariable(single([]), CerebusInfo.MaxSpikesPerTick); % offset in ms from current timestamp
s.spikeChannels = SignalSpec.AnalogVectorVariable(uint8([]), CerebusInfo.MaxSpikesPerTick);
s.spikeUnits = SignalSpec.AnalogVectorVariable(uint8([]), CerebusInfo.MaxSpikesPerTick);
s.spikeWaveforms = SignalSpec.Analog(zeros(CerebusInfo.WaveformSamples, 0, 'int16'), 'mV', ...
    'isVariableByDim', [false true], 'maxSize', [CerebusInfo.WaveformSamples, CerebusInfo.MaxSpikesPerTick], ...
    'concatLastDim', true);
BusSerialize.createBusBaseWorkspace('SpikeDataBus', s);
clear s;

% AnalogDataBus (to send to data logger)
s = struct();
s.continuousTimeOffsets = BusSerialize.SignalSpec.TimestampOffsetVectorVariable(single([]), CerebusInfo.MaxContinuousSamplesPerTick); % offset in ms from current timestamp
s.continuousData = SignalSpec.Analog(zeros(0, 0), '', 'isVariableByDim', [true true], ...
    'maxSize', [CerebusInfo.MaxChannels, CerebusInfo.MaxContinuousSamplesPerTick], ...
    'concatLastDim', true);
BusSerialize.createBusBaseWorkspace('ContinuousDataBus', s);
clear s;

BusSerialize.updateCodeForBuses({'SpikeDataBus', 'CerebusStatisticsBus', 'ContinuousDataBus'});

end
