function hLine = getIncomingLine(blockName, portNum)
    ph = get_param(blockName, 'PortHandles');
    
    hInports = ph.Inport;
    
    if portNum > numel(hInports)
        error('Input port %d not found on block %s', portNum, blockName);
    end
    
    hIn = hInports(portNum);
    
    hLine = get_param(hIn, 'Line');
    
    if hLine == -1
        % no incoming connections
        hLine = [];
        return;
    end
end