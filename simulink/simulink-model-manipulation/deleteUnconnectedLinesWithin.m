function deleteUnconnectedLinesWithin(block)
% delete unconnected lines within block or system
% based heavily on http://www.mathworks.com/matlabcentral/fileexchange/12352-delete-unconnected-lines

    if ~blockExists(block)
        return;
    end

    lines = find_system( block, 'LookUnderMasks', 'all', 'FindAll', 'on', 'Type', 'line' );

    for i = 1:length(lines)
        deleteIfUnconnected(lines(i));
    end
end

function deleteIfUnconnected(line)
% Delete line if it has no
%   1) no source-block
%   2) no line-children AND no destination-block
%   otherwise go recursively through all eventual line-children

    if get( line, 'SrcPortHandle' ) < 0
        delete_line(line);
        return
    end
    lineChildren = get(line, 'LineChildren');
    if isempty(lineChildren)
        if get(line, 'DstPortHandle') < 0
            delete_line(line);
        end
    else
        for i=1:length(lineChildren)
            deleteIfUnconnected(lineChildren(i));
        end
    end

end