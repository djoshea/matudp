function [contextInfo contextName] = getDisplayContext(varargin)
% [contextInfo contextName] = getDisplayContext()
%   retrieves the current display context
%
% [contextInfo] = getDisplayContext(contextName)
%   retrieves a specific context, doesn't change current
%
% [contextInfo contextName] = getDisplayContext('setContext', contextName)
%   sets the current context, used by setDisplayContext for this purpose
%

persistent pContextName;
persistent pContextInfo;

if nargin == 2 && strcmp(varargin{1}, 'setContext')
    % set the display context 

    contextName = varargin{2};
    contextInfo = getContextInfo(contextName);

    % save the current context in the persistent
    pContextName = contextName;
    pContextInfo = contextInfo;

elseif nargin == 1
    % retrieve a specific display context, don't change current

    contextName = varargin{1};
    contextInfo = getContextInfo(contextName);

elseif nargin == 0
    % retrieve the current context
    contextName = pContextName;
    contextInfo = pContextInfo;

else
    error('Error: number of arguments must be 0-2');
end

end

function contextInfo = getContextInfo(contextName)
    assert(ischar(contextName), 'Context Name must be a string');

    map = getDisplayContextMap();
    
    if ~map.isKey(contextName)
        error('Display context %s not found', contextName);
    end 

    contextInfo = map(contextName);
end

