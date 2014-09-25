function addLineSafe(srcBlock, srcPortNum, dstBlock, dstPortNum )

if isempty(srcBlock) || isempty(srcPortNum)
    return;
end
if isempty(dstBlock) || isempty(dstPortNum)
    return;
end

% necessary to avoid errors with broken lines
deleteBrokenIncomingLines(dstBlock, dstPortNum);

% not strictly necessary, but neater
deleteBrokenOutgoingLines(srcBlock, srcPortNum);

if ~lineExists(srcBlock, srcPortNum, dstBlock, dstPortNum)
    [srcPort, sysName] = makePortName(srcBlock, srcPortNum);
    dstPort = makePortName(dstBlock, dstPortNum);
    add_line(sysName, srcPort, dstPort, 'autorouting', 'on');
end

end

