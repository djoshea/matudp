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
                        for iG = 1:length(groups)
                            group = groups(iG);
                            fprintf('DS Group %s : \n', group.name);
                            
                            disp(groups(iG).signals);
                        end
                    otherwise
                        fprintf('Tag %s : %s\n', type, str);
                end
            end
        else
            fprintf('Non-tagged : %s\n', str);
        end

        fprintf('\n');
    end

    pause(0.01);
end


