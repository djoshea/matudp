function [td] = loadSaveTagTrialData(varargin)

p = inputParser();
p.addParameter('includeSpikeData', true, @islogical);
p.addParameter('includeWaveforms', true, @islogical);
p.addParameter('includeContinuousNeuralData', true, @islogical);
p.KeepUnmatched = true;
p.parse(varargin{:});

info = MatUdp.DataLoadEnv.buildSaveTagInfo(p.Unmatched);

[trials, meta] = MatUdp.DataLoadEnv.loadSaveTagRaw(p.Unmatched);

td = MatUdp.DataLoad.buildTrialData(trials, meta, p.Results);

td.datasetName = sprintf('%s %s %s saveTag %s', info.subject, info.dateStr, ...
  info.protocol, MatUdp.Utils.strjoin(info.saveTag,','));

