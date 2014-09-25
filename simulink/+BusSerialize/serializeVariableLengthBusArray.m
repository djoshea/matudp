function out = serializeVariableLengthBusArray(busName, V)
% serialize a bus array via concatenation of the individual serialized
% buses. This function is designed to work on the host, not for code
% generation, and consequently allows variable length bus arrays,
% containing variable length bus element within, which is not supported for
% code generation directly within Simulink.
%
% The serialized bytes will be:
% 2 bytes : uint16 length N
% 4*N bytes : uint16 zero-indexed offset from start of the bytestream
%    of each bus element in the array. note that the first bus will be 
%    serialized at offset 2+2*N

N = numel(V);
sLength = typecast(uint16(N), 'uint8');

if N == 0
    out = sLength;
    return;
end

% defer to the generated code for serializing the bus elements
fnName = sprintf('serializeBus_%s', busName);
serializeBusFn = BusSerialize.getGeneratedCodeFunctionName(fnName);
hFn = eval(['@' serializeBusFn]);

serializedElements = arrayfun(hFn, V, 'UniformOutput', false);
serializedElements = cellfun(@BusSerialize.makecol, serializedElements, 'UniformOutput', false);
sElements = cat(1, serializedElements{:});

% compute length of each serialized bus
serializedLengths = cellfun(@numel, serializedElements);

% build header
size_offset = 4;
headerLength = 2 + size_offset*N;
offsets = uint32(headerLength + [0; cumsum(serializedLengths(1:end-1))] + 1);
sOffsets = typecast(offsets, 'uint8');

assert(numel(sOffsets) == size_offset*N);

% concatenate everything
import BusSerialize.makecol;
out = [makecol(sLength); makecol(sOffsets); makecol(sElements)]; 

end
