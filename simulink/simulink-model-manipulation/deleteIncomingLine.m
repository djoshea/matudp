function deleteIncomingLine(blockName, portNum)
    hLine = getIncomingLine(blockName, portNum);
    if isempty(hLine)
        return;
    end
    
    % we can't just call delete(hLine) as hLine may have other destinations
    % besides blockName/portNum. Instead, find the source and call deleteLine
    [srcBlock srcPortNum] = getIncomingLineSource(blockName, portNum);
    
    deleteLine(srcBlock, srcPortNum, blockName, portNum);
end