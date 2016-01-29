function p = getGeneratedCodePath()
% retrieves codePath setting for where to author utility code
% throws an error if it isn't set

try
    p = evalin('base', 'BusSerializeInfo.codePath');
catch
    p = [];
end

assert(~isempty(p), 'Call BusSerialize.setGeneratedCodePath(''/path/to/code'') to indicate where to store authored code');

end