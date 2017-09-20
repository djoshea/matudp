function [td] = loadTrialDataInteractive(varargin)

p = inputParser();
p.addParameter('includeSpikeData', true, @islogical);
p.addParameter('includeWaveforms', true, @islogical);
p.addParameter('includeContinuousNeuralData', true, @islogical);
p.KeepUnmatched = true;
p.parse(varargin{:});

folder = uigetdir(getenv('MATUDP_DATAROOT'), 'Choose date folder or save tag folder');
if folder == 0
    td = [];
    return
end

info = MatUdp.DataLoadEnv.buildSaveTagInfo(p.Unmatched);

[trials, meta] = MatUdp.DataLoadEnv.loadSaveTagRaw(p.Unmatched);

td = MatUdp.DataLoad.buildTrialData(trials, meta, p.Results);

td.datasetName = sprintf('%s %s %s saveTag %s', info.subject, info.dateStr, ...
  info.protocol, TrialDataUtilities.String.strjoin(info.saveTag,','));
