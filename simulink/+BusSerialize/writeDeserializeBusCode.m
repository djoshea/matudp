function writeDeserializeBusCode(busName, varargin)
% writeDeserializeBusCode(busName, ['forMatlab', false/true])
% if forMatlab is false (default):
%     writes an m-file deserializeBus_*BusName* which can deserialize a scalar bus
%     from a uint8 bytestream leaving char and logical types as uint8 signals
%
% if forMatlab is true:
%     writes an m-file deserializeBusForMatlab_*BusName* which can deserialize a scalar bus
%     from a uint8 bytestream, converting char and logical signals back to
%     char and logical from uint8
%

    p = inputParser();
    p.addParamValue('forMatlab', false, @islogical);
    p.parse(varargin{:});
    forMatlab = p.Results.forMatlab;

    % write to temp file, copy later if files differ
    if forMatlab
        fnName = sprintf('deserializeBusForMatlab_%s', busName);
    else
        fnName = sprintf('deserializeBus_%s', busName);
    end
    fileName = BusSerialize.getGeneratedCodeFileName(fnName);
    temp = tempname();
    fid = fopen(temp, 'w+');
    
    [busObject, busSpec] = BusSerialize.getBusFromBusName(busName);
    elements = busObject.Elements;
    
    w = @(varargin) BusSerialize.writeReplaceNewline(fid, varargin{:});
    
    w('function [bus, valid, offset] = %s(input, offset, valid, namePrefix)\n', fnName);
    w('%%#codegen\n');
    w('%% DO NOT EDIT: Auto-generated by \n');
    w('%%   BusSerialize.writeDeserializeBusCode(''%s'')\n', busName);
    w('\n');
    
    w('    in = typecast(input, ''uint8'');\n');
    w('    if nargin < 2\n');
    w('         offset = uint32(1);\n');
    w('    end\n');
    w('    if nargin < 3\n');
    w('         valid = uint8(1);\n');
    w('    end\n');
    w('    if nargin < 4\n');
    w('        namePrefix = uint8('''');\n');
    w('    end\n');
    w('    offset = uint32(offset);\n');
    w('\n');
    
    % first, initialize the bus to default
    w('    bus = initializeBus_%s();\n', busName);
    
    for iElement = 1:numel(elements)
        e = elements(iElement);
        
        signalSpec = busSpec.signals(iElement);

        % compute total number of elements
        numElements = prod(e.Dimensions);

        if signalSpec.isEnum
            if numElements~= 1
                a = 1;
            end
        end
        
        % compute string to use for dimensions
        dims = e.Dimensions;
        ndims = numel(dims);
        if ndims == 1
            dimsStr = mat2str([dims 1]);
            dimsForEmpty = [dims 1];
        else
            dimsStr = mat2str(dims);
            dimsForEmpty = dims;
        end
        dimsForEmpty(signalSpec.isVariableByDim) = 0;
        
        isVariable = strcmp(e.DimensionsMode, 'Variable');
        isBus = strncmp(e.DataType, 'Bus:', 4);

        % write comment separating this variable in code
        w(['    ', repmat('%%', 1, 60), '\n']);
        if isVariable
            % variable sized array
            w('    %% Deserializing variable-sized field %s\n', e.Name);
        elseif isBus
            % fixed size nested bus
            innerBusName = BusSerialize.parseBusDataTypeStr(e.DataType);
             w('    %% Deserializing fixed-size field %s as nested Bus: %s\n', ...
                 e.Name, innerBusName);
        else
            % non variable size array, compute total number of elements
            w('    %% Deserializing fixed-sized field %s\n', e.Name);
        end
        w(['    ', repmat('%%', 1, 60), '\n\n']);
           
        if ~isBus
            w('    %% Checking header\n');
            %check if enough bytes to read the bitFlags, signal type,
            % name, units,
            % data type id, and nDims
            nBytesSansPrefix = 1 + 1 + 2 + numel(e.Name) + 2 + numel(e.DocUnits) + 1 + 1;
            w('    if valid == uint8(0) || offset + uint32(%d + numel(namePrefix) - 1) > numel(in)\n', nBytesSansPrefix);
            w('        valid = uint8(0);\n');
            w('    end\n');

            % compare to known header: bitFlags, signal type, concat dimension, 
            % name, units,
            % data typeid, nDims
            bitFlags = uint8(signalSpec.bitFlagsForSerialization);
            sigType = uint8(signalSpec.type);
%             concatDim = signalSpec.concatDim;
%             if isempty(concatDim)
%                 concatDim = uint8(0);
%             end

            if signalSpec.isEnum
                dtid = getDataTypeIdFromName('char');
            else
                dtid = getDataTypeIdFromName(signalSpec.class);
            end
                
            ndims = numel(e.Dimensions);
            
            w('    expectedHeader_%s = uint8([%d, %d, typecast(uint16(numel(namePrefix) + %d), ''uint8''), namePrefix, ''%s'', typecast(uint16(%d), ''uint8''), ''%s'', %d, %d])'';\n', ...
                e.Name, bitFlags, sigType, numel(e.Name), e.Name, ...
                numel(e.DocUnits), e.DocUnits, dtid, ndims);
            w('    for headerOffset = 1:uint32(%d+numel(namePrefix)-1)\n', nBytesSansPrefix);
            w('        valid = uint8(valid && in(offset+headerOffset-1) == expectedHeader_%s(headerOffset));\n', e.Name);
            w('    end\n');
            
%             w('    if valid == uint8(0) || ~isequal(in(offset:offset+uint32(%d-1)), ...\n', nBytes);
%             w('        valid = uint8(0);\n');
%             w('    end\n');
            w('    offset = offset + uint32(%d + numel(namePrefix));\n', nBytesSansPrefix);
            w('\n');
            
            w('    %% Establishing size\n');
            
            if isVariable % && ~signalSpec.isEnum
                % specify upper bounds on size before populating
                w('    coder.varsize(''bus.%s'', %s);\n', e.Name, mat2str(signalSpec.maxSize));
            end

            % check whether the buffer is large enough to read the size
            bytesSize = 2 * ndims;
            w('    if valid == uint8(0) || offset + uint32(%d - 1) > numel(in)\n', bytesSize);
            % buffer not large enough, fill with zeros
            w('        %% buffer not large enough for header\n');
            w('        valid = uint8(0);\n');
            if signalSpec.isEnum
                % create array of enum type with default value
                w('        bus.%s = repmat(%s.%s, %s);\n', e.Name, signalSpec.enumName, signalSpec.getEnumDefaultValueAsString(), dimsStr);
                %w('        bus.%s = %s.%s;\n', e.Name, signalSpec.enumName, signalSpec.getEnumDefaultValueAsString());
            else
                w('        bus.%s = zeros(%s, ''%s'');\n', e.Name, dimsStr, e.DataType);
            end
            w('    else\n');

            % buffer is okay, extract dimensions
            w('        sz = typecast(in(offset:(offset+uint32(%d-1))), ''uint16'')'';\n', bytesSize);
            w('        offset = offset + uint32(%d);\n', bytesSize);

            w('        %% check size\n');
            
           % w('        if sz(1) > uint16(%d), valid = uint8(0); end %% max enum member length as string\n', signalSpec.getEnumMaxLengthAsString());

            if signalSpec.isEnum
                % check dimensions aren't too large
                w('        if prod(sz) > uint16(%d), valid = uint8(0); end\n', prod(dims) * signalSpec.getEnumMaxLengthAsString());
            elseif isVariable
                % check dimensions aren't too large
                for iDim = 1:ndims
                    w('        if sz(%d) > uint16(%d), valid = uint8(0); end\n', iDim, dims(iDim));
                end
            else
                % check dimensions match
                for iDim = 1:ndims
                    w('        if sz(%d) ~= uint16(%d), valid = uint8(0); end\n', iDim, dims(iDim));
                end
            end

            % compute total number of elements
            w('        elements = uint32(1);\n');
            w('        for i = 1:%d\n', ndims);
            w('             elements = elements * uint32(sz(i));\n');
            w('        end\n');

            bytesPerElement = signalSpec.bytesPerElement;

            % check whether buffer is long enough for data
            w('        if elements > uint32(0) && offset + uint32(elements*%d - 1) > numel(in)\n', bytesPerElement);
            w('            %% buffer not large enough for data\n');
            w('            valid = uint8(0);\n');
            w('        end\n');
 
            w('        if valid && elements == uint32(0)\n');
            w('            %% assigning empty value\n');
            if signalSpec.isEnum
                if isVariable
                    w('            bus.%s = %s.empty(%s);\n', e.Name, signalSpec.enumName, mat2str(dimsForEmpty));
                else
                    w('            bus.%s = repmat(%s.%s, %s);\n', e.Name, signalSpec.enumName, signalSpec.getEnumDefaultValueAsString(), dimsStr);
                end
            elseif isVariable
                w('            bus.%s = zeros(%s, ''%s'');\n', e.Name, mat2str(dimsForEmpty), e.DataType);
            else
                w('            bus.%s = zeros(%s, ''%s'');\n', e.Name, dimsStr, e.DataType);
            end
            w('        else\n');

            % we've already checked the sizes, but add assert statements to
            % mollify codegen
            if isVariable && ~signalSpec.isEnum
                w('            %% mollify codegen\n');
                for iDim = 1:ndims
                    w('            assert(sz(%d) <= uint16(%d));\n', iDim, dims(iDim));
                end
            end
            w('            %% read and typecast data\n');
            
            if signalSpec.isEnum
                w('            assert(elements <= uint32(%d));\n', signalSpec.getEnumMaxLengthAsString() * prod(signalSpec.maxSize));
            else
                w('            assert(elements <= uint32(%d));\n', numElements);
            end

            % pre-initialize value
            if signalSpec.isEnum
                 if isVariable
                    w('            bus.%s = %s.empty(%s);\n', e.Name, signalSpec.enumName, mat2str(dimsForEmpty));
                else
                    w('            bus.%s = repmat(%s.%s, %s);\n', e.Name, signalSpec.enumName, signalSpec.getEnumDefaultValueAsString(), dimsStr);
                end
            elseif isVariable
                if ndims == 1
                    w('            bus.%s = zeros([sz uint16(1)], ''%s'');\n', e.Name, e.DataType);
                else
                    w('            bus.%s = zeros(sz, ''%s'');\n', e.Name, e.DataType);
                end
            else
                w('            bus.%s = zeros(%s, ''%s'');\n', e.Name, dimsStr, e.DataType);
            end
            
            % make appropriate conversions for matlab mode
            if forMatlab
                if signalSpec.isChar
                    w('            bus.%s = char(bus.%s);\n', e.Name, e.Name);
                    w('            if isempty(bus.%s), bus.%s = ''''; end\n', e.Name, e.Name);
                elseif signalSpec.isLogical
                    w('            bus.%s = logical(bus.%s);\n', e.Name, e.Name);
                end
            end
            
            w('            if elements > uint32(0)\n');
            % handle enum case separately since we'll convert back to
            % string
            if signalSpec.isEnum
                % for enums, convert to string and then serialize the string
                enumFnName = BusSerialize.getGeneratedCodeFunctionName(sprintf('semicolonDelimitedStringToEnumVector_%s', signalSpec.enumName));
                %enumStruct = BusSerialize.getEnumAsValueStruct(signalSpec.enumName);
                %enumStrMaxSize = max(cellfun(@numel, fieldnames(enumStruct)));
                tempEnumVecName = sprintf('tempVar_%s', e.Name);
                w('                coder.varsize(''%s'', %d);\n', tempEnumVecName, prod(dims));
                w('                %s = repmat(%s.%s, %s);\n', tempEnumVecName, signalSpec.enumName, signalSpec.getEnumDefaultValueAsString(), dimsStr);
                w('                [%s, nValues, valueValid] = %s(typecast(in(offset:offset+uint32(elements*%d - 1))'', ''uint8'')'',%s);\n', tempEnumVecName, enumFnName, bytesPerElement, tempEnumVecName);
                
                if isVariable
                    w('                if nValues < %d\n', prod(dims))
                    w('                    bus.%s = %s(uint32(1):nValues);\n', e.Name, tempEnumVecName);
                    w('                end\n');
                else
                    w('                bus.%s = repmat(%s.%s, %s);\n', e.Name, signalSpec.enumName, signalSpec.getEnumDefaultValueAsString(), dimsStr);
                    w('                if nValues < %d\n', prod(dims))
                    w('                    bus.%s(uint32(1):nValues) = %s(uint32(1):nValues);\n', e.Name, tempEnumVecName);
                    w('                end\n');
                end 
                
                % the double transpose shenanigans are a workaround for a
                % bug involving typecast, variable-length row vectors, and
                % code generation size inference
