function info = buildSaveTagInfo(varargin)
  p = inputParser();
  p.addParameter('dateStr', datestr(now, 'yyyy-mm-dd'), @ischar);
  p.addParameter('subject', getenv('MATUDP_SUBJECT'), @ischar);
  p.addParameter('protocol', getenv('MATUDP_PROTOCOL'), @ischar);
  p.addParameter('saveTag', [], @isvector);
  p.KeepUnmatched = true;
  p.parse(varargin{:});

  info = p.Results;
end
