function deleteOutgoingLine(blockName, portNum)
    if blockExists(blockName)
        hLine = getOutgoingLine(blockName, portNum);
        if ~isempty(hLine)
            delete(hLine);
        end
    end
end