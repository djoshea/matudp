function [bus, vals, busSpec] = createBusBaseWorkspace(busName, valueStruct, varargin)
    import BusSerialize.SignalSpec;
    
    p = inputParser();
    p.addParamValue('headerFile', '', @ischar);
    p.parse(varargin{:});
    headerFile = p.Results.headerFile;
    
    fields = fieldnames(valueStruct);
    nFields = numel(fields);

    % create bus object
    bus = Simulink.Bus();
    vals = struct();
    
    % require that the definition go in a specific named header file
    if ~isempty(headerFile)
        bus.DataScope = 'Exported';
        bus.HeaderFile = headerFile;
    end
    
    % create BusSpec object 
    busSpec = BusSerialize.BusSpec(busName);

    for iF = 1:nFields
        field = fields{iF};
        value = valueStruct.(field);

        % create bus element for this field
        busElement = Simulink.BusElement;
        busElement.Name = field;

        if ~isa(value, 'SignalSpec')
            error('All field values must be BusSerialize.SignalSpec instances');
            %spec = SignalSpec.buildFixedForValue(value);
        else
            spec = value;
        end
        
        % add to BusSpec
        busSpec.addSignalSpec(spec, field);
        
        % store value in vals struct
        vals.(field) = spec.value;
            
        if spec.isBus
            % indicates a nested bus
            if isempty(spec.value)
                warning('No value found for bus element %s', field);
            end
            
            busElement.DataType = sprintf('Bus: %s', spec.busName);
            if spec.isVariable
                busElement.Dimensions = spec.busSize;
            else
                busElement.Dimensions = spec.dims;
            end
            
        else
            % normal bus element signal
            busElement.DataType = spec.class;
            
            if spec.isEnum
                busElement.DataType = sprintf('Enum: %s', spec.enumName);
                busElement.DocUnits = 'enum';
                
            elseif islogical(spec.value) || strcmp(spec.class, 'logical')
                % replace boolean values with uint8 arrays but mark units
                % as 'bool'
                busElement.DataType = 'uint8';
                busElement.DocUnits = 'bool';
                
            elseif ischar(spec.value) || strcmp(spec.class, 'char')
                % replace character values with uint8 arrays but mark
                % as units = 'char'
                busElement.DataType = 'uint8';
                busElement.DocUnits = 'char';
                
            else
                busElement.DocUnits = spec.units;
            end 

            % determine whether variable size
            if spec.isVariable
                busElement.DimensionsMode = 'Variable';
                % use the specified upper-bound size rather than the size of
                % value.field
                busElement.Dimensions = spec.maxSize;
            else
                busElement.DimensionsMode = 'Fixed';
                busElement.Dimensions = spec.dims;
            end
        end

        bus.Elements(iF) = busElement;
    end

    % assign the copy into the base workspace with the right name
    assignin('base', busName, bus);
    
    % and assign busSpec into base workspace with name BusSpec_busName
    busSpecVar = sprintf('BusSpec_%s', busName);
    assignin('base', busSpecVar, busSpec);

end
