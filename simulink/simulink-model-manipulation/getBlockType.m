function blockType = getBlockType(block)
% blockType = getBlockType(block)
% Returns the BlockType parameter of block

if blockExists(block)
    blockType = get_param(block, 'BlockType');
else
    blockType = '';
end