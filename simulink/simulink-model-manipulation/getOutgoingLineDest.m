function [blockNames portNums] = getOutgoingLineDest(blockName, portNum)
    hLine = getOutgoingLine(blockName, portNum);
    if isempty(hLine)
        blockNames = [];
        portNums = [];
        return;
    end
    
    hBlocks = get(hLine, 'DstBlockHandle');
    hBlocks = hBlocks(hBlocks ~= -1);
    if isempty(hBlocks)
        blockNames = [];
        portNums = [];
        
        return;
    end
    blockNames = arrayfun(@getBlockNameFromHandle, hBlocks, 'UniformOutput', false);
    
    hPorts = get(hLine, 'DstPortHandle');
    hPorts = hPorts(hPorts ~= -1);
    portNums = arrayfun(@(h) get_param(h, 'PortNumber'), hPorts);
end
