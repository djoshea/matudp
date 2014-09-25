function p = getGeneratedCodePath()
% retrieves codePath setting for where to author utility code
% throws an error if it isn't set

try
    p = evalin('base', 'BusSerializeInfo.codePath');
    assert(~isempty(p));
catch
    error('Call BusSerialize.setGeneratedCodePath(''/path/to/code'') to indicate where to store authored code');
end

end