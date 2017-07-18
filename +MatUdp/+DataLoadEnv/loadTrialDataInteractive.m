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

[R, meta] = MatUdp.DataLoadEnv.loadSaveTagRaw(p.Unmatched);

%debug('Building TrialData...\n');
if ~exist('tdi', 'var')
    tdi = MatUdpTrialDataInterfaceV8(R, meta);
end

tdi.includeSpikeData = p.Results.includeSpikeData;
tdi.includeWaveforms = p.Results.includeWaveforms;
tdi.includeContinuousNeuralData = p.Results.includeContinuousNeuralData;

td = TrialData(tdi);

td.datasetName = sprintf('%s %s %s saveTag %s', info.subject, info.dateStr, ...
  info.protocol, TrialDataUtilities.String.strjoin(info.saveTag,','));
