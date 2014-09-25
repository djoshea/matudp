function maskDeserializeVariableLengthBusArrayBlockUpdate(block)

if isBlockInLibrary(block)
    return;
end

% disable library links so we can make modifications
setBlockLinkDisabled(block);

busType = getBlockParamEval(block, 'busType');
inputVariable = getBlockParamCheckbox(block, 'inputVariable');

try
    busName = BusSerialize.parseBusDataTypeStr(busType);

    if isempty(busName)
        return;
    end
    
    % get function name
    deserializeFnName = BusSerialize.getGeneratedCodeFunctionName(sprintf('deserializeBus_%s', busName));
    initFnName = BusSerialize.getGeneratedCodeFunctionName(sprintf('initializeBus_%s', busName));
    
    % determine max length of bus output
    %[maxBufferLen, isVariable] = BusSerialize.computeMaxSerializedBusLength(busName);
    
    % update the signature and contents of the code block
    % function [bus, valid] = deserialize(bytes, index)
    outputTypes = {busType, 'uint8'};
    outputSizes = {1, 1};
    outputSizesVariable = [false, false];
    inputTypes = {'Inherit: Same as Simulink', 'uint16', 'uint8'};
    inputSizes = {-1, 1, 1};
    inputSizesVariable = [inputVariable, false, false];
    
    % load code template from file
    packageDir = BusSerialize.getPathToBusSerializePackageDir();
    templateFile = fullfile(packageDir, 'templateCode_deserializeBusArrayElement.txt');
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
    
catch exc
    fprintf('BusSerialize: Error encountered updating deserialize variable length bus array block %s\n', block);
    disp(exc.getReport());
end,
