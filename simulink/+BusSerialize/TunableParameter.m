classdef TunableParameter < handle
% this class wraps Simulink.Parameter objects and handles:
%  - prefixing values with a uint8 counter so that parameter updates can
%     be detected on the xPC target
%  - for non-bus signals: typecasting values as double so that parameters can be tuned on xPC
%     target.
%  - for bus signals: serializing the bus value using the serializeBus_
%     method
%  - handling pulse switch and toggle switch signals
%

    properties(SetAccess=protected)
        name
        
        parameter % Simulink.Parameter object
        
        resetImmediately = false; % this is set for pulse switch signals only, bus signals maintain their own resetImmediately flags
        
        resetValue
        
        value
        
        valueSize
        
        valueClass = '';
        
        updateCounter = uint8(1);
        
        isBus = false;
        
        isVariableLengthBusArray = false;
        
        busArrayMaxElements
        
        busName = '';
        
        isPulseSwitch = false;
        
        isToggleSwitch = false;
        
        headerLength = 1;
        
        numelAsDouble
        
        numelAsBytes
        
        startByteDeserialize
        
        endByteDeserialize
    end
    
    properties(Dependent)
        nameSimulinkParameter
        
        valueClassSimulink % same as valueClass except char and logical are converted to uint8
        
        valueAsBytes
        
        valueAsDouble
    end 
    
    methods(Access=protected)
        % use create methods to construct!
        function tp = TunableParameter()
            
        end
    end
    
    methods(Static)
        function tp = create(name, value, varargin)
            % creates parameter and saves in base workspace
            tp = BusSerialize.TunableParameter();
            
            p = inputParser();
            p.addParamValue('resetImmediately', false, @islogical);
            p.addParamValue('isPulseSwitch', false, @islogical);
            p.addParamValue('isToggleSwitch', false, @islogical);
            p.addParamValue('isBus', false, @islogical);
            p.addParamValue('isVariableLengthBusArray', false, @islogical);
            p.addParamValue('busArrayMaxElements', 1, @isscalar);
            p.addParamValue('busName', '', @ischar)
            p.parse(varargin{:});
            
            tp.name = name;
            
            tp.valueClass = class(value);
            if ischar(value) || islogical(value)
                value = uint8(value);
            end
            value = BusSerialize.makecol(value);
            
            tp.value = value;
            tp.resetValue = value;

            tp.resetImmediately = p.Results.resetImmediately;
            tp.isBus = p.Results.isBus;
            tp.isVariableLengthBusArray = p.Results.isVariableLengthBusArray;
            tp.busArrayMaxElements = p.Results.busArrayMaxElements;
            tp.busName = p.Results.busName;
            tp.isPulseSwitch = p.Results.isPulseSwitch;
            tp.isToggleSwitch = p.Results.isToggleSwitch;

            if tp.isBus || tp.isVariableLengthBusArray
                tp.valueClass = 'struct';
                tp.valueSize = [tp.busArrayMaxElements 1];
            else
                tp.valueClass = class(value);
                tp.valueSize = size(value);
            end
            
            % save room for largest possible serialized value
            headerLength = 1;
            if tp.isBus
                numBytes = headerLength + BusSerialize.computeMaxSerializedBusLength(tp.busName);
            elseif tp.isVariableLengthBusArray
                numBytes = headerLength + BusSerialize.maxLengthSerializedVariableLengthBusArray(tp.busName, tp.busArrayMaxElements);
            else
                % already includes 1 byte header
                numBytes = numel(tp.getValueAsBytes(value));
            end
            tp.numelAsBytes = numBytes;
            tp.numelAsDouble = ceil(numBytes / 8);
            
            tp.startByteDeserialize = headerLength + 1; % skip 1 byte header
            tp.endByteDeserialize = tp.numelAsBytes; % already includes 1 byte header
           
            tp.parameter = Simulink.Parameter;
            tp.parameter.Value = tp.getValueAsDouble(value);
            tp.parameter.DataType = 'double';
            tp.parameter.CoderInfo.StorageClass = 'ExportedGlobal';
            
            tp.assignIntoBaseWorkspace();
        end
        
        function tp = createPulseSwitch(name)
            % critical that value be false here as that's what it resets to
            tp = BusSerialize.TunableParameter.create(name, uint8(0), 'resetImmediately', true, 'isPulseSwitch', true);
        end
        
        function tp = createToggleSwitch(name, normallyOn)
            if nargin < 2
                normallyOn = false;
            end
            
            tp = BusSerialize.TunableParameter.create(name, uint8(normallyOn), 'isToggleSwitch', true);
        end       
        
        function tp = createBus(name, busName, value)
            if nargin < 3
                initFn = sprintf('initializeBus_%s', busName);
                if ~exist(initFn, 'file')
                    error('Could not find %s to generate default initial value for bus', initFn);
                end
                fn = str2func(initFn);
                value = fn();
            end
            tp = BusSerialize.TunableParameter.create(name, value, 'busName', busName, 'isBus', true);
        end
        
        function tp = createVariableLengthBusArray(name, busName, maxElements)
            tp = BusSerialize.TunableParameter.create(name, struct([]), 'busName', busName, ...
                'isVariableLengthBusArray', true, 'busArrayMaxElements', maxElements);
        end
    end
    
    methods
        function incrementUpdateCounter(tp)
            tp.updateCounter = uint8(mod(uint16(tp.updateCounter) + uint16(1),  256));
        end
        
        function assignIntoBaseWorkspace(tp)
            assignin('base', tp.name, tp);
            assignin('base', tp.nameSimulinkParameter, tp.parameter);
        end
    end
    
    methods
        function setValue(tp, value, varargin)
            p = inputParser();
            p.addParamValue('localOnly', false, @islogical);
            p.addParamValue('remoteOnly', false, @islogical);
            p.parse(varargin{:});
            localOnly = p.Results.localOnly;
            remoteOnly = p.Results.remoteOnly;

            if ~localOnly
                tg = xpctarget.xpc;
                if isempty(tg)
                    warning('Could not find xPC target. Skipping setting value of parameter %s', tp.nameSimulinkParameter)
                    return;
                end
            end
            
            if isvector(value)
                value = BusSerialize.makecol(value);
            end
            assert(all(size(value) <= tp.valueSize), 'Value must be same size or smaller than old value');
            
            if ~tp.isBus && ~tp.isVariableLengthBusArray
                % expand to original size of resetValue in case we're
                % providing a smaller vector, matrix than originally
                % specified
                if strcmp(tp.valueClass, 'logical')
                    fullValue = false(tp.valueSize);
                else
                    fullValue = zeros(tp.valueSize, tp.valueClass);
                end
                sz = size(value);
                args = arrayfun(@(s) 1:s, sz, 'UniformOutput', false);
                
                fullValue(args{:}) = value;
                
                value = fullValue;
            end
        
            tp.incrementUpdateCounter();
            
            valueAsDouble = tp.getValueAsDouble(value);
            assert(numel(valueAsDouble) <= tp.numelAsDouble, 'Serialized alue size has changed since creation');

            if ~localOnly
                % try to update the value on the xPC target
                try
                    paramId = tg.getparamid('', tp.nameSimulinkParameter);
                catch
                    paramId = [];
                end

                if isempty(paramId)
                    %warning('Could not find parameter %s on xPC Target, only updating local parameter', tp.nameSimulinkParameter);
                end
                
                if ~isempty(paramId)
                    try
                        tg.setparam(paramId, valueAsDouble);
                        fprintf('Updated parameter %s on xPC target\n', tp.nameSimulinkParameter);
                    catch e
                        fprintf('%s', e.getReport());
                    end 
                end
            end
            
            % if all okay, update value
            if ~remoteOnly
                tp.value = value;
                tp.parameter.Value = valueAsDouble;
            end
        end

        function activatePulseSwitch(tp)
            if ~tp.isPulseSwitch
                error('TunableParameter %s is not a pulse switch, see createPulseSwitch(...)', tp.name);
            end
            
            tp.setValue(true, 'remoteOnly', true);
            tp.value = false;
        end
        
        function newValue = toggleSwitch(tp)
            if ~tp.isToggleSwitch
                error('TunableParameter %s is not a toggle switch, see createToggleSwitch(...)', tp.name);
            end
            
            newValue = ~tp.value;
            tp.setValue(newValue);
        end 
        
        function toggleSwitchOn(tp)
            if ~tp.isToggleSwitch
                error('TunableParameter %s is not a toggle switch, see createToggleSwitch(...)', tp.name);
            end
            
            tp.setValue(true);
        end
        
        function toggleSwitchOff(tp)
            if ~tp.isToggleSwitch
                error('TunableParameter %s is not a toggle switch, see createToggleSwitch(...)', tp.name);
            end
            
            tp.setValue(false);
        end
        
        function activatePulseField(tp, field)
            assert(tp.isBus && isfield(tp.value, field), 'Parameter %s is not a bus or does not have field %s', tp.name, field);
            v = tp.value;
            v.(field) = true;
            tp.setValue(v, 'remoteOnly', true);
            tp.value.(field) = false;
        end
        
        function val = toggleField(tp, field)
            assert(tp.isBus && isfield(tp.value, field), 'Parameter %s is not a bus or does not have field %s', tp.name, field);
            v = tp.value;
            val = ~v.(field);
            v.(field) = val;
            tp.setValue(v);
        end
        
        function toggleFieldOn(tp, field)
            assert(tp.isBus && isfield(tp.value, field), 'Parameter %s is not a bus or does not have field %s', tp.name, field);
            v = tp.value;
            v.(field) = true;
            tp.setValue(v);
        end
        
        function toggleFieldOff(tp, field)
            assert(tp.isBus && isfield(tp.value, field), 'Parameter %s is not a bus or does not have field %s', tp.name, field);
            v = tp.value;
            v.(field) = false;
            tp.setValue(v);
        end
        
        function value = retrieveValueFromTarget(tp)
            try
                paramId = tg.getparamid('', tp.nameSimulinkParameter);
            catch
                paramId = [];
            end

            if isempty(paramId)
                warning('Could not find parameter %s on xPC Target, trusting value from local parameter', tp.nameSimulinkParameter);
    
                serialized = tp.parameter.Value;
            else
                serialized = tg.getparam(paramId);
            end
           
            value = tp.deserializeValue(serialized);
            tp.value = value;
            tp.parameter.Value = value;
        end

        function [value, counter] = deserializeValue(tp, serialized)
            assert(isdouble(serialized));
            headerLen = 1;
            valueAsBytes = typecast(serialized(:), 'uint8');
            counter = uint8(valueAsBytes(1));
            data = valueAsBytes(headerLen+1:end);

            if tp.isBus
                fnName = sprintf('deserializeBusForMatlab_%s', tp.busName);
                if ~exist(fnName, 'file')
                    error('Could not find deserialization function %s. Have you called BusSerialize.updateCodeForBuses(''%s'')?', ...
                        fnName, tp.busName);
                end
                deserializeFn = str2func(fnName);
                value = deserializeFn(data);

            elseif tp.isVariableLengthBusArray
                % build header
               error('Not yet implemented');

            else
                value = cast(typecast(data(:), tp.valueClassSimulink), tp.valueClass);
            end 
        end
    end
    
    methods
        function sname = get.nameSimulinkParameter(tp)
            sname = sprintf('SimulinkParameter_%s', tp.name);
        end
        
        function sclass = get.valueClassSimulink(tp)
            if ismember(tp.valueClass, {'logical', 'char'});
                sclass = 'uint8';
            else
                sclass = tp.valueClass;
            end 
        end
        
        function asBytes = get.valueAsBytes(tp)
            asBytes = tp.getValueAsBytes(tp.value);
        end
        
        function asBytes = getValueAsBytes(tp, value)
            if tp.isBus
                % serialize the bus
                fnName = sprintf('serializeBus_%s', tp.busName);
                if ~exist(fnName, 'file')
                    error('Could not find serialization function %s. Have you called BusSerialize.updateCodeForBuses(''%s'')?', ...
                        fnName, tp.busName);
                end
                serializeFn = str2func(fnName);
                [serialized, valid] = serializeFn(value);
                if ~valid, error('Error serializing value!'); end
                
            elseif tp.isVariableLengthBusArray
                % serialize the bus array
                serialized = BusSerialize.serializeVariableLengthBusArray(tp.busName, value);
                
            else
                serialized = typecast(value(:), 'uint8');
            end
                
            % first byte is uint8 counter that increments each time we update
            asBytes = [uint8(tp.updateCounter); makecol(serialized)];
            
            function v = makecol(v)
                if(size(v, 2) > size(v, 1) && isvector(v))
                    v = v';
                end
            end
        end
        
        function asDouble = get.valueAsDouble(tp)
            asDouble = tp.getValueAsDouble(tp.value);
        end
        
        function asDouble = getValueAsDouble(tp, value)
            % typecast to double after rounding up number of bytes to
            % nearest octet. We do this because Simulink xPC target only
            % tunes double parameters
            asBytes = tp.getValueAsBytes(value);
            lenBytes = numel(asBytes);
            lenAsDouble = tp.numelAsDouble;
            valueAsBytes = zeros(lenAsDouble*8, 1, 'uint8');
            valueAsBytes(1:lenBytes) = asBytes;
            asDouble = typecast(valueAsBytes, 'double');
        end
    end
end

