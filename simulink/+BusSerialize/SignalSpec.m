classdef SignalSpec < handle

    properties
        value = [];
        units = '';
        type = BusSerialize.SignalTypes.Unspecified;

        isLogical = false; % whether this value came from a logical and was converted to uint8 for Simulink

        isVariableByDim = false; % logical array indicating whether each dimension has variable length
        maxSize = []; % array of maximum size along each dimension

        ndimsManual = []; % if set, ndims will be forced up to this number, useful when concatLastDim is true and we want to distinguish between multiple
        concatLastDim = true; % indicates which dimension to concatenate analog signals along

        isBus = false;
        busName = '';

        isEnum = false;
        enumName = '';

        % should this be cleared immediately after 1 tick when
        % de-serializing
        resetImmediately = false;

        includeForSerialization = true;
    end

    properties(Dependent)
        class % class to use in matlab
        classSimulink % class to use inside simulink for code generation (converts logical and char to uint8)
        classForSerialization % like class, except converts enum to char
        isVariable
        isChar
        nDims
        dims
        bytesPerElement

        bitFlagsForSerialization % used in serialization process to indicate a few boolean flags
        % 1: isVariable
        % 2: concatLastDim

        isPulse
    end

    methods(Access=protected)
        % don't call constructor directly, use one of the Static methods
        % below to construct
        function sv = SignalSpec(varargin)
            p = inputParser();
            p.addParameter('value', [], @(x) true);
            p.addParameter('units', '', @ischar);
            p.addParameter('type', BusSerialize.SignalTypes.Unspecified, @(x) isa(x, 'BusSerialize.SignalTypes'));
            p.addParameter('isVariableByDim', [], @islogical);
            p.addParameter('maxSize', [], @isvector);
            p.addParameter('concatLastDim', true, @islogical);
            p.addParameter('ndimsManual', [], @(x) isempty(x) || isscalar(x));
            p.addParameter('isBus', false, @islogical);
            p.addParameter('busName', '', @ischar);
            p.addParameter('isEnum', false, @islogical);
            p.addParameter('enumName', '', @ischar);
            p.addParameter('resetImmediately', false, @islogical);
            p.addParameter('includeForSerialization', true, @islogical);
            p.parse(varargin{:});

            % copy values over to class
            flds = fieldnames(p.Results);
            for i = 1:numel(flds)
                sv.(flds{i}) = p.Results.(flds{i});
            end

            % convert logical to uint8
            if islogical(p.Results.value)
                sv.isLogical = true;
                sv.value = uint8(p.Results.value);
            end

            if ~ismember('maxSize', p.UsingDefaults)
                nDims = numel(p.Results.maxSize);
            elseif ~ismember('isVariableByDim', p.UsingDefaults)
                nDims = numel(p.Results.isVariableByDim);
            elseif isvector(sv.value) || (isempty(sv.value) && ismatrix(sv.value))
                nDims = 1;
            else
                nDims = ndims(sv.value);
            end
            sv.ndimsManual = p.Results.ndimsManual;
            if ~isempty(nDimsManual)
                nDims = max(nDimsManual, nDims);
            end

            if ismember('isVariableByDim', p.UsingDefaults)
                sv.isVariableByDim = false(1 , nDims);
            end

            sv.ndimsManual = p.Results.ndimsManual;

            if ismember('maxSize', p.UsingDefaults)
                if nDims == 1
                    sv.maxSize = numel(sv.value);
                else
                    sv.maxSize = size(sv.value);
                end
            end

            sv.includeForSerialization = p.Results.includeForSerialization;

            assert(ischar(sv.units));
            assert(isempty(sv.value) || numel(sv.isVariableByDim) == nDims, 'isVariableByDim must have numel == nDims');
            assert(numel(sv.maxSize) == nDims, 'maxSize must have numel == nDims');
        end
    end

    methods % configuration hash utilities
         % used when hashing bus configuration
         function S = getStructForConfigurationHash(spec)
            S.units = spec.units;
            S.class = spec.class;
            S.type = uint8(spec.type);
            S.isVariableByDim = spec.isVariableByDim;
            S.maxSize = spec.maxSize;
            S.concatLastDim = spec.concatLastDim;

            S.busConfig = [];
            S.enumName = spec.enumName;
            S.enumValues = [];

            if spec.isBus
                % include nested to BusSpec's configuration
                [~, busSpec] = BusSerialize.getBusFromBusName(spec.busName);
                if isempty(busSpec)
                    error('BusSpec for bus %s not found in base workspace', spec.busName);
                end
                S.busConfig = busSpec.getStructForConfigurationHash();
            end

            if spec.isEnum
                % include the value struct for the enum to hash
                S.enumValues = BusSerialize.getEnumAsValueStruct(spec.enumName);
            end
         end
    end

    methods % Dependent property generators
        function c = get.class(sv)
            if sv.isBus
                c = '';
