function p = getPathToBusSerializePackageDir()
% assumes this file lives in the +BusSerialize directory

    stack = dbstack('-completenames');
    p = fileparts(stack(1).file);
end
