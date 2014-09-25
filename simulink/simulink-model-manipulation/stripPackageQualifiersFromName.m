function sys = stripPackageQualifiersFromName(sys)
% if a loaded script or system lies within a package, remove the package names ahead of
% the system name, e.g. 'Package1.Package2.System' --> System

    idx = find(sys == '.', 1, 'last');
    if ~isempty(idx)
        sys = sys(idx+1:end);
    end

end