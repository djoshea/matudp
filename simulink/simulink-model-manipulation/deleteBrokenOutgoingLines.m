function deleteBrokenOutgoingLines(blockName, portNum)

hLine = getOutgoingLine(blockName, portNum);
if isempty(hLine)
    return;
end

hBlocks = get(hLine, 'DstBlockHandle');
if hBlocks == -1
    delete(hLine);
end

end

