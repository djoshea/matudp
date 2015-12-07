function etherinit = mxpcethercheck(id)
% override

etherinit = 1;
return;

% etherinit = 1;

% Copyright 2010 The MathWorks, Inc.

% configid = [{'ID1'}, {'ID2'}, {'ID3'}, {'ID4'}, {'ID5'}, {'ID6'}, {'ID7'}, {'ID8'}];
% 
% if nargin == 0
%     id = get_param(gcb, 'ID');
% end
% 
% etherinit = length(find_system(bdroot, ...
%                                'FollowLinks',    'on',  ...
%                                'LookUnderMasks', 'all', ...
%                                'MaskType',       'xpcetherinit', ...
%                                'ID',             id));
% 
% for j = 1 : length(configid)
%     etherinit = etherinit + length(find_system(bdroot, ...
%                                                'FollowLinks',    'on',  ...
%                                                'LookUnderMasks', 'all', ...
%                                                'MaskType',       'xpcnwconfig', ...
%                                                configid{j},      id));
% end