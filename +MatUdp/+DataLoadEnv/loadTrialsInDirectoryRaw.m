function [trials, meta] = loadTrialsInDirectoryRaw(folder, varargin)
% returns all trials and meta files as cell arrays
    p = inputParser();
    p.addParameter('maxTrials', Inf, @isscalar); % stop after max trials
    p.addParameter('excludeGroups', {}, @iscellstr); % strip signals from specific groups off
    p.addParameter('trialIdFilter', [], @(x) isvector(x) || isempty(x)); % if specified, only load trial ids found in list
    p.parse(varargin{:});
    maxTrials = p.Results.maxTrials;
    trialIdFilter = p.Results.trialIdFilter;
    
    if ~exist(folder, 'dir')
        error('Folder %s does not exist', folder);
    end
    [names, info] = MatUdp.DataLoadEnv.listTrialFilesInSaveTagFolder(folder);
    if isempty(names)
        error('No mat files found in %s', folder);
    end
    
    if ~isempty(trialIdFilter)
        % filter by those found in list
        trialIdsFound = [info.trialId];
        mask = ismember(trialIdsFound, trialIdFilter);
        names = names(mask);
%         info  = info(mask);
    end
        
    nFiles = numel(names);
    if nargin > 1 && nFiles > maxTrials
        nFiles = maxTrials;
    end
    data = cellvec(nFiles);
    meta = cellvec(nFiles);
    valid = falsevec(nFiles);
    
    prog = ProgressBar(nFiles, 'Loading .mat in %s', folder);
    for i = 1:nFiles
        prog.update(i);
        d = load(fullfile(folder, names{i}), 'trial', 'meta');
        if ~isempty(d) && isfield(d, 'trial') && isfield(d, 'meta')
            
            % strip groups
            [data{i}, meta{i}] = stripGroups(d.trial, d.meta, p.Results.excludeGroups);
            valid(i) = true;
        end
    end
    prog.finish();

    trials = data(valid);      
end

function [trial, meta] = stripGroups(trial, meta, groupsRemove)
    if isempty(groupsRemove), return; end
    signalsRemove = cell(0, 1);
    for iG = 1:numel(groupsRemove)
        group = groupsRemove{iG};
        if ~isfield(meta.groups, group), continue, end
        signalsRemove = cat(1, signalsRemove, makecol(meta.groups.(group).signalNames));
    end
    
    nS = numel(signalsRemove);
    for iS = 1:nS
        sig = signalsRemove{iS};
        % add the time fields for each signal
        if isfield(meta.signals, sig)
            if ~isempty(meta.signals.(sig).timeFieldName)
                signalsRemove{end+1} = meta.signals.(sig).timeFieldName; %#ok<AGROW>
            end
        end
    end
    
    signalsRemove = unique(signalsRemove);
    
    rmfieldSafe = @(from, flds) rmfield(from, intersect(fieldnames(from), flds));
    
    % now strip the signals
    trial = rmfieldSafe(trial, signalsRemove);
    meta.signals = rmfieldSafe(meta.signals, signalsRemove);
    meta.groups = rmfieldSafe(meta.groups, groupsRemove);
end

 