function [R, meta] = loadSaveTagRaw(folder, saveTag, varargin)

p = inputParser();
p.addParameter('maxTrials', Inf, @isscalar);
p.addParameter('minDuration', 50, @isscalar);
p.KeepUnmatched = true;
p.parse(varargin{:});
maxTrials = p.Results.maxTrials;

nST = numel(saveTag);
[trialsC, metaByTrialC] = deal(cell(nST, 1));
for iST = 1:nST
    folderSaveTag = fullfile(folder, sprintf('saveTag%03d', saveTag(iST)));
    [trialsC{iST}, metaByTrialC{iST}] = MatUdp.DataLoad.loadAllTrialsInDirectoryRaw(folderSaveTag, ...
        'maxTrials', maxTrials, p.Unmatched);
end

%debug('Concatenating trial data...\n');
R = structcat(cat(1, trialsC{:}));
meta = structcat(cat(1, metaByTrialC{:}));

% filter min duration
mask = [R.duration] > p.Results.minDuration;

%debug('Filtering %d trials with duration < %d\n', nnz(~mask), p.Results.minDuration);
R = R(mask);
meta = meta(mask);

