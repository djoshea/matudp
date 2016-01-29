function oldPath = setGeneratedCodePath(p)

try
    info = evalin('base', 'BusSerializeInfo');
    oldPath = evalin('base', 'BusSerializeInfo.codePath');
catch
    info = struct();
    oldPath = '';
end

if ~exist(p, 'dir')
    mkdir(p);
end
info.codePath = p;
assignin('base', 'BusSerializeInfo', info);

addpath(p);

end