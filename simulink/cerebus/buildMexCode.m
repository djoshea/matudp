% build xpcnbexpose.c
mex('xpcnbexpose.c', '-DMATLAB_MEX_FILE', ['-I' fullfile(matlabroot, 'toolbox\rtw\targets\xpc\target\build\xpcblocks\include')])

% build xpcnbfree.c
mex('xpcnbfree.c', '-DMATLAB_MEX_FILE', ['-I' fullfile(matlabroot, 'toolbox\rtw\targets\xpc\target\build\xpcblocks\include')])