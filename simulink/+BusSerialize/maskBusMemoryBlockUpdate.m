function maskBusMemoryBlockUpdate(block)

if isBlockInLibrary(block)
    return;
end

setBlockLinkDisabled(block);

try
    % update all bus types within
    busType = getBlockParamEval(block, 'busType');
    set_param([block '/In'],  'OutDataTypeStr', busType);
    set_param([block '/Out'], 'OutDataTypeStr', busType);
    set_param([block '/Serialize'],  'busType', busType);
    set_param([block '/Deserialize'], 'busType', busType);

    % set buffer size in variable to fixed
    busName = BusSerialize.parseBusDataTypeStr(busType);
    bufferSize = BusSerialize.computeMaxSerializedBusLength(busName);
    set_param([block '/ToFixed'], 'bufferSize', num2str(bufferSize));

catch exc
    fprintf('BusSerialize: Error encountered updating bus memory block %s\n', block);
    disp(exc.getReport());
end

end

