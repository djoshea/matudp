function t = tabulateTrialCounts(varargin)
% see MatUdp.DataLoadEnv.buildPathToSaveTag for path specification
% parameters

p = inputParser();
p.addParameter('dateStr', {}, @(x) ischar(x) || iscellstr(x));
p.addParameter('protocol', '', @(x) ischar(x) || iscellstr(x));
p.KeepUnmatched = true;
p.parse(varargin{:});

if isempty(p.Results.dateStr)
  dateStr = MatUdp.DataLoadEnv.listDates(p.Unmatched);
elseif ischar(p.Results.dateStr)
  dateStr = {p.Results.dateStr};
else
  dateStr = p.Results.dateStr;
end

if ~isempty(p.Results.protocol)
  protocol = p.Results.protocol;
  if ischar(protocol)
    protocol = {protocol};
  end
else
  protocol = {};
end

Date = cell(0, 1);
Protocol = cell(0, 1);
SaveTag = nan(0, 1);
NumTrials = nan(0, 1);
c = 1;

prog = ProgressBar(numel(dateStr), 'Processing %d dates', numel(dateStr));
for iD = 1:numel(dateStr)
  prog.update(iD);

  % loop over protocols included in list if specified
  protocolThis = MatUdp.DataLoadEnv.listProtocols('dateStr', dateStr{iD}, p.Unmatched);
  if ~isempty(protocol)
    protocolThis = intersect(protocolThis, protocol);
  end

  for iP = 1:numel(protocolThis)
    % loop over save tags
    saveTags = MatUdp.DataLoadEnv.listSaveTags('dateStr', dateStr{iD}, ...
      'protocol', protocolThis{iP}, p.Unmatched);
    for iST = 1:numel(saveTags)
      nTrials = MatUdp.DataLoadEnv.countTrialsInSaveTag('dateStr', dateStr{iD}, ...
        'protocol', protocolThis{iP}, 'saveTag', saveTags(iST), p.Unmatched);
      Date{c, 1} = dateStr{iD};
      Protocol{c, 1} = protocolThis{iP};
      SaveTag(c, 1) = saveTags(iST);
      NumTrials(c, 1) = nTrials;
      c = c+1;
    end
  end
end
prog.finish();

Date = string(Date);
Protocol = string(Protocol);
t = table(Date, Protocol, SaveTag, NumTrials);
