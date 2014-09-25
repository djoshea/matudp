function [busObject, busSpec] = getBusFromBusName(busName)
% busObject will be the Simulink.Bus class. busSpec will be the
% BusSerialize.BusSpec object used to build that bus which contains
% additional metadata

try
    busObject = evalin('base', busName);
    assert(isa(busObject, 'Simulink.Bus'));
catch
    %warning('Could not find bus %s in base workspace', busName);
    busObject = [];
end

try
    busSpecVar = sprintf('BusSpec_%s', busName);
    busSpec = evalin('base', busSpecVar);
    assert(isa(busSpec, 'BusSerialize.BusSpec'));
catch
    %warning('Could not find bus %s in base workspace', busName);
    busSpec = [];
end




