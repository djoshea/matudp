function [R, meta] = loadSaveTagRaw(varargin)
% see MatUdp.DataLoadEnv.buildPathToSaveTag for path specification
% parameters

p = inputParser();
p.addParameter('maxTrials', Inf, @isscalar);
p.addParameter('minDuration', 50, @isscalar);
p.addParameter('saveTag', [], @isvector);
p.addParameter('excludeGroups', {}, @iscellstr); % strip signals from specific groups
p.addParameter('trialIdFilter', [], @isvector); % if specified, only load trial ids found in list
p.KeepUnmatched = true;
p.parse(varargin{:});
maxTrials = p.Results.maxTrials;

% if not specified load all save tags
saveTag = p.Results.saveTag;
if isempty(saveTag)
    [saveTag, folder] = MatUdp.DataLoadEnv.listSaveTags(p.Unmatched);
    if isempty(saveTag)
        error('Could not find any save tags in directory %s', folder);
    end
end

nST = numel(saveTag);
[trialsC, metaByTrialC] = deal(cell(nST, 1));
for iST = 1:nST
    folderSaveTag = MatUdp.DataLoadEnv.buildPathToSaveTag('saveTag', saveTag(iST), p.Unmatched);
    [trialsC{iST}, metaByTrialC{iST}] = MatUdp.DataLoadEnv.loadTrialsInDirectoryRaw(folderSaveTag, ...
        'maxTrials', maxTrials, 'excludeGroups', p.Results.excludeGroups, 'trialIdFilter', p.Results.trialIdFilter);
end

%debug('Concatenating trial data...\n');
R = TrialDataUtilities.Data.structcat(1, cat(1, trialsC{:}));
meta = TrialDataUtilities.Data.structcat(1, cat(1, metaByTrialC{:}));

if isempty(R)
    return;
end

% filter min duration
mask = [R.duration] > p.Results.minDuration;

%debug('Filtering %d trials with duration < %d\n', nnz(~mask), p.Results.minDuration);
R = R(mask);
meta = meta(mask);
