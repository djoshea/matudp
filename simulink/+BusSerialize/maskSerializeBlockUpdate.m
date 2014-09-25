function maskSerializeBlockUpdate(block)

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
    
    % get function name
    fnName = sprintf('serializeBus_%s', busName);
    fullFnName = BusSerialize.getGeneratedCodeFunctionName(fnName);
    
    % determine max length of bus output
    [maxBufferLen, ~] = BusSerialize.computeMaxSerializedBusLength(busName);
    
    % update the signature and contents of the code block
    inputTypes = {busType};
    inputSizes = {1};
    inputSizesVariable = false;
    outputTypes = {'uint8'};
    outputSizes = {maxBufferLen};
    outputSizesVariable = true;
    
    % load code template from file
    packageDir = BusSerialize.getPathToBusSerializePackageDir();
    templateFile = fullfile(packageDir, 'templateCode_serializeBlock.txt');
    template = fileread(templateFile);
    
    % replace {{ tokens }} with bus specific values
    dict.maxBufferLen = num2str(maxBufferLen);
    dict.serializeFn = fullFnName;
    code = BusSerialize.replaceTokensInTemplate(template, dict);
    
    updateMatlabFunctionBlockContents(block, 'code', code, ...
        'inputTypes', inputTypes, 'outputTypes', outputTypes, ...
        'inputSizes', inputSizes, 'outputSizes', outputSizes, ...
        'inputSizesVariable', inputSizesVariable, ...
        'outputSizesVariable', outputSizesVariable);
    
catch exc
    fprintf('BusSerialize: Error encountered updating serialize block %s\n', block);
    disp(exc.getReport());
end