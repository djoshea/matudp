function [td] = loadSaveTagTrialData(varargin)

p = inputParser();
p.addParamValue('includeSpikeData', true, @islogical);
p.addParamValue('includeWaveforms', true, @islogical);
p.addParamValue('includeContinuousNeuralData', true, @islogical);
p.KeepUnmatched = true;
p.parse(varargin{:});

info = MatUdp.DataLoadEnv.buildSaveTagInfo(p.Unmatched);

[R, meta] = MatUdp.DataLoadEnv.loadSaveTagRaw(p.Unmatched);

%debug('Building TrialData...\n');
if ~exist('tdi', 'var')
    tdi = MatUdpTrialDataInterfaceV7(R, meta);
end

tdi.includeSpikeData = p.Results.includeSpikeData;
tdi.includeWaveforms = p.Results.includeWaveforms;
tdi.includeContinuousNeuralData = p.Results.includeContinuousNeuralData;

td = TrialData(tdi);

td.datasetName = sprintf('%s %s %s saveTag %s', info.subject, info.dateStr, ...
  info.protocol, MatUdp.Utils.strjoin(info.saveTag,','));