%                 w('                [bus.%s, valueValid] = %s(typecast(in(offset:offset+uint32(elements*%d - 1))'', ''uint8'')'');\n', ...
%                     e.Name, enumFnName, bytesPerElement);
                
                if forMatlab
                    % if enum value isn't valid, just leave it as char
                    % rather than using the default value
                    w('                if ~valueValid %% unknown enum value, leaving as char only for Matlab\n');
                    w('                    bus.%s = typecast(in(offset:offset+uint32(elements*%d - 1)), ''char'');\n', e.Name, bytesPerElement);
                    w('                end\n');
                else
                    w('                if ~valueValid, valid = uint8(0); end\n'); 
                end
            else
                if forMatlab
                    % convert char / logical back to original class
                    if signalSpec.isLogical
                        w('                bus.%s = logical(in(offset:offset+uint32(elements*%d - 1)));\n', ...
                            e.Name, bytesPerElement);
                    elseif signalSpec.isChar
                        w('                bus.%s = char(in(offset:offset+uint32(elements*%d - 1)));\n', ...
                            e.Name, bytesPerElement);
                        % transpose into row vector
                        w('                if size(bus.%s, 1) > size(bus.%s, 2) && size(bus.%s, 2) == 1, bus.%s = bus.%s''; end\n', ...
                            e.Name, e.Name, e.Name, e.Name, e.Name);
                    else
                        w('                bus.%s(1:elements) = typecast(in(offset:offset+uint32(elements*%d - 1))'', ''%s'')'';\n', ...
                            e.Name, bytesPerElement, signalSpec.class); 
                    end
                else
                    % if ~forMatlab, keep char & logical as uint8
                    w('                bus.%s(1:elements) = typecast(in(offset:offset+uint32(elements*%d - 1))'', ''%s'')'';\n', ...
                        e.Name, bytesPerElement, e.DataType); 
                end
                
            end
            w('                offset = offset + uint32(elements*%d);\n', bytesPerElement);
            w('            end\n');
            w('        end\n');
            w('    end\n');
            
        else
            % bus variable!
            innerBusName = BusSerialize.parseBusDataTypeStr(e.DataType);
            deserializeFnName = BusSerialize.getGeneratedCodeFunctionName(sprintf('deserializeBus_%s', innerBusName));
            
            % handle nested bus deserialization
            % note that bus arrays must have fixed length

            % we loop over the elements and store each one into the bus
            % array
            w('    %% deserialize each bus element within\n');
            if numElements > 1
                % pre-initialize the array so that we can repmat it
                w('    subNamePrefix = uint8([namePrefix, ''%s1_'']);\n', e.Name);
                w('    [busInitializer_%s, valid, offset] = %s(in, offset, valid, subNamePrefix);\n', e.Name, deserializeFnName);
                w('    bus.%s = repmat(busInitializer_%s(1), %s);\n', e.Name, e.Name, dimsStr);

                % loop over the partial matrix elements
                w('    iSubElement = uint32(2);\n');
                w('    while iSubElement <= uint32(%d) && valid == uint8(1)\n', numElements);
                % this element is okay, actually deserialize it
                w('        subNamePrefix = uint8([namePrefix, ''%s'' str2num(iSubElement) ''_'']);\n', e.Name);
                w('        [bus.%s(iSubElement), valid, offset] = %s(in, offset, valid, subNamePrefix);\n', ...
                    e.Name, deserializeFnName);
                w('        iSubElement = iSubElement + uint32(1);\n');
                w('    end\n');

            else
                % scalar bus, simply assign it in place
                w('    subNamePrefix = uint8([namePrefix, ''%s_'']);\n', e.Name);
                w('    [bus.%s, valid, offset] = %s(in, offset, valid, subNamePrefix);\n', ...
                        e.Name, deserializeFnName);
            end

            % also write this nested bus's deserialize fn
            BusSerialize.writeDeserializeBusCode(innerBusName);
        end
        w('\n');
    end
    
    w('\n');
    w('end');
    
    fclose(fid);
    
    % copy now if files differed
    update = BusSerialize.overwriteIfFilesDiffer(temp, fileName);
    delete(temp);
    if update
        fprintf('BusSerialize: Updating %s\n', fnName);
    end
end

function id = getDataTypeIdFromName(name)
    types = {'double', 'single', 'int8', 'uint8', 'int16', 'uint16', ...
        'int32', 'uint32', 'char', 'logical'};
    [tf, which] = ismember(name, types);
    assert(tf, 'Unsupported data type %s', name);
    id = which - 1;
end
