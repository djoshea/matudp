function connectBlocksIntoSuccessiveInPorts(blocksSrc, blockDest, varargin)
% connectBlocksIntoSuccessiveInPorts(blocksSrc, blockDest, varargin)
% 
% Connects each block in blocksSrc (cellstr) to successive inports of
% blockDest.
%
% Optional params:
%   outPortNum: which outPort of blocksSrc{:} to connect [default = 1]
%   inPortNumStart: which inPort of blockDest to start at [default = 1]
%   inPortNumAdvance: how many inPorts of blockDest to advance before
%     connecting the next blockSrc. [default = 1]. E.g. to connect to
%     successive odd ports, set this to 2.

p = inputParser;
p.addRequired('blocksSrc', @iscellstr);
p.addRequired('blockDest', @ischar);
p.addParamValue('outPortNum', 1, @isnumeric);
p.addParamValue('inPortNumStart', 1, @isnumeric);
p.addParamValue('inPortNumAdvance', 1, @isnumeric);
p.parse(blocksSrc, blockDest, varargin{:});

outPortNum = p.Results.outPortNum;
inPortNum = p.Results.inPortNumStart;
inPortNumAdvance = p.Results.inPortNumAdvance;

nBlocksSrc = numel(blocksSrc);
for iSrc = 1:nBlocksSrc
    addLineSafe(blocksSrc{iSrc}, outPortNum, blockDest, inPortNum);
    inPortNum = inPortNum + inPortNumAdvance;
end