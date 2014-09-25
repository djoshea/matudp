classdef SignalTypes < int32
    enumeration
        Unspecified (0)
        Timestamp (1) % uint32 timestamp in ms
        TimestampOffset (2) % single precision offset in ms
        Pulse (3) % single tick "pulse" instruction
        Param (4)
        Analog (5)
        EventName (6)
        EventTag (7) % TODO not yet supported!!!!
        Spike (8)
        SpikeWaveform (9)
    end
end
