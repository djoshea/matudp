function setGeneratedCodePath(p)

if ~exist(p, 'dir')
    mkdir(p);
end
info.codePath = p;
assignin('base', 'BusSerializeInfo', info);

addpath(p);

end