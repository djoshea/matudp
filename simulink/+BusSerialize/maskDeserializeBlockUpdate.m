function maskDeserializeBlockUpdate(block)

if isBlockInLibrary(block)
    return;
end

% disable library links so we can make modifications
setBlockLinkDisabled(block);

busType = get_param(block, 'busType');

try
    busName = BusSerialize.parseBusDataTypeStr(busType);

    if isempty(busName)
        return;
    end
    
    % get function names
    deserializeFnName = BusSerialize.getGeneratedCodeFunctionName(sprintf('deserializeBus_%s', busName));
    initFnName = BusSerialize.getGeneratedCodeFunctionName(sprintf('initializeBus_%s', busName));
    
    
    % determine max length of bus output
    %[maxBufferLen, isVariable] = BusSerialize.computeMaxSerializedBusLength(busName);
    
    % update the signature and contents of the code block
    outputTypes = {busType, 'uint8'};
    outputSizes = {1, 1};
    outputSizesVariable = [false, false];
    inputTypes = {'Inherit: Same as Simulink'};
    inputSizes = {-1};
    inputSizesVariable = true;
    
    % load code template from file
    packageDir = BusSerialize.getPathToBusSerializePackageDir();
    templateFile = fullfile(packageDir, 'templateCode_deserializeBlock.txt');
    template = fileread(templateFile);
    
    % replace {{ tokens }} with bus specific values
    dict.deserializeBusFn = deserializeFnName;
    dict.initBusFn = initFnName;
    code = BusSerialize.replaceTokensInTemplate(template, dict);
    
    updateMatlabFunctionBlockContents(block, 'code', code, ...
        'inputTypes', inputTypes, ...
        'inputSizes', inputSizes, ...
        'inputSizesVariable', inputSizesVariable, ...
        'outputTypes', outputTypes, ...
        'outputSizes', outputSizes, ...
        'outputSizesVariable', outputSizesVariable);
    
catch
    fprintf('BusSerialize: Error encountered updating deserialize block %s\n', block);
end
