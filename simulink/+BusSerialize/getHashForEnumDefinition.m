function hash = getHashForEnumDefinition(enumName)
% hash the enum definition (including members and their values) to a uint32

    vals = BusSerialize.getEnumAsValueStruct(enumName);
    opt.Method = 'Sha-1';
    opt.Format = 'uint8';
    fullHash = BusSerialize.DataHash(vals, opt);
    hash = typecast(fullHash(1:4), 'uint32');

end
