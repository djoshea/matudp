function hLine = getOutgoingLine(blockName, portNum)
    ph = get_param(blockName, 'PortHandles');
    
    if isempty(ph) || ~isstruct(ph)
        hLine = [];
        return;
    end
    
    hOutports = ph.Outport;
    
    if portNum > numel(hOutports)
        error('Output port %d not found on block %s', portNum, blockName);
    end
    
    hOut = hOutports(portNum);
    hLine = get_param(hOut, 'Line');
    
    if hLine == -1
        % no incoming connections
        hLine = [];
        return;
    end

end