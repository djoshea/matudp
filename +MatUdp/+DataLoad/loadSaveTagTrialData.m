function [td] = loadSaveTagTrialData(folder, saveTag, varargin)

[R, meta] = MatUdp.DataLoad.loadSaveTagRaw(folder, saveTag, varargin{:});

%debug('Building TrialData...\n');
if ~exist('tdi', 'var')
    tdi = MatUdpTrialDataInterfaceV6(R, meta);
end

td = TrialData(tdi);

