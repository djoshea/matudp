function maskSerializedBusTunableParameterBlockUpdate(block)

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
    
    if ~param.isBus
        error('This parameter was not created with BusSerialize.TunableParameter.createBus');
    end
    busName = param.busName;
    busType = ['Bus: ' busName];
    
    % get function name
    deserializeFnName = BusSerialize.getGeneratedCodeFunctionName(sprintf('deserializeBus_%s', busName));
    initFnName = BusSerialize.getGeneratedCodeFunctionName(sprintf('initializeBus_%s', busName));
    
    
    % update constant block
    constBlock = [block '/Parameter Value'];
    setBlockParam(constBlock, 'Value', param.nameSimulinkParameter);
    
    % update deserialize block
    deserializeBlock = [block '/Deserialize Bus Parameter'];
   
    [~, busSpec] = BusSerialize.getBusFromBusName(busName);
    
    % load code template from file
    packageDir = BusSerialize.getPathToBusSerializePackageDir();
    templateFile = fullfile(packageDir, 'templateCode_deserializeBusParameterBlock.txt');
    template = fileread(templateFile);
    
    flags.resetImmediately = false;
    dict.resetImmediatelyCode = '';
    for iS = 1:busSpec.nSignals
        spec = busSpec.signals(iS);
        if spec.resetImmediately
            flags.resetImmediately = true;
            dict.resetImmediatelyCode = [dict.resetImmediatelyCode, ...
                sprintf('        bus.%s = %s;\n', busSpec.signalNames{iS}, mat2str(spec.value, 'class'))];
        end
    end
    
    % replace {{ tokens }} with bus specific values
    dict.deserializeBusFn = deserializeFnName;
    dict.initBusFn = initFnName;
    code = BusSerialize.replaceTokensInTemplate(template, dict);
    
    
    % update the signature and contents of the code block
    % [bus, update, receivedInvalid] = deserializeBusParameter(valAsDouble, allowUpdate)
    outputTypes = {busType, 'uint8', 'uint8'};
    outputSizes = {1, 1, 1};
    outputSizesVariable = [false, false, false];
    inputTypes = {'double', 'uint8'};
    inputSizes = {-1, 1};
    inputSizesVariable = [false, false];
    
    updateMatlabFunctionBlockContents(deserializeBlock, 'code', code, ...
        'inputTypes', inputTypes, ...
        'inputSizes', inputSizes, ...
        'inputSizesVariable', inputSizesVariable, ...
        'outputTypes', outputTypes, ...
        'outputSizes', outputSizes, ...
        'outputSizesVariable', outputSizesVariable);
    
catch exc
    fprintf('BusSerialize: Error encountered updating serialized bus tunable parameter block %s\n', block);
    disp(exc.getReport());
end

end
