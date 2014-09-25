function outSize = computeDataLoggerHeaderLength(groupName)
%#codegen
% computes the length of the data logger group header that precedes a 
% serialized bus. This will be a fixed length that depends on the name and
% meta information.

    % bytes used:
    % version: 2 
    % type: 1 
    % name: 1 + numel(groupName)
    % hash: 4
    % nSignals: 2
    % timestamp: 4

    outSize = uint16(numel(BusSerialize.serializeDataLoggerHeader(uint8(0), groupName, uint32(0), uint16(0), uint32(0))));

end
