function sys = getCurrentRootSystem()
% like gcs, except returns the root system's name, ignoring children
% ensures that the name of the system is fully qualified with any
% containing package names

    sys = getPackageQualifiedName(getSysName(gcs));
    
end