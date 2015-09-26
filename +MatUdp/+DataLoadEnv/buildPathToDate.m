function folder = buildPathToDate(varargin)
    p = inputParser();
    p.addParameter('dateStr', datestr(now, 'yyyy-mm-dd'), @ischar);
    p.KeepUnmatched = false;
    p.parse(varargin{:});

    % get the subject folder
    subjRoot = MatUdp.DataLoadEnv.buildPathToSubjectRoot(p.Unmatched);
    
    folder = fullfile(subjRoot, p.Results.dateStr);
end

