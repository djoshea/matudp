classdef BusSpec < handle
    properties
        busName = '';
        
        % array of SignalSpec handles
        signals 
        
        signalNames = {}
    end
   
    properties(Dependent)
        nSignals
    end
    
    methods
        function bs = BusSpec(name)
            bs.busName = name;
        end
        
        function n = get.nSignals(bs)
            n = numel(bs.signals);
        end
        
        function addSignalSpec(bs, spec, signalName)
            assert(isa(spec, 'BusSerialize.SignalSpec'));
            if bs.nSignals == 0
                bs.signals = spec;
                bs.signalNames = {signalName};
            else
                bs.signals(bs.nSignals+1, 1) = spec;
                bs.signalNames = [bs.signalNames; signalName];
            end
        end
        
        function hash = computeConfigurationHash(bs)
            % returns a scalar uint32 hash of the configuration of this bus
            % and nested signals/buses, ignoring the values (and current
            % sizes of variable signals)
            S = bs.getStructForConfigurationHash();
            opt.Method = 'Sha-1';
            opt.Format = 'uint8';
            fullHash = BusSerialize.DataHash(S, opt);
            hash = typecast(fullHash(1:4), 'uint32');
        end
        
        function S = getStructForConfigurationHash(bs)
            S.busName = bs.busName;
            for i = 1:bs.nSignals
                S.signalConfig(i) = bs.signals(i).getStructForConfigurationHash();
            end
            S.signalNames = bs.signalNames;
        end
        
        function s = getSignalByName(bs, name)
            [tf, idx] = ismember(name, bs.signalNames);
            if ~tf
                s = [];
            else
                s = bs.signals(idx(1));
            end
        end
    end
    
end
        
