function [td, saveTags] = loadAllSaveTagsTrialData(folder)

if nargin < 1
    folder = '';
end
[R, meta, saveTags] = MatUdp.DataLoad.loadAllSaveTagsRaw(folder);

%debug('Building TrialData...\n');
if ~exist('tdi', 'var')
    tdi = MatUdpTrialDataInterfaceV6(R, meta);
end

td = TrialData(tdi);
