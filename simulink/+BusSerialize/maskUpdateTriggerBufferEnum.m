function maskUpdateTriggerBufferEnum(block)

if isBlockInLibrary(block)
    return;
end

% disable library links so we can make modifications
setBlockLinkDisabled(block);

bufferType = getBlockParamEval(block, 'bufferType');

try
    enumName = BusSerialize.parseEnumDataTypeStr(bufferType);
    enumDefaultValue = char(eval([enumName '.getDefaultValue()']));

    blockAppend = [block '/Append To Buffer/bufferEachTick'];
    blockClear = [block '/clearIfNewTimestamp'];
    
    % load code template from file
    packageDir = BusSerialize.getPathToBusSerializePackageDir();
    
    dict = struct('enumName', enumName, 'enumDefaultValue', enumDefaultValue);
    templateFileBuffer = fullfile(packageDir, 'templateCode_triggerBufferEnum.txt');
    templateFileClear = fullfile(packageDir, 'templateCode_triggerBufferClearEnum.txt');

    templateBuffer = fileread(templateFileBuffer);
    templateClear = fileread(templateFileClear);
    
    % replace {{ tokens }} with bus specific values
    code = BusSerialize.replaceTokensInTemplate(templateBuffer, dict);
    updateMatlabFunctionBlockContents(blockAppend, 'code', code);
    
    code = BusSerialize.replaceTokensInTemplate(templateClear, dict);
    updateMatlabFunctionBlockContents(blockClear, 'code', code);
        
catch exc
    fprintf('BusSerialize: Error encountered updating triggeredBuffer block %s\n', block);
    disp(exc.getReport());
end

end