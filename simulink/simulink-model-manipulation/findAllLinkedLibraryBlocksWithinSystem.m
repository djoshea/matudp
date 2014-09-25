function blockNames = findAllLinkedLibraryBlocksWithinSystem(refName, sys)
% find all blocks which are referenced to (linked to a library block named)
% refName (e.g. 'myLibraryName/blockNameWithinLibrary') with block sys
% or current top-level system (default=bdroot)

if nargin < 2
    sys = bdroot;
end

% resolved links use ReferenceBlock
blocksResolved = find_system(sys, 'FollowLinks', 'on', 'LookUnderMasks', 'all', ...
    'ReferenceBlock', refName);

% disabled blocks use AncestorBlock
blocksDisabled = find_system(sys, 'FollowLinks', 'on', 'LookUnderMasks', 'all', ...
    'AncestorBlock', refName);

blockNames = cat(1, blocksResolved(:), blocksDisabled(:));