%             elseif sv.isEnum
%                 % will be converted to char during serialization
%                 c = 'char';
            elseif sv.isLogical
                c = 'logical';
            else
                c = class(sv.value);
            end
        end

        function c = get.classForSerialization(sv)
            if sv.isEnum
                % will be converted to char during serialization
                c = 'char';
            else
                c = sv.class;
            end
        end

        function tf = get.isChar(sv)
            tf = strcmp(sv.class, 'char');
        end

        function c = get.classSimulink(sv)
            if sv.isLogical || sv.isChar
                c = 'uint8';
            else
                c = class(sv.value); %#ok<CPROP>
            end
        end

        function tf = get.isVariable(sv)
            tf = any(sv.isVariableByDim);
        end

        function nDims = get.nDims(sv)
            if sv.isBus
                nDims = numel(sv.maxSize);
            elseif isvector(sv.value)
                nDims = 1;
            else
                nDims = ndims(sv.value);
            end

            % force to be at least nDimsManual
            if ~isempty(sv.ndimsManual)
                nDims = max(nDims, sv.ndimsManual);
            end
        end

        function dims = get.dims(sv)
            if sv.isVariable
                dims = -1 * ones(1, sv.nDims);
            else
                dims = ones(1, sv.nDims);

                if sv.isBus
                    dims(1:numel(sv.maxSize)) = sv.maxSize;
                elseif isvector(sv.value)
                    dims(1) = numel(sv.value);
                else
                    dims(1:numel(size(sv.value))) = size(sv.value);
                end
            end
        end

        function bytes = get.bytesPerElement(sv)
            if sv.isBus
                bytes = [];
            elseif strcmp(sv.classForSerialization, 'logical') || strcmp(sv.classForSerialization, 'char')
                bytes = 1;
            else
                bytes = numel(typecast(zeros(1, sv.classForSerialization), 'uint8'));
            end
        end

        % enum utilities
        function maxLen = getEnumMaxLengthAsString(sv)
            assert(sv.isEnum, 'Not enum type');
            maxLen = BusSerialize.getEnumMaxLengthAsString(sv.enumName);
        end

        function vals = getEnumMemberValueStruct(sv)
            assert(sv.isEnum, 'Not enum type');
            vals = BusSerialize.getEnumAsValueStruct(sv.enumName);
        end

        function defString = getEnumDefaultValueAsString(sv)
            assert(sv.isEnum, 'Not enum type');
            defString = BusSerialize.getEnumDefaultValueAsString(sv.enumName);
        end

        function bf = get.bitFlagsForSerialization(sv)
            bf = uint8(0);
            if sv.isVariable
                bf = bitset(bf, 1);
            end
            if sv.concatLastDim
                bf = bitset(bf, 2);
            end
        end

        function tf = get.isPulse(sv)
            tf = sv.type == BusSerialize.SignalTypes.Pulse;
        end
    end

    methods(Static) % Special builder methods, user should call these
        % overwriting model timestamp with our own for this group as uint32
        function sv = Timestamp(value, varargin)
            % SIGNAL_TYPE_TIMESTAMPOFFSET must be type single for data logger
            assert(isa(value, 'uint32'), 'Timestamp signals must have class uint32');
            sv = BusSerialize.SignalSpec.Param(value, varargin{:});
            sv.type = BusSerialize.SignalTypes.Timestamp;
            sv.units = 'ms';
        end

        function sv = TimestampVectorVariable(value, maxLen, varargin)
            assert(isa(value, 'uint32'), 'Timestamp signals must have class uint32');
            sv = BusSerialize.SignalSpec.ParamVectorVariable(value, maxLen, varargin{:});
            sv.type = BusSerialize.SignalTypes.Timestamp;
            sv.units = 'ms';
        end

        % correcting timestamps by ms
        function sv = TimestampOffset(value, varargin)
            % SIGNAL_TYPE_TIMESTAMPOFFSET must be type single for data logger
            assert(isa(value, 'single'), 'Timestamp offset signals must have class single');
            sv = BusSerialize.SignalSpec.Param(value, varargin{:});
            sv.type = BusSerialize.SignalTypes.TimestampOffset;
            sv.units = 'ms';
        end

        function sv = TimestampOffsetVectorVariable(value, maxLen, varargin)
            assert(isa(value, 'single'), 'Timestamp offset signals must have class single');
            sv = BusSerialize.SignalSpec.ParamVectorVariable(value, maxLen, varargin{:});
            sv.type = BusSerialize.SignalTypes.TimestampOffset;
            sv.units = 'ms';
        end

        % represents a nested bus field
        function sv = Bus(busName, varargin)
            p = inputParser();
            p.KeepUnmatched = true;
            p.addOptional('value', struct(), @(x) isstruct(x) || isempty(x));
            p.parse(varargin{:});

            sv = BusSerialize.SignalSpec('value', p.Results.value, 'isBus', true, ...
                'busName', busName, p.Unmatched);
        end

        % switch on for 1 tick, then back off
        function sv = PulseSwitch()
            sv = BusSerialize.SignalSpec.Analog(uint8(0), '', 'resetImmediately', true);
        end

        function sv = ToggleSwitch(value)
            if nargin < 1
                value = false;
            end
            sv = BusSerialize.SignalSpec.ParamBoolean(value);
        end
    end

    methods(Static) % Param builder methods
        % Parameter field whose type / size is determined by value
        % use 'isVariableByDim' logical array and 'maxSize' to specify
        % variable size fields
        function sv = Param(value, varargin)
            p = inputParser();
            p.KeepUnmatched = true;
            p.addOptional('units', '', @ischar);
            p.parse(varargin{:});
            sv = BusSerialize.SignalSpec('type', BusSerialize.SignalTypes.Param, ...
                'value', value, 'units', p.Results.units, p.Unmatched);
        end

        % Logical scalar paramter
        function sv = ParamBoolean(value, varargin)
            % okay to pass logical type into param as well
            value = logical(value);
            sv = BusSerialize.SignalSpec('type', BusSerialize.SignalTypes.Param, ...
                'value', uint8(value), 'units', '', varargin{:});
        end

        % Fixed-size string parameter
        function sv = ParamString(value, varargin)
            value = char(value);
            sv = BusSerialize.SignalSpec('type', BusSerialize.SignalTypes.Param, ...
                'value', value, 'units', '', 'concatLastDim', false, varargin{:});
        end

        % Variable size string parameter
        function sv = ParamStringVariable(value, maxLen, varargin)
            value = char(value);
            sv = BusSerialize.SignalSpec('type', BusSerialize.SignalTypes.Param, ...
                'value', value, 'units', '', 'isVariableByDim', true, 'maxSize', maxLen, ...
                'concatLastDim', false, varargin{:});
        end

        % Variable size vector paramter
        function sv = ParamVectorVariable(value, maxLen, varargin)
            p = inputParser();
            p.KeepUnmatched = true;
            p.addOptional('units', '', @ischar);
            p.parse(varargin{:});
            value = BusSerialize.makecol(value);
            sv = BusSerialize.SignalSpec('type', BusSerialize.SignalTypes.Param, ...
                'value', value, 'units', p.Results.units, 'isVariableByDim', true, ...
                'maxSize', maxLen, p.Unmatched);
        end

        function sv = ParamEnum(enumName, varargin)
            % signal will be of type Enum: enumName
            % assumes that the enum type already exists

            p = inputParser();
            p.addOptional('value', [], @(x) isa(x, enumName));
            p.KeepUnmatched = true;
            p.parse(varargin{:});

            % use either empty or default value if not specified, empty is
            % when the length is variable. Can't use .empty in codegen as
            % of R2015a
            v = p.Results.value;
            if isempty(v)
