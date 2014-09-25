files = dir('*.mat');
trialCell = cell(length(files), 1);
for iF = 1:length(files)
    data = load(files(iF).name, 'trial');
    trialCell{iF} = data.trial;
end

R = structcat(trialCell{:});

