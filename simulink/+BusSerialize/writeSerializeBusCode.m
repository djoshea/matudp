function writeSerializeBusCode(busName, varargin)
% writes an m-file serializeBus_*BusName* which can serialize a scalar bus
% to a uint8 bytestream via bytePackInBuffer. if includeDataLoggerHeader is
% true, writes a function serializeBusWithDataLoggerHeader_*BusName* that
% takes additional arguments group name, group type, and timestamp
%
% N.B. Be careful when changing the serialization format. You will need to
% update writeDeserializeBusCode, computeMaxSerializedBusLength, and
% writeGetSerializedBusLengthCode, as well as adjusting the data logger and
% udpMexReceiver to match the new format.

    p = inputParser();
    p.addParamValue('includeDataLoggerHeader', false, @islogical);
    p.parse(varargin{:});
    
    includeDataLoggerHeader = p.Results.includeDataLoggerHeader;

    % first, write the getSerializedBusLength function so we can call it
    BusSerialize.writeGetSerializedBusLengthCode(busName);

    % write to temp file, copy later if files differ
    if includeDataLoggerHeader
        fnName = sprintf('serializeBusWithDataLoggerHeader_%s', busName);
    else
        fnName = sprintf('serializeBus_%s', busName);
    end
    fileName = BusSerialize.getGeneratedCodeFileName(fnName);
    temp = tempname();
    fid = fopen(temp, 'w+');
    
    w = @(varargin) BusSerialize.writeReplaceNewline(fid, varargin{:});
    
    [busObject, busSpec] = BusSerialize.getBusFromBusName(busName);
    if isempty(busObject)
        error('Bus %s not found', busName);
    end
    
    elements = busObject.Elements;
    [maxBufferLen, isVariable] = BusSerialize.computeMaxSerializedBusLength(busName);
    
    if includeDataLoggerHeader
        w('function [out, valid] = %s(bus, groupType, groupName, timestamp, namePrefix)\n', fnName);
    else
        w('function [out, valid] = %s(bus, namePrefix)\n', fnName);
    end
    w('%%#codegen\n');
    w('%% DO NOT EDIT: Auto-generated by \n');
    w('%%   BusSerialize.writeSerializeBusCode(''%s'')\n', busName);
    w('\n');
    
    if includeDataLoggerHeader
        w('    if nargin < 5, namePrefix = uint8(''''); end\n');
    else
        w('    if nargin < 2, namePrefix = uint8(''''); end\n');
    end
    w('    namePrefixBytes = uint8(namePrefix(:))'';\n');
    w('    valid = uint8(0);\n');
    
    if includeDataLoggerHeader
        % compute length of data logger header
        w('    headerLength = uint32(BusSerialize.computeDataLoggerHeaderLength(uint8([namePrefixBytes, groupName])));\n');
    end
    
    if isVariable
        % use coder.varsize to establish an upper bound on the output
        if includeDataLoggerHeader
            % include header length (fixed) in max size
            w('    coder.varsize(''out'', %d + headerLength);\n', maxBufferLen);
        else
            w('    coder.varsize(''out'', %d);\n', maxBufferLen);
        end
    end
    
    % first, compute the size needed for the output buffer
    lenFnName = BusSerialize.getGeneratedCodeFunctionName(sprintf('getSerializedBusLength_%s', busName));
    if includeDataLoggerHeader
        w('    outSize = headerLength + %s(bus, namePrefix);\n', lenFnName);
    else
        w('    outSize = %s(bus, namePrefix);\n', lenFnName);
    end
    
    % declare the output buffer to this size
    w('    out = zeros(outSize, 1, ''uint8'');\n');
    w('    offset = uint32(1);\n');
    w('\n');
    
    if includeDataLoggerHeader
        w('    %% Serialize data logger header\n');
        nSignals = BusSerialize.computeBusNumSignalsFlattened(busName);
        configHash = busSpec.computeConfigurationHash();
        w('    header = BusSerialize.serializeDataLoggerHeader(groupType, uint8([namePrefixBytes, groupName]), uint32(%d), uint16(%d), timestamp);\n', configHash, nSignals);
        w('    out(1:headerLength) = uint8(header);\n');
        w('    offset = offset + headerLength;\n');
        w('\n');
    end
    
    % now loop over the elements and serialize them in place 
    for iElement = 1:numel(elements)
        e = elements(iElement);
        
        signalSpec = busSpec.signals(iElement);
        
        dims = e.Dimensions;
        numElements = prod(dims);
        ndims = numel(dims);
        
        isVariable = strcmp(e.DimensionsMode, 'Variable');
        isBus = strncmp(e.DataType, 'Bus:', 4);
        
        if ~isBus
            w(['    ', repmat('%%', 1, 70), '\n']);
            if isVariable
                w('    %% Serialize variable-sized %s\n', e.Name);
            else
                w('    %% Serialize fixed-sized %s\n', e.Name);
            end
            w(['    ', repmat('%%', 1, 70), '\n\n']);
            name = e.Name;
            
            % first make assertions about the size
            w('    %% Check input size is valid\n');
            if ndims == 1
                if signalSpec.isVariableByDim(1)
                    w('    assert(numel(bus.%s) <= %d, ''numel(bus.%s) exceeds max size of %d'');', ...
                            e.Name, signalSpec.maxSize(1), e.Name, signalSpec.maxSize(1));
                else
                    w('    assert(numel(bus.%s) == %d, ''numel(bus.%s) must be %d'');', ...
                            e.Name, numel(signalSpec.value), e.Name, numel(signalSpec.value));
                end
            else
                w('    assert(ndims(bus.%s) == %d, ''ndims(bus.%s) must be %d'');', ...
                    e.Name, ndims, e.Name, ndims);
                for iDim = 1:ndims
                    if signalSpec.isVariableByDim(iDim)
                        w('    assert(size(bus.%s, %d) <= %d, ''size(bus.%s, %d) exceeds max size of %d'');', ...
                            e.Name, iDim, signalSpec.maxSize(iDim), e.Name, iDim, signalSpec.maxSize(iDim));
                    else
                        w('    assert(size(bus.%s, %d) == %d, ''size(bus.%s, %d) must be %d'');', ...
                            e.Name, iDim, size(signalSpec.value, iDim), e.Name, iDim, size(signalSpec.value, iDim));
                    end
                end
            end

            % serialize the bit flag
            bitFlags = uint8(signalSpec.bitFlagsForSerialization);
            w('    %% %s bitFlags\n', name);
            w('    if(offset > numel(out)), return, end\n');    
            w('    out(offset) = uint8(%d);\n', bitFlags);
            w('    offset = offset + uint32(1);\n');
            w('\n');

            % serialize the signal type
            w('    %% %s signal type\n', name);
            w('    if(offset > numel(out)), return, end\n');    
            w('    out(offset) = uint8(%d);\n', uint8(signalSpec.type));
            w('    offset = offset + uint32(1);\n');
            w('\n');
            
