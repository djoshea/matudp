function [blockName portNum] = getIncomingLineSource(blockName, portNum)
    hLine = getIncomingLine(blockName, portNum);
    if isempty(hLine)
        blockName = [];
        portNum = [];
    else
        hBlock = get_param(hLine, 'SrcBlockHandle');
        if(hBlock == -1)
            blockName = [];
            portNum = [];
            return;
        end
        blockName = getfullname(hBlock);
        hPort = get_param(hLine, 'SrcPortHandle');
        portNum = get_param(hPort, 'PortNumber');
    end
end