function count = countTrialsInSaveTag(varargin)
% see MatUdp.DataLoadEnv.buildPathToSaveTag for path specification
% parameters

p = inputParser();
p.addParameter('saveTag', [], @(x) isvector(x) || isempty(x));
p.KeepUnmatched = true;
p.parse(varargin{:});

saveTag = p.Results.saveTag;

if isempty(saveTag)
    saveTag = MatUdp.DataLoadEnv.listSaveTags(p.Unmatched);
end

nST = numel(saveTag);
count = nanvec(nST);
for iST = 1:nST
    folderSaveTag = MatUdp.DataLoadEnv.buildPathToSaveTag('saveTag',  saveTag(iST), p.Unmatched);

    if ~exist(folderSaveTag, 'dir')
        error('Folder %s does not exist', folder);
    end
    files = MatUdp.DataLoadEnv.listTrialFilesInSaveTagFolder(folderSaveTag);
    
    count(iST) = numel(files);
end