%             % serialize the concatenation dimension
%             concatDim = signalSpec.concatDim;
%             if isempty(concatDim)
%                 concatDim = uint8(0);
%             end
%             w('    %% %s concatenation dimension\n', name);
%             w('    if(offset > numel(out)), return, end\n');    
%             w('    out(offset) = uint8(%d);\n', concatDim);
%             w('    offset = offset + uint32(1);\n');
%             w('\n');
            
            % serialize the nameLength as uint16 and then the name
            nName = numel(name);
            w('    %% %s name with prefix \n', name);
            w('    if(offset+uint32(2+%d -1) > numel(out)), return, end\n', nName);
            w('    out(offset:(offset+uint32(1))) = typecast(uint16(numel(namePrefixBytes) + %d), ''uint8'');\n', nName);
            w('    offset = offset + uint32(2);\n');
            w('    out(offset:(offset+uint32(numel(namePrefixBytes) + %d-1))) = [namePrefixBytes, uint8(''%s'')];\n', nName, e.Name);
            w('    offset = offset + uint32(numel(namePrefixBytes) + %d);\n', nName);
            w('\n');

            % serialize the unitsLength as uint16 and then the units
            units = e.DocUnits;
            nUnits = numel(units);
            w('    %% %s units\n', name);
            w('    if(offset+uint32(2+%d -1) > numel(out)), return, end\n', nUnits);
            w('    out(offset:(offset+uint32(1))) = typecast(uint16(%d), ''uint8'');\n', nUnits);
            w('    offset = offset + uint32(2);\n');
            if nUnits > 0
                w('    out(offset:(offset+uint32(%d-1))) = uint8(''%s'');\n', nUnits, units);
                w('    offset = offset + uint32(%d);\n', nUnits);
            end
            w('\n');

            % write the data type id, as uint8
            dtid = getDataTypeIdFromName(signalSpec.classForSerialization);
            w('    %% %s data type id\n', name);
            w('    if(offset > numel(out)), return, end\n', nUnits);
            w('    out(offset) = uint8(%d); %% data type is %s\n', dtid, signalSpec.class);
            w('    offset = offset + uint32(1);\n');
            w('\n');

            % write the current dimensions as uint16s, even for fixed length
            % arrays
            w('    %% %s dimensions\n', name);
            w('    if(offset > numel(out)), return, end\n');
            w('    if(offset+uint32(1+2*%d-1) > numel(out)), return, end\n', ndims);
            % one byte number of dimensions
            w('    out(offset) = uint8(%d);\n', ndims);
            w('    offset = offset + uint32(1);\n');

            if signalSpec.isEnum
                % for enums, convert to string and then serialize the
                % string, using the dimensions of the string as the
                % indicated dimensions
                enumFnName = BusSerialize.getGeneratedCodeFunctionName(sprintf('enumToString_%s', signalSpec.enumName));
                enumStruct = BusSerialize.getEnumAsValueStruct(signalSpec.enumName);
                enumStrMaxSize = max(cellfun(@numel, fieldnames(enumStruct)));
                enumStrVarName = sprintf('enumAsStr_%s', e.Name);
                
                w('    %% converting enum type %s to string\n', signalSpec.enumName);
                w('    coder.varsize(''%s'', %d);\n', enumStrVarName, enumStrMaxSize);
                
                % loop over elements of the signal and concatenate the string versions of each enum value with ;
                w('    %s = zeros(0, 1, ''uint8'');\n', enumStrVarName);
                w('    for iEnum = 1:numel(bus.%s)\n', e.Name);
                w('        %s = [%s; uint8(%s(bus.%s(iEnum)))'']; %%#ok<AGROW>\n', enumStrVarName, enumStrVarName, enumFnName, e.Name); % convert to column vector
                w('        if iEnum < numel(bus.%s)\n', e.Name);
                w('            %s = [%s; uint8('';'')]; %%#ok<AGROW>\n', enumStrVarName, enumStrVarName);
                w('        end\n');
                w('    end\n');
                
                ndims = 1;
                w('    out(offset:(offset+uint32(2*%d-1))) = typecast(uint16(numel(%s)), ''uint8'');\n', ndims, enumStrVarName);
                
            elseif ndims == 1
                w('    out(offset:(offset+uint32(2*%d-1))) = typecast(uint16(numel(bus.%s)), ''uint8'');\n', ndims, e.Name);
            else
                w('    out(offset:(offset+uint32(2*%d-1))) = typecast(uint16(size(bus.%s)), ''uint8'');\n', ndims, e.Name);
            end
            w('    offset = offset + uint32(2*%d);\n', ndims);
            w('\n');

            % write data
            if iElement == numel(elements)
                mlintMsg = ' %#ok<NASGU>';
            else
                mlintMsg = '';
            end
            w('    %% %s data\n', name);

            % figure out how many bytes are used by this
            bytesPerElement = signalSpec.bytesPerElement;
            if signalSpec.isEnum
                w('    nBytes = uint32(numel(%s));\n', enumStrVarName);
            else
                w('    nBytes = uint32(%d * ', bytesPerElement);
                if ndims == 1
                    w('numel(bus.%s)', e.Name);
                else
                    for d = 1:ndims
                        w('size(bus.%s, %d)', e.Name, d);
                        if d < ndims
                            w(' * ');
                        end
                    end
                end
                w(');\n');
            end

            % and store the value
            w('    if nBytes > uint32(0)\n');
            w('        if(offset+uint32(nBytes-1) > numel(out)), return, end\n');
            
            if signalSpec.isEnum
                w('        out(offset:(offset+uint32(nBytes-1))) = uint8(%s(:));\n', enumStrVarName);
            else
                % the double transpose shenanigans are a workaround for a
                % bug involving typecast, variable-length row vectors, and
                % code generation size inference
                simulinkClass = signalSpec.classSimulink;
                if strcmp(simulinkClass, 'uint8')
                    w('        out(offset:(offset+uint32(nBytes-1))) = uint8(bus.%s(:));\n', e.Name);
                else
                    w('        out(offset:(offset+uint32(nBytes-1))) = typecast(%s(bus.%s(:))'', ''uint8'')'';\n', simulinkClass, e.Name);
                end
            end
            w('    end\n');
            w('    offset = offset + nBytes;%s\n', mlintMsg);
            
        else
            % handle nested bus case, by appending field name to prefix
            innerBusName = BusSerialize.parseBusDataTypeStr(e.DataType);
            % defer to this bus's getSerializedBusLength fn
            lenFnName = BusSerialize.getGeneratedCodeFunctionName(sprintf('getSerializedBusLength_%s', innerBusName));
            
            w(['    ', repmat('%%', 1, 70), '\n']);
            w('    %% Serialize nested %s bus field %s\n', innerBusName, e.Name);
            w(['    ', repmat('%%', 1, 70), '\n\n']);
            
            % serialize each element of bus array separately
            for iSubElement = 1:numElements
                if iElement == numel(elements) && iSubElement == numElements
                    mlintMsg = ' %#ok<NASGU>';
                else
                    mlintMsg = '';
                end
                
                serializeFnName = BusSerialize.getGeneratedCodeFunctionName(sprintf('serializeBus_%s', innerBusName));
                
                w('    %% %s nested bus element(%d)\n', e.Name, iSubElement);
