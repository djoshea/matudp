function [param, simulinkParam] = getTunableParameterReferenceFromName(paramName)

try
    param = evalin('base', paramName);
    assert(isa(param, 'BusSerialize.TunableParameter'));
catch
    warning('Could not find BusSerialize.TunableParameter %s in base workspace', paramName);
    param = [];
    simulinkParam = [];
    return;
end

try
    simulinkParam = evalin('base', param.nameSimulinkParameter);
	assert(isa(simulinkParam, 'Simulink.Parameter'));
catch
    warning('Could not find Simulink.Parameter %s in base workspace', param.nameSimulinkParameter);
    param = [];
    simulinkParam = [];
end
    


