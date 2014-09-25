function maskTunableParameterPulseSwitchBlockUpdate(block)

if isBlockInLibrary(block)
    return;
end

% disable library links so we can make modifications
setBlockLinkDisabled(block);

paramName = getBlockParamEval(block, 'paramName');

try
    param = BusSerialize.getTunableParameterReferenceFromName(paramName);

    if isempty(param)
        % just create it for the user
        warning('Automatically generating %s using BusSerialize.TunableParameter.createPulseSwitch. You may need to re-update the diagram', paramName);
        BusSerialize.TunableParameter.createPulseSwitch(paramName);
    else
        if ~param.isPulseSwitch
            warning('Parameter %s was not created as a tunable parameter switch using BusSerialize.TunableParameter.createPulseSwitch', paramName);
            return;
        end
    end
    
    % defer
    BusSerialize.maskTunableParameterBlockUpdate(block);
    
catch exc
    fprintf('BusSerialize: Error encountered updating tunable parameter block %s\n', block);
    disp(exc.getReport());
end,