%                 if includeDataLoggerHeader
                    % include bus field name in namePrefix
                    if numElements > 1
                        % include index in namePrefix as well
                        w('    subNamePrefix = uint8([namePrefixBytes, uint8(''%s''), uint8(''%d''), uint8(''_'')]);\n', e.Name, iSubElement);
                    else
                        w('    subNamePrefix = uint8([namePrefixBytes, uint8(''%s''), uint8(''_'')]);\n', e.Name);
                    end
                    w('    nestedBytes = uint32(%s(bus.%s(%d), subNamePrefix));\n', lenFnName, e.Name, iSubElement);
                    w('    out(offset:(offset+nestedBytes-uint32(1))) = %s(bus.%s(%d), subNamePrefix);\n', serializeFnName, e.Name, iSubElement);
%                 else
%                     % don't include bus field name in namePrefix
%                     w('    nestedBytes = uint32(%s(bus.%s(%d), namePrefix));\n', lenFnName, e.Name, iSubElement);
%                     w('    out(offset:(offset+nestedBytes-uint32(1))) = %s(bus.%s(%d), namePrefix);\n', serializeFnName, e.Name, iSubElement);
%                 end
                w('    offset = offset + nestedBytes; %s\n', mlintMsg);
            end
            
            % and make sure that this function has been written too!
            BusSerialize.writeSerializeBusCode(innerBusName);
        end
        w('\n');
    end
    
    w('    valid = uint8(1);\n');
    
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

