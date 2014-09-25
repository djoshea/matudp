function numPorts = getNumOutPorts(blockName)

ph = get_param(blockName, 'PortHandles');
numPorts = length(ph.Outport);

end

