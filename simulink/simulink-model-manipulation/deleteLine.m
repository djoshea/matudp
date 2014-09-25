function deleteLine(srcBlock, srcPortNum, dstBlock, dstPortNum)

[srcPort, sysName] = makePortName(srcBlock, srcPortNum);
dstPort = makePortName(dstBlock, dstPortNum);

try
    delete_line(sysName, srcPort, dstPort);
catch exc
    % squash any errors
end

end

