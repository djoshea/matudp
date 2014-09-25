function numPorts = getNumInPorts(blockName)

ph = get_param(blockName, 'PortHandles');
numPorts = length(ph.Inport);

end

