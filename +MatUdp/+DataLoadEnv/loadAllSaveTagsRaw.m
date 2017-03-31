function [R, meta, saveTags] = loadAllSaveTagsRaw(varargin)

[saveTags, folder] = MatUdp.DataLoadEnv.listSaveTags(varargin{:});
if isempty(saveTags)
    error('Could not find any save tags in directory %s', folder);
end

nST = numel(saveTags);
prog = ProgressBar(nST, 'Loading Save Tags %s', MatUdp.Utils.strjoin(saveTags, ','));
[Rc, metac] = deal(cell(nST, 1));
for iST = 1:nST
    prog.update(iST);
    [Rc{iST}, metac{iST}] = MatUdp.DataLoadEnv.loadSaveTagRaw(varargin{:}, ...
        'saveTag', saveTags(iST));
end
prog.finish();

R = TrialDataUtilities.Data.structcat(1, Rc{:});
meta = TrialDataUtilities.Data.structcat(1, metac{:});

end