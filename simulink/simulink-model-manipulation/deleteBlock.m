function deleteBlock(blockName)
    if blockExists(blockName)
        deleteBlockLines(blockName);
        delete_block(blockName);
    end
end