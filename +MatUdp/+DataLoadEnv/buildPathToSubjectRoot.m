function folder = buildPathToSubjectRoot(varargin)
    p = inputParser();
    % only one of the following options or environment variables should be set
    p.addParameter('dataRoot', getenv('MATUDP_DATAROOT'), @ischar);  % root path under which lives dataStore/subject/dateStr
    p.addParameter('dataStoreRoot', getenv('MATUDP_DATASTOREROOT'), @ischar); % root path under which lives subject/dateStr
    p.addParameter('subjectRoot',  getenv('MATUDP_SUBJECTROOT'), @ischar); % root path under which lives dateStr
    
    p.addParameter('dataStore', getenv('MATUDP_DATASTORE'), @ischar);
    p.addParameter('subject', getenv('MATUDP_SUBJECT'), @ischar);
    p.parse(varargin{:});

    msg = 'Only one of dataRoot / MATUDP_DATAROOT, dataStoreRoot / MATUDP_DATASTOREROOT, subjectRoot / MATUDP_SUBJECTROOT should be specified';
    if ~isempty(p.Results.subjectRoot)
        assert(isempty(p.Results.dataStoreRoot) && isempty(p.Results.dataRoot), msg);
        folder = fullfile(p.Results.subjectRoot);
        
    elseif ~isempty(p.Results.dataStoreRoot)
        assert(~isempty(p.Results.subject), 'Either subject must be specified or MATUDP_SUBJECT must be set');
        assert(isempty(p.Results.dataRoot) && isempty(p.Results.subjectRoot), msg);
        folder = fullfile(p.Results.dataStoreRoot, p.Results.subject);
        
    elseif ~isempty(p.Results.dataRoot)
        assert(~isempty(p.Results.subject), 'Either subject must be specified or MATUDP_SUBJECT must be set');
        assert(isempty(p.Results.dataStoreRoot) && isempty(p.Results.subjectRoot), msg);
    	folder  = fullfile(p.Results.dataRoot, p.Results.dataStore, p.Results.subject);
    end
end

