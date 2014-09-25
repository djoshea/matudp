function busName = parseBusDataTypeStr(busStr)
% given a string like 'Bus: BusType', returns 'BusType'
% if busStr is not a valid bus identifier string, returns ''

busName = regexp(busStr, 'Bus: (?<busName>[^ ]+)', 'tokens', 'once');
if isempty(busName)
    busName = '';
else
    busName = busName{1};
end

end