%                 if isfield(p.Unmatched, 'isVariableByDim') && any(p.Unmatched.isVariableByDim)
%                     v = eval([enumName '.empty()']);
%                 else
                    v = eval([enumName '.getDefaultValue()']);
%                 end
            end

            % a value specified with a Simulink enum type
            sv = BusSerialize.SignalSpec('type', BusSerialize.SignalTypes.Param, ...
                'value', v, 'isEnum', true, 'enumName', enumName, 'concatLastDim', false, p.Unmatched);
        end

        function sv = ParamEnumVectorVariable(enumName, maxLen, varargin)
            sv = BusSerialize.SignalSpec.ParamEnum(enumName, 'isVariableByDim', true, 'maxSize', maxLen, varargin{:});
        end

        function sv = Analog(value, varargin)
            p = inputParser();
            p.KeepUnmatched = true;
            p.addOptional('units', '', @ischar);
            p.parse(varargin{:});
            sv = BusSerialize.SignalSpec('type', BusSerialize.SignalTypes.Analog, ...
                'value', value, 'units', p.Results.units, p.Unmatched);
        end

        function sv = AnalogVectorMultiChannel(value, varargin)
            sv = BusSerialize.SignalSpec.Analog(value, varargin{:}, 'ndimsManual', 2); % manually ensure concatenation is over columns
        end

        function sv = AnalogEnum(enumName, varargin)
            % signal will be of type Enum: enumName
            % assumes that the enum type already exists

            p = inputParser();
            p.addOptional('value', [], @(x) isa(x, enumName));
            p.KeepUnmatched = true;
            p.parse(varargin{:});

            % use either empty or default value if not specified, empty is
            % when the length is variable. Can't use .empty in codegen
            v = p.Results.value;
            if isempty(v)
