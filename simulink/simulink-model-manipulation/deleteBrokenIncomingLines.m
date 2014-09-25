function deleteBrokenIncomingLines(blockName, portNum)

hLine = getIncomingLine(blockName, portNum);
if isempty(hLine)
    return;
end

hBlock = get_param(hLine, 'SrcBlockHandle');
if(hBlock == -1)
    delete(hLine);
end

end

