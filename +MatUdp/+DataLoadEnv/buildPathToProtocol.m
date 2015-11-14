function folder = buildPathToProtocol(varargin)
    p = inputParser();
    p.addParameter('protocol', getenv('MATUDP_PROTOCOL'), @ischar);
    p.KeepUnmatched = true;
    p.parse(varargin{:});

    assert(~isempty(p.Results.protocol), 'Either protocol must be specified or MATUDP_PROTOCOL must be set');
    
    dateRoot = MatUdp.DataLoadEnv.buildPathToDate(p.Unmatched);
    folder = fullfile(dateRoot, p.Results.protocol);
end

