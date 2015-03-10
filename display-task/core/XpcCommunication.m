classdef XpcCommunication < handle

    properties(SetAccess=protected)
        truncateNull = true; % if true, trims null (uint8(0)) from end of received packets

        targetIP
        targetPort
        rxPort % local port to receive on
    end

    properties(SetAccess=protected,Hidden)
        sock % network socket
        udpSend % udp object to send packets back to xpc
        state
    end

    properties(Dependent)
        isOpen
    end

    properties(Constant, Hidden)
        PACKET_SIZE = 1600;
        STATE_CLOSED = 0;
        STATE_OPEN = 1;
    end

    methods 
        function xcom = XpcCommunication()
            xcom.state = XpcCommunication.STATE_CLOSED;

            % extract network parameters from display context
            cxt = getDisplayContext();
            xcom.targetIP = cxt.networkTargetIP;
            xcom.targetPort = cxt.networkTargetPort;
            xcom.rxPort = cxt.networkReceivePort;
        end

        function tf = get.isOpen(xcom)
            tf = xcom.state == XpcCommunication.STATE_OPEN;
        end

        function open(xcom)
            if xcom.isOpen 
                return;
            end

            xcom.sock = pnet('udpsocket', xcom.rxPort);
            if xcom.sock < 0
                error('Error opening socket on port %d', xcom.rxPort);
            end

            % open udp send object as well
            xcom.udpSend = udp(xcom.targetIP, xcom.targetPort);
            fopen(xcom.udpSend);

            xcom.state = XpcCommunication.STATE_OPEN;
        end

        function close(xcom)
            try
                pnet(xcom.sock, 'close');
            catch 
            end
            try
                fclose(xcom.udpSend);
            catch 
            end
            try
                delete(xcom.udpSend);
            catch
            end

            xcom.state = XpcCommunication.STATE_CLOSED;
        end

        function delete(xcom)
            xcom.close();
        end

        function str = readPacket(xcom)
            % Read raw packet string from xpc
            % See also readTaggedPacket()
            
            xcom.open();
            psize=pnet(xcom.sock,'readpacket', xcom.PACKET_SIZE, 'noblock');
            if psize > 0
                str = char(pnet(xcom.sock, 'read', xcom.PACKET_SIZE, 'uint8', 'noblock'));
                if xcom.truncateNull
                    lastInd = find(str > 0, 1, 'last');
                    str = str(1:lastInd);
                end
            elseif pnet(xcom.sock, 'status') == 0
                fprintf('Error reading from pnet socket! Reconnecting...\n');
                xcom.close();
                xcom.open();
                str = '';
            else
                str = '';
            end
        end

        function str = writePacket(xcom, data)
            % Write raw packet string to xpc
            if ~exist('data', 'var')
                error('Usage: xcom.writePacket(data)');
            end
            xcom.open();
            fwrite(xcom.udpSend, data);
        end

        function tags = parseTaggedPacket(xcom, str)
            % Reads a packet whose string contains text wrapped in <tags>
            % tags will be a struct indicating the tag type (.type) and 
            % tag contents (.str)
            %
            % Example: if packet contains <typeA>text1</typeA><typeB>text2</typeB>
            %   tags(1).type = 'typeA'; tags(1).str = 'text1';
            %   tags(2).type = 'typeB'; tags(2).str = 'text2';

            if ~isempty(str)
                % regex to match <tag>text</tag>
                pat = '<(?<type>[a-zA-Z0-9_\-\.]+)>(?<str>.*?)</\k<type>>';
                tags = makecol(regexp(str, pat, 'names'));
            else
                tags = struct('type', {}, 'str', {});
            end
        end

        function tags = readTaggedPacket(xcom)
            % reads a packet from xpc, parses the string with parseTaggedPacket
            % and returns the tags within
            str = xcom.readPacket();
            tags = xcom.parseTaggedPacket(str);
        end

        function allTags = readTaggedPackets(xcom)
            % reads multiple packets from xpc (as many as are in buffer) and 
            % parses each with parseTaggedPacket. Concatenates the tags from 
            % all packets.
            allTags = [];
            while true
                tags = readTaggedPacket(xcom);
                if isempty(tags)
                    break;
                end

                if isempty(allTags)
                    allTags = tags;
                else
                    allTags = [allTags; tags];
                end
            end
        end

        function [tags groups] = readTaggedPacketsParseData(xcom)
            % reads multiple tagged packets from xpc (as many as are in the buffer)
            % parses them with parseTaggedPacket. Automatically de-serializes
            % the <ds> tagged strings and returns a struct groups with
            % groups.groupName.signals containing the signals sent in group groupName
            %
            % This enables xpc to send data to the display pc using the data serializer
            % block and a <ds>...</ds> wrapper concatenated into a packet containing
            % display commands
            
            tags = xcom.readTaggedPackets();
            groups = []; 

            nTags = length(tags);
            removeFromTags = false(nTags, 1);
            for iTag = 1:nTags
                type = tags(iTag).type;
                str = tags(iTag).str;
                if strcmp(type, 'ds')
                    groupsThisTag = makecol(DataSerializerParser.parseGroups(str));
                    if isempty(groupsThisTag)
                        continue;
                    end

                    removeFromTags(iTag) = true;
                    
                    for iGroup = 1:length(groupsThisTag)
                        g = groupsThisTag(iGroup);
                        groups.(g.name) = g.signals;
                    end
                end
            end

            tags = tags(~removeFromTags);
            if isempty(groups)
                groups = struct([]);
            end
        end
    end

end
