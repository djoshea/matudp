function [name valid] = getInputSignalName(blockName, portNum)
    ph = get_param(blockName, 'PortHandles');
    in = ph.Inport;
    
    if portNum > length(in)
        error('Input port %d not found on block %s', portNum, blockName);
    end
    
    hPort = in(portNum);
    name = get_param(hPort, 'Name');
    
    if isempty(name)
        name = '?';
        valid = false;
    else
        if name(1) == '<' && name(end) == '>'
            name = name(2:end-1);
        end
        valid = true;
    end
end