function [bus, vals, busSpec] = createBusBaseWorkspaceWithFixedSizeSignalsOnly(busName, valueStruct)
    % generate a bus by dropping all variable sized elements from the
    % valueStruct struct -> SignalSpec description. 
    import BusSerialize.SignalSpec;
    
    fields = fieldnames(valueStruct);
    nFields = numel(fields);
    
    % keep only fixed size fields
    fixedValueStruct = struct();
    for iF = 1:nFields
        field = fields{iF};
        value = valueStruct.(field);

        if ~isa(value, 'SignalSpec')
            error('All field values must be BusSerialize.SignalSpec instances');
            %spec = SignalSpec.buildFixedForValue(value);
        else
            spec = value;
        end
        
        if ~spec.isVariable
            fixedValueStruct.(field) = spec;
        end
    end
    
    % defer to normal 
    [bus, vals, busSpec] = BusSerialize.createBusBaseWorkspace(busName, fixedValueStruct);
end