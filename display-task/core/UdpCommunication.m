classdef UdpCommunication < handle

    properties(SetAccess=protected)
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
        function com = UdpCommunication(cxt)
            com.state = UdpCommunication.STATE_CLOSED;

            % extract network parameters from display context
            com.targetIP = cxt.networkTargetIP;
            com.targetPort = cxt.networkTargetPort;
            com.rxPort = cxt.networkReceivePort;
        end

        function tf = get.isOpen(com)
            tf = com.state == XpcCommunication.STATE_OPEN;
        end

        function open(com)
            if com.isOpen 
                return;
            end

            udpMexReceiver('start', sprintf('%s:%d', com.targetIP, com.rxPort), num2str(com.targetPort));
            com.state = XpcCommunication.STATE_OPEN;
        end

        function close(com)
            udpMexReceiver('stop');
            com.state = XpcCommunication.STATE_CLOSED;
        end

        function delete(com)
            com.close();
        end

        function str = writePacket(com, varargin)
            com.open();
            udpMexReceiver('send', varargin{:});
        end

        function groups = readGroups(com)
            groups = udpMexReceiver('retrieveGroups');

        end
    end

end
