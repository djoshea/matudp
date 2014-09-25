function maskTunableParameterBlockUpdate(block)

if isBlockInLibrary(block)
    return;
end


% disable library links so we can make modifications
setBlockLinkDisabled(block);

paramName = getBlockParamEval(block, 'paramName');

try
    param = BusSerialize.getTunableParameterReferenceFromName(paramName);

    if isempty(param)
        return;
    end
    
    % update constant block
    constBlock = [block '/Parameter Value'];
    setBlockParam(constBlock, 'Value', param.nameSimulinkParameter);
    
    % update the signature and contents of the code block
    % [value, update] = deserializeParameter(valAsDouble)
    outputTypes = {param.valueClass, 'uint8'};
    outputSizes = {param.valueSize, 1};
    outputSizesVariable = [false, false];
    inputTypes = {'double'};
    inputSizes = {-1};
    inputSizesVariable = [false];
    
    % load code template from file
    packageDir = BusSerialize.getPathToBusSerializePackageDir();
    if param.resetImmediately
        templateFile = fullfile(packageDir, 'templateCode_tunableParameterResetImmediately.txt');
    else
        templateFile = fullfile(packageDir, 'templateCode_tunableParameter.txt');
    end
    template = fileread(templateFile);
    
    % replace {{ tokens }} with bus specific values
    dict.class = param.valueClass;
    dict.sizeStr = mat2str(param.valueSize);
    dict.startByte = param.startByteDeserialize;
    dict.endByte = param.endByteDeserialize;
    dict.resetValue = param.resetValue;
    code = BusSerialize.replaceTokensInTemplate(template, dict);
    
    matlabBlock = [block '/Deserialize Parameter'];
    updateMatlabFunctionBlockContents(matlabBlock, 'code', code, ...
        'inputTypes', inputTypes, ...
        'inputSizes', inputSizes, ...
        'inputSizesVariable', inputSizesVariable, ...
        'outputTypes', outputTypes, ...
        'outputSizes', outputSizes, ...
        'outputSizesVariable', outputSizesVariable);
    
catch exc
    fprintf('BusSerialize: Error encountered updating tunable parameter block %s\n', block);
    disp(exc.getReport());
end,
