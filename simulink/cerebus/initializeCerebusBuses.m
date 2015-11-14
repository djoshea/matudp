function initializeCerebusBuses()

import BusSerialize.SignalSpec;

CerebusInfo.MaxChannels = 96;
CerebusInfo.MaxSpikesPerTick = CerebusInfo.MaxChannels;
CerebusInfo.WaveformNumSamples = 48;
CerebusInfo.MaxContinuousSamplesPerTick = 30*2;
CerebusInfo.ContinuousGroupId = 6;

assignin('base', 'CerebusInfo', CerebusInfo);

cerebusHeaderFile = 'CerebusBuses.h';

% CerebusStatisticsBus
s = struct();
s.nUDPPackets = SignalSpec.Param(uint32(0), 'packets');
s.nUDPBytes = SignalSpec.Param(uint32(0), 'bytes');
s.nCBPackets = SignalSpec.Param(uint32(0), 'packets');
s.nSpikes = SignalSpec.Param(uint32(0), 'spikes');
s.nSpikesByChannel = SignalSpec.Analog(zeros(CerebusInfo.MaxChannels, 1, 'uint32'), 'spikes');
s.nContinuousChannels =  SignalSpec.Param(uint16(0), 'channels');
s.nContinuousSamples =  SignalSpec.Param(uint32(0), 'samples');
s.mostRecentContinuousSamples =  SignalSpec.Analog(zeros(CerebusInfo.MaxChannels, 1, 'int16'), 'mV');
s.cerebusClock = BusSerialize.SignalSpec.Param(uint32(0), 'ms/30');
s.clockOffset = BusSerialize.SignalSpec.TimestampOffset(single(0));
s.cerebusClockRef = BusSerialize.SignalSpec.Param(uint32(0), 'ms/30');
s.localClockRef = BusSerialize.SignalSpec.Param(uint32(0), 'ms');
BusSerialize.createBusBaseWorkspace('CerebusStatisticsBus', s, 'headerFile', cerebusHeaderFile);
clear s;

% SpikeDataBus (to send to data logger)
s = struct();
s.spikeTimeOffsets = BusSerialize.SignalSpec.TimestampOffsetVectorVariable(single([]), CerebusInfo.MaxSpikesPerTick); % offset in ms from current timestamp
s.spikeChannels = SignalSpec.AnalogVectorVariable(uint8([]), CerebusInfo.MaxSpikesPerTick);
s.spikeUnits = SignalSpec.AnalogVectorVariable(uint8([]), CerebusInfo.MaxSpikesPerTick);
s.spikeWaveforms = SignalSpec.Analog(zeros(CerebusInfo.WaveformNumSamples, 0, 'int16'), 'mV', ...
    'isVariableByDim', [false true], 'maxSize', [CerebusInfo.WaveformNumSamples, CerebusInfo.MaxSpikesPerTick], ...
    'concatLastDim', true);
BusSerialize.createBusBaseWorkspace('SpikeDataBus', s, 'headerFile', cerebusHeaderFile);
clear s;

% ContinuousDataBus (to send to data logger)
s = struct();
s.continuousTimeOffsets = BusSerialize.SignalSpec.TimestampOffsetVectorVariable(single([]), CerebusInfo.MaxSpikesPerTick); % offset in ms from current timestamp
s.continuousData = SignalSpec.Analog(zeros(0, 0, 'int16'), 'mV', ...
    'isVariableByDim', [true true], 'maxSize', [CerebusInfo.MaxChannels, CerebusInfo.MaxContinuousSamplesPerTick], ...
    'concatLastDim', true);
BusSerialize.createBusBaseWorkspace('ContinuousDataBus', s, 'headerFile', cerebusHeaderFile);
clear s;

BusSerialize.updateCodeForBuses({'SpikeDataBus', 'ContinuousDataBus', 'CerebusStatisticsBus'});

end
