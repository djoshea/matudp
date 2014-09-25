function path = getPathToSystem(sys)

if nargin == 0
    sys = getCurrentRootSystem();
end

if isempty(sys)
    path = '';
else
    sys = stripPackageQualifiersFromName(getSysName(sys));
    path = get_param(sys, 'filename');
end

end