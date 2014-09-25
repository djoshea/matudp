function maskDropVariableLengthSignalsFromBusBlockUpdate(block)

if isBlockInLibrary(block)
    return;
end

% disable library links so we can make modifications
setBlockLinkDisabled(block);

busType = getBlockParamEval(block, 'busType');
busFixedType = getBlockParamEval(block, 'busFixedType');

try
    busName = BusSerialize.parseBusDataTypeStr(busType);
    busFixedName = BusSerialize.parseBusDataTypeStr(busFixedType);

    if isempty(busName) || isempty(busFixedName)
        return;
    end
    
    % get function name
    fnName = sprintf('dropVariableLengthSignalsFromBus_%s', busName);
    convertFnName = BusSerialize.getGeneratedCodeFunctionName(fnName);
    
    % update the signature and contents of the code block
    inputTypes = {busType};
    inputSizes = {1};
    inputSizesVariable = false;
    outputTypes = {busFixedType};
    outputSizes = {1};
    outputSizesVariable = false;
    
    % load code template from file
    packageDir = BusSerialize.getPathToBusSerializePackageDir();
    templateFile = fullfile(packageDir, 'templateCode_dropVariableLengthSignalsFromBus.txt');
    template = fileread(templateFile);
    
    % replace {{ tokens }} with bus specific values
    dict.convertFn = convertFnName;
    dict.busFixedName = busFixedName;
    code = BusSerialize.replaceTokensInTemplate(template, dict);
    
    updateMatlabFunctionBlockContents(block, 'code', code, ...
        'inputTypes', inputTypes, 'outputTypes', outputTypes, ...
        'inputSizes', inputSizes, 'outputSizes', outputSizes, ...
        'inputSizesVariable', inputSizesVariable, ...
        'outputSizesVariable', outputSizesVariable);
    
catch err
    fprintf('BusSerialize: Error encountered updating drop variable length signals from bus block %s\n', block);
    disp(err.getReport);
end

end
