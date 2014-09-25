function redrawLines(block)
% delete and redraw lines to enable better autorouting
% based heavily on http://www.mathworks.com/matlabcentral/fileexchange/34237
%
% Careful using this in callbacks, as it may make signal propagation never
% appear in the GUI.

if ~blockExists(block)
    return;
end

nIn = getNumInPorts(block);
for i = 1:nIn
    [blockName portNum] = getIncomingLineSource(block, i);
    deleteIncomingLine(block, i);
    addLineSafe(blockName, portNum, block, i);
end

nOut = getNumOutPorts(block);
for i = 1:nOut
    [blockNames portNums] = getOutgoingLineDest(block, i);
    deleteOutgoingLine(block, i);
    addLineExclusive(block, i, blockNames, portNums);
end