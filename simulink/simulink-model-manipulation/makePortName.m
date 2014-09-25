function [portName, sysName] = makePortName(bName, portNum)
    % find the leaf of the block path/name
    lastSlash = find(bName == '/', 1, 'last');
    if ~isempty(lastSlash)
        sysName = bName(1:lastSlash-1);
        bName = bName(lastSlash+1:end);
    else
        sysName = '';
    end
    
    portName = [bName '/' num2str(portNum)];
end