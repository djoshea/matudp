function [td] = loadSaveTagTrialData(varargin)

[R, meta] = MatUdp.DataLoadEnv.loadSaveTagRaw(varargin{:});

%debug('Building TrialData...\n');
if ~exist('tdi', 'var')
    tdi = MatUdpTrialDataInterfaceV7(R, meta);
end

td = TrialData(tdi);

