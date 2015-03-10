function data = savePackets(nPackets)
if nargin < 1
    nPackets = 10;
end

data = cell(nPackets, 1);
idxPacket = 1;

xpc = XpcCommunication();
xpc.open();

fprintf('Listening on port %d...\n', xpc.rxPort);
while true
    str = xpc.readPacket();

    if(length(str) > 0)
        tags = xpc.parseTaggedPacket(str);
        if ~isempty(tags)
            nTags = length(tags);
            for iTag = 1:nTags
                type = tags(iTag).type;
                str = tags(iTag).str;
                switch type
                    case 'ds'
                        groups = DataSerializerParser.parseGroups(str);
                        data{idxPacket} = groups;

                        for iG = 1:length(groups)
                            group = groups(iG);
                            fprintf('DS Group %s : \n', group.name);
                            
                            disp(groups(iG).signals);
                        end
                    otherwise
                        fprintf('Tag %s : %s\n', type, str);
                        data{idxPacket} = str;
                end
            end
        else
            fprintf('Non-tagged : %s\n', str);
            data{idxPacket} = str;
        end

        idxPacket = idxPacket + 1;
        if idxPacket > nPackets
            return;
        end
        fprintf('\n');
    end

    pause(0.001);
end


