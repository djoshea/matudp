function tf = lineExists(srcBlock, srcPortNum, dstBlock, dstPortNum)
% tf = lineExists(srcBlock, srcPortNum, dstBlock, dstPortNum)
% return true if the line from srcBlock/srcPortNum to dstBlock/dstPortNum exists
    [blockName portNum] = getIncomingLineSource(dstBlock, dstPortNum);
    tf = strcmp(blockName, srcBlock) && portNum == srcPortNum;
end
