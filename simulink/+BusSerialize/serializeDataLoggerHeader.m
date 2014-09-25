function out = serializeDataLoggerHeader(groupType, groupName, configHash, nSignals, timestamp)
%#codegen

    v = uint8(4); % version
    t = uint8(groupType); % type
    n = uint8(groupName); % name
    h = uint32(configHash); % configuration hash
    s = uint16(nSignals); % number of signals in flattened bus
    w = uint32(timestamp); % timestamp in ms

    out = uint8([v, t, typecast(h, 'uint8'), typecast(s, 'uint8'), ...
        typecast(uint16(numel(n)), 'uint8'), n, ...
        typecast(w, 'uint8')]);
end
