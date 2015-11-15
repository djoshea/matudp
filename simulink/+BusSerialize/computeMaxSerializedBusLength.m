function [maxLen, isVariable, extraBytesPerNamePrefixCharacter] = computeMaxSerializedBusLength(busName, namePrefixKnown)
% name prefixes are tricky. if we know that there will be a prefix for
% nested buses, we need to include it in maxLen, but there will also be an
% unknown component that is passed into the serializeBus function, which we
% factor in by multiplying this prefix length by extraBytesPerNamePrefixCharacter
if nargin < 2
    namePrefixKnown = '';
end

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

extraBytesPerNamePrefixCharacter = numel(elements);

for i = 1:numel(elements)
    e = elements(i);
    signalSpec = busSpec.signals(i);
    
    if signalSpec.isBus
        % handle nested bus case
        innerBusName = BusSerialize.parseBusDataTypeStr(e.DataType);
        subNamePrefix = [namePrefixKnown, e.Name, '_'];
        [maxLenInnerBus, ~, extraBytesPerInner] = BusSerialize.computeMaxSerializedBusLength(innerBusName, subNamePrefix);
        extraBytesPerNamePrefixCharacter = extraBytesPerNamePrefixCharacter + extraBytesPerInner;
        maxLen = maxLen + maxLenInnerBus * prod(e.Dimensions);
    else
        % bit flags, signal type, name, units, data type id, nDims
        headerLen = 1 + 1 + 2 + numel(namePrefixKnown) + numel(e.Name) + 2 + numel(e.DocUnits) + 1 + 1;
        
        % reserve a uint16 size per dimension
        maxLen = maxLen + headerLen + 2 * numel(e.Dimensions); 
    
        if signalSpec.isEnum
            % reserve space for the longest string
            members = fieldnames(BusSerialize.getEnumAsValueStruct(signalSpec.enumName));
            lens = cellfun(@numel, members);
            maxLen = maxLen + max(lens) * prod(e.Dimensions);
        else
            % reserve space for the largest size 
            bytesPerElement = numel(typecast(cast(1, e.DataType), 'uint8'));
            maxLen = maxLen + bytesPerElement * prod(e.Dimensions); 
        end
    end
end
