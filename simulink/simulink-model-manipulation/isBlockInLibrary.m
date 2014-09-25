function tf = isBlockInLibrary(block)

bh = getHandleFromBlockName(block);
sysdgmType = lower(get_param(bdroot(bh), 'BlockDiagramType'));
tf = isequal(sysdgmType, 'library');
    
end