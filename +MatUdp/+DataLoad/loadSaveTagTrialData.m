function [td] = loadSaveTagTrialData(folder, saveTag, varargin)

[R, meta] = MatUdp.DataLoad.loadSaveTagRaw(folder, saveTag, varargin{:});

%debug('Building TrialData...\n');
td = MatUdp.DataLoad.buildTrialData(R, meta);

