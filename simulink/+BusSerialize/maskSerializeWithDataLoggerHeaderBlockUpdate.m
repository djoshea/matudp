function maskSerializeWithDataLoggerHeaderBlockUpdate(block)

if isBlockInLibrary(block)
    return;
end

% disable library links so we can make modifications
setBlockLinkDisabled(block);

busType = getBlockParamEval(block, 'busType');
groupTypeStr = getBlockParamEval(block, 'groupType'); 
groupName = getBlockParamEval(block, 'groupName');

try
    busName = BusSerialize.parseBusDataTypeStr(busType);

    if isempty(busName)
        return;
    end
    
    % get function name
    fnName = sprintf('serializeBusWithDataLoggerHeader_%s', busName);
    fullFnName = BusSerialize.getGeneratedCodeFunctionName(fnName);
    
    % compute header length
    headerLen = BusSerialize.computeDataLoggerHeaderLength(groupName);
    
    % determine max length of bus output
    maxBufferLen = BusSerialize.computeMaxSerializedBusLength(busName);
    
    outLen = headerLen + maxBufferLen;
    
    % update the signature and contents of the code block
    inputTypes = {'uint8', busType, 'uint32'};
    inputSizes = {1, 1, 1};
    inputSizesVariable = [false, false, false];
    outputTypes = {'uint8'};
    outputSizes = {outLen};
    outputSizesVariable = true;
    
    % load code template from file
    packageDir = BusSerialize.getPathToBusSerializePackageDir();
    templateFile = fullfile(packageDir, 'templateCode_serializeWithDataLoggerHeader.txt');
    template = fileread(templateFile);
    
    % replace {{ tokens }} with bus specific values
    dict.serializeBusFn = fullFnName;
    dict.groupType = sprintf('BusSerialize.GroupTypes.%s', groupTypeStr);
    dict.groupName = groupName;
    code = BusSerialize.replaceTokensInTemplate(template, dict);
    
    updateMatlabFunctionBlockContents(block, 'code', code, ...
        'inputTypes', inputTypes, 'outputTypes', outputTypes, ...
        'inputSizes', inputSizes, 'outputSizes', outputSizes, ...
        'inputSizesVariable', inputSizesVariable, ...
        'outputSizesVariable', outputSizesVariable);
    
catch err
    fprintf('BusSerialize: Error encountered updating serialize block %s\n', block);
    disp(err.getReport);
end

end
