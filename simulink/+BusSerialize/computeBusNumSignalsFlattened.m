function nSignals = computeBusNumSignalsFlattened(busName)
% compute the total number of signals within a bus, when all signals within
% have been flattened

[~, busSpec] = BusSerialize.getBusFromBusName(busName);

% determine if anything inside the bus is variable length
nSignals = 0;
for i = 1:busSpec.nSignals
    spec = busSpec.signals(i);
    if spec.isBus
        nSignals = nSignals + spec.maxSize * BusSerialize.computeBusNumSignalsFlattened(spec.busName);
    else
        nSignals = nSignals + 1;
    end
end