%                 if isfield(p.Unmatched, 'isVariableByDim') && any(p.Unmatched.isVariableByDim)
%                     v = eval([enumName '.empty()']);
%                 else
                    v = eval([enumName '.getDefaultValue()']);
%                 end
            end

            % a value specified with a Simulink enum type
            sv = BusSerialize.SignalSpec('type', BusSerialize.SignalTypes.Analog, ...
                'value', v, 'isEnum', true, 'enumName', enumName, 'concatLastDim', false, p.Unmatched);
        end

        function sv = AnalogEnumVectorVariable(enumName, maxLen, varargin)
            sv = BusSerialize.SignalSpec.AnalogEnum(enumName, 'isVariableByDim', true, 'maxSize', maxLen, varargin{:});
        end

        function sv = EventEnumQueueVariable(eventEnumName, maxLen, varargin)
            sv = BusSerialize.SignalSpec.AnalogEnumVectorVariable(eventEnumName, maxLen, varargin{:});
        end

        function sv = AnalogBoolean(value, varargin)
            % okay to pass logical type into param as well
            value = logical(value);
            sv = BusSerialize.SignalSpec('type', BusSerialize.SignalTypes.Analog, ...
                'value', uint8(value), 'units', '', varargin{:});
        end

        function sv = AnalogVectorVariable(value, maxLen, varargin)
            sv = BusSerialize.SignalSpec.ParamVectorVariable(value, maxLen, varargin{:});
            sv.type = BusSerialize.SignalTypes.Analog;
        end
    end

    methods(Static) % Builder methods for trial event buses
        function sv = EventNameEnum(enumName, varargin)
            % signal will be of type Enum: enumName
            % assumes that the enum type already exists

            % get default value
            v = eval([enumName '.getDefaultValue()']);

            % a value specified with a Simulink enum type
            sv = BusSerialize.SignalSpec('type', BusSerialize.SignalTypes.EventName, ...
                'value', v, 'isEnum', true, 'enumName', enumName);
        end

        function sv = EventTag(varargin)
            % like a per-event occurrence parameter, i.e. a specific value
            % associated with a specific event occurrence
            % see .Param for signature
            sv = BusSerialize.Param(varargin{:});
            sv.type = BusSerialize.SignalTypes.EventTag;
        end

        function sv = EventTagEnum(varargin)
            % like a per-event occurrence parameter, i.e. a specific value
            % associated with a specific event occurrence
            % see .ParamEnum for signature
            sv = BusSerialize.ParamEnum(varargin{:});
            sv.type = BusSerialize.SignalTypes.EventTag;
        end

        function sv = EventTagString(varargin)
            % like a per-event occurrence parameter, i.e. a specific value
            % associated with a specific event occurrence
            % see .ParamString for signature
            sv = BusSerialize.ParamString(varargin{:});
            sv.type = BusSerialize.SignalTypes.EventTag;
        end

        % Variable size string parameter
        function sv = EventTagStringVariable(varargin)
            % like a per-event occurrence parameter, i.e. a specific value
            % associated with a specific event occurrence
            % see .ParamStringVariable for signature
            sv = BusSerialize.ParamStringVariable(varargin{:});
            sv.type = BusSerialize.SignalTypes.EventTag;
        end

        % Variable size vector paramter
        function sv = EventTagVectorVariable(varargin)
            % like a per-event occurrence parameter, i.e. a specific value
            % associated with a specific event occurrence
            % see .ParamVectorVariable for signature
            sv = BusSerialize.ParamVectorVariable(varargin{:});
            sv.type = BusSerialize.SignalTypes.EventTag;
        end
    end

end
