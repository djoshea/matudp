function updateCodeForBuses(busNames)
% loop through buses and update all code associated with them

if ischar(busNames)
    busNames = {busNames};
end

for iBus = 1:numel(busNames)
    BusSerialize.writeSerializeBusCode(busNames{iBus}, 'includeDataLoggerHeader', false); 
    BusSerialize.writeSerializeBusCode(busNames{iBus}, 'includeDataLoggerHeader', true);
    BusSerialize.writeDeserializeBusCode(busNames{iBus}, 'forMatlab', false);
    BusSerialize.writeDeserializeBusCode(busNames{iBus}, 'forMatlab', true);
    BusSerialize.writeInitializeBusCode(busNames{iBus});
end