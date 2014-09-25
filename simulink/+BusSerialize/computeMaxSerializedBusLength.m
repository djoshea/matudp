function [maxLen, isVariable] = computeMaxSerializedBusLength(busName)

[busObject, busSpec] = BusSerialize.getBusFromBusName(busName);

if isempty(busObject)
    warning('Bus %s does not exist', busName);
    maxLen = 0;
    isVariable = false;
    return;
end

elements = busObject.Elements;

% determine if anything inside the bus is variable length
isVariable = false;
for i = 1:numel(elements)
    if strcmp(elements(i).DimensionsMode, 'Variable') || busSpec.signals(i).isEnum
        isVariable = true;
    end
end

elements = busObject.Elements;

% compute the maximal length of the buffer
maxLen = 0;

for i = 1:numel(elements)
    e = elements(i);
    signalSpec = busSpec.signals(i);
    
    if signalSpec.isBus
        % handle nested bus case
        innerBusName = BusSerialize.parseBusDataTypeStr(e.DataType);
        maxLenInnerBus = BusSerialize.computeMaxSerializedBusLength(innerBusName);
        maxLen = maxLen + maxLenInnerBus * prod(e.Dimensions);
    else
        % bit flags, signal type, name, units, data type id, nDims
        headerLen = 1 + 1 + 2 + numel(e.Name) + 2 + numel(e.DocUnits) + 1 + 1;
        
        % reserve a uint16 size per dimension
        maxLen = maxLen + headerLen + 2 * numel(e.Dimensions); 
    
        if signalSpec.isEnum
            % reserve space for the longest string
            members = fieldnames(BusSerialize.getEnumAsValueStruct(signalSpec.enumName));
            lens = cellfun(@numel, members);
            maxLen = maxLen + max(lens);
        else
            % reserve space for the largest size 
            bytesPerElement = numel(typecast(cast(1, e.DataType), 'uint8'));
            maxLen = maxLen + bytesPerElement * prod(e.Dimensions); 
        end
    end
end
