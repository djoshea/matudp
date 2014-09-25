classdef GroupTypes < int32
    % used to route buses on the data logger receivers
    enumeration
        Control (1) % used to change the data logger state (set metadata, advance trial, etc.)
        Parameter (2) % unique because all of the contents of the group are automatically considered parameters (only last value saved)
        Analog (3) % every sample is saved
        Event (4) % have a special form where an SignalTypes.EventName signal determines the name of the event field created
        Note (5) % not yet implemented
        Spike (6)
        Continuous (7)
    end
end
