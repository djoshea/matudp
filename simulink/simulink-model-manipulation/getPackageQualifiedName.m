function sys = getPackageQualifiedName(sys)
% if a loaded script or system lies within a package, add the package names ahead of
% the system name, e.g. 'System' --> 'Package1.Package2.System'

    %path = getPathToSystem(sys);
    path = which(sys);

    % split into path
    remPath = fileparts(path);

    packages = '';
    while(~isempty(remPath))
        [remPath, folder] = fileparts(remPath);
        if folder(1) == '+'
            packages = [folder(2:end) '.' packages]; %#ok<AGROW>
        else
            break;
        end
    end

    sys = [packages, sys];

end