function vec = ipAddressFromString(ip)
% IPADDRESSFROMSTRING Evaluate a string IP Address.

% Copyright 2009 The MathWorks, Inc.

if isvector(ip) && isnumeric(ip)
    return;
else
    tokens = regexp(ip, '(\d{1,3}).(\d{1,3}).(\d{1,3}).(\d{1,3})', 'tokens', 'once');
    if isempty(tokens)
        error('Could not parse IP address %s', ip);
    end
    
    vec = cellfun(@str2double, tokens);
end
