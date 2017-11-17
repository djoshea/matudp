function [td, saveTags] = loadAllSaveTagsTrialData(folder)

if nargin < 1
    folder = '';
end
[R, meta, saveTags] = MatUdp.DataLoad.loadAllSaveTagsRaw(folder);

%debug('Building TrialData...\n');
td = MatUdp.DataLoad.buildTrialData(R, meta);