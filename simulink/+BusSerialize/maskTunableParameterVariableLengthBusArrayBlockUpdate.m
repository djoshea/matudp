function maskTunableParameterVariableLengthBusArrayBlockUpdate(block)

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
    
    assert(param.isVariableLengthBusArray, 'Parameter %s was not created using TunableParameter.createVariableLengthBusArray');
    
    % update constant block
    constBlock = [block '/Parameter Value'];
    setBlockParam(constBlock, 'Value', param.nameSimulinkParameter);
    
    % update the signature and contents of the code block
    % [value, update] = deserializeParameter(valAsDouble)
    outputTypes = {'uint8', 'uint8'};
    outputSizes = {param.numelAsBytes - param.headerLength, 1};
    outputSizesVariable = [false, false];
    inputTypes = {'double'};
    inputSizes = {-1};
    inputSizesVariable = [false];
    
    % load code template from file
    packageDir = BusSerialize.getPathToBusSerializePackageDir();
    templateFile = fullfile(packageDir, 'templateCode_tunableParameter.txt');
    template = fileread(templateFile);
    
    % replace {{ tokens }} with bus specific values
    dict.class = 'uint8';
    dict.sizeStr = mat2str([param.numelAsBytes - param.headerLength, 1]);
    dict.startByte = param.startByteDeserialize;
    dict.endByte = param.endByteDeserialize;
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
