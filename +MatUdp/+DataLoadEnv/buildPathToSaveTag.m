function folder = buildPathToSaveTag(varargin)
    p = inputParser();
    p.addParameter('saveTag', 0, @isscalar);
    p.KeepUnmatched = true;
    p.parse(varargin{:});

    protocolRoot = MatUdp.DataLoadEnv.buildPathToProtocol(p.Unmatched);
    folder = fullfile(protocolRoot, sprintf('saveTag%03d', p.Results.saveTag));
end
