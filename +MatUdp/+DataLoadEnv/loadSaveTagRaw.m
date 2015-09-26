function [R, meta] = loadSaveTagRaw(varargin)
% see MatUdp.DataLoadEnv.buildPathToSaveTag for path specification
% parameters

p = inputParser();
p.addParameter('maxTrials', Inf, @isscalar);
p.addParameter('minDuration', 50, @isscalar);
p.addParameter('saveTag', 1, @isvector);
p.addParameter('excludeGroups', {}, @iscellstr); % strip signals from specific groups
p.KeepUnmatched = true;
p.parse(varargin{:});
maxTrials = p.Results.maxTrials;

saveTag = p.Results.saveTag;
nST = numel(saveTag);
[trialsC, metaByTrialC] = deal(cell(nST, 1));
for iST = 1:nST
    folderSaveTag = MatUdp.DataLoadEnv.buildPathToSaveTag('saveTag', saveTag(iST), p.Unmatched);
    [trialsC{iST}, metaByTrialC{iST}] = MatUdp.DataLoadEnv.loadTrialsInDirectoryRaw(folderSaveTag, ...
        'maxTrials', maxTrials, 'excludeGroups', p.Results.excludeGroups);
end

%debug('Concatenating trial data...\n');
R = structcat(cat(1, trialsC{:}));
meta = structcat(cat(1, metaByTrialC{:}));

if isempty(R)
    return;
end

% filter min duration
mask = [R.duration] > p.Results.minDuration;

%debug('Filtering %d trials with duration < %d\n', nnz(~mask), p.Results.minDuration);
R = R(mask);
meta = meta(mask);

