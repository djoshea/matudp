function folder = buildPath(varargin)
    p = inputParser();
    p.addRequired('subject', @ischar);
    p.addRequired('protocol', @ischar);
    p.addParameter('dateStr', datestr(now, 'yyyy-mm-dd'), @ischar);
    p.addParameter('dataRoot', '', @(x) ischar(x));
    p.parse(varargin{:});

    if ~isempty(p.Results.dataRoot)
        dataRoot = p.Results.dataRoot;
    else
        dataRoot = getenvCheckPath('MATUDP_DATAROOT');
    end

    folder = fullfile(dataRoot, p.Results.subject, p.Results.dateStr, p.Results.protocol);
end

function val = getenvCheckPath(key)
    val = getenvString(key);
    assert(exist(val, 'dir') > 0, 'Directory %s not found, from environment variable %s', val, key);
end

function val = getenvString(key)
    val = getenv(key);
    if isempty(val)
        error('Environment variable %s not found. Use setenv to create it.', key); 
    end
end