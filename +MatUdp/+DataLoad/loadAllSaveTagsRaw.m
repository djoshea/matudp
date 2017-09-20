function [R, meta, saveTags] = loadAllSaveTagsRaw(folder)

if nargin < 1 || strcmp(folder, '')
    folder = uigetdir('', 'Choose protocol folder');
end

% enumerate saveTag folders in that directory
list = dir(folder);
mask = falsevec(numel(list));
saveTags = nanvec(numel(list));

for i = 1:numel(list)
    if ~list(i).isdir, continue, end
    r = regexp(list(i).name, 'saveTag(\d+)', 'tokens');
    if ~isempty(r)
        saveTags(i) = str2double(r{1});
        mask(i) = true;
    end
end

saveTags = saveTags(mask);
list = list(mask);

if isempty(saveTags)
    error('Could not find any save tags in directory %s', folder);
end

nST = numel(saveTags);
prog = ProgressBar(nST, 'Loading %d save tags', nST);
[Rc, metac] = deal(cell(nST));

for iST = 1:nST
    [Rc{iST}, metac{iST}] = MatUdp.DataLoad.loadSaveTagRaw(folder, saveTags(iST));
end

R = structcat(cat(1, Rc{:}));
meta = structcat(cat(1, metac{:}));

end