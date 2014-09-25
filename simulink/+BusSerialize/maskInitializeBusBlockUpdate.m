function maskInitializeBusBlockUpdate(block)

if isBlockInLibrary(block)
    return;
end

% disable library links so we can make modifications
setBlockLinkDisabled(block);

busType = getBlockParamEval(block, 'busType');

try
    busName = BusSerialize.parseBusDataTypeStr(busType);

    if isempty(busName)
        return;
    end
    
    % get function name
    fnName = sprintf('initializeBus_%s', busName);
    initFnName = BusSerialize.getGeneratedCodeFunctionName(fnName);
    
    % update the signature and contents of the code block
    inputTypes = {};
    inputSizes = {};
    inputSizesVariable = logical([]);
    outputTypes = {busType};
    outputSizes = {1};
    outputSizesVariable = false;
    
    % load code template from file
    packageDir = BusSerialize.getPathToBusSerializePackageDir();
    templateFile = fullfile(packageDir, 'templateCode_initializeBlock.txt');
    template = fileread(templateFile);
    
    % replace {{ tokens }} with bus specific values
    dict.initFn = initFnName;
    dict.busName = busName;
    code = BusSerialize.replaceTokensInTemplate(template, dict);
    
    updateMatlabFunctionBlockContents(block, 'code', code, ...
        'inputTypes', inputTypes, 'outputTypes', outputTypes, ...
        'inputSizes', inputSizes, 'outputSizes', outputSizes, ...
        'inputSizesVariable', inputSizesVariable, ...
        'outputSizesVariable', outputSizesVariable);
    
catch err
    fprintf('BusSerialize: Error encountered updating initialize bus block %s\n', block);
    disp(err.getReport);
end

end
