function td = loadSaveTagFromFolder(subject, dateStr, saveTag, maxTrials)

if ~exist('maxTrials', 'var')
    maxTrials = Inf;
end
if ~exist('saveTag', 'var')
    saveTag = 0;
end

if ~exist('dateStr', 'var')
    dateStr = datestr(now, 'yyyy-mm-dd');
end

dataRoot = getenvCheckPath('MATUDP_DATAROOT');

nST = numel(saveTag);
[trialsC, metaByTrialC] = cellvec(nST);
for iST = 1:nST
    folder = sprintf('%s/%s/%s/ChannelReach/saveTag%03d', dataRoot, subject, dateStr, saveTag(iST));
    [trialsC{iST}, metaByTrialC{iST}] = ChannelReach.DataLoad.loadAllInDirectory(folder, maxTrials);
end

debug('Concatenating trial data...\n');
R =  MatUdp.Utils.structcat(cat(1, trialsC{:}));
meta = MatUdp.Utils.structcat(cat(1, metaByTrialC{:}));

mask = [R.duration] > 50;

R = R(mask);
meta = meta(mask);

if isempty(R)
    error('Could not find any trials in directory %s', folder);
end

% fix temporary issue with time field prefixes
for iT = 1:numel(meta)
    if isfield(meta(iT).groups, 'loadCell_loadCell')
        meta(iT).groups.loadCell_loadCell.signalNames = setdiff(meta(iT).groups.loadCell_loadCell.signalNames, 'loadCell_timestampOffsets');
    end
end

debug('Building TrialData...\n');
if ~exist('tdi', 'var')
    tdi = MatUdpTrialDataInterfaceV6(R, meta);
end

td = TrialData(tdi);

% add missing success channel
if ~td.hasChannel('success')
    s = td.getEventOccurred('Success');
    td = td.addBooleanParam('success', s);
end
    
td.datasetName = sprintf('%s ChannelReach %s ST %d', subject, dateStr, saveTag);
