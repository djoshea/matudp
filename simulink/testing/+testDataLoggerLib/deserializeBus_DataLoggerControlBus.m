function [bus, valid, offset] = deserializeBus_DataLoggerControlBus(in, offset, valid)
%#codegen
% DO NOT EDIT: Auto-generated by 
%   writeDeserializeBusModelPackagedCode('testDataLogger', 'DataLoggerControlBus')

    if nargin < 2
         offset = uint16(1);
    end
    if nargin < 3
         valid = uint8(1);
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Deserializing variable-sized field dataStore
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Checking header
    if valid == uint8(0) || offset + uint16(22 - 1) > numel(in)
        valid = uint8(0);
    end
    if valid == uint8(0) || ~isequal(in(offset:offset+uint16(22-1)), ...
        uint8([1, 4, 0, typecast(uint16(9), 'uint8'), 'dataStore', typecast(uint16(4), 'uint8'), 'char', 8, 1]'))
        valid = uint8(0);
    end
    offset = offset + uint16(22);

    % Establishing size
    coder.varsize('bus.dataStore', 30);
    if valid == uint8(0) || offset + uint16(2 - 1) > numel(in)
        % buffer not large enough
        valid = uint8(0);
        bus.dataStore = zeros([30 1], 'uint8');
    else
        sz = typecast(in(offset:(offset+uint16(2-1))), 'uint16')';
        offset = offset + uint16(2);
        % check size
        if sz(1) > uint16(30), valid = uint8(0); end
        elements = uint16(1);
        for i = 1:1
             elements = elements * uint16(sz(i));
        end
        if valid == uint8(0) || offset + uint16(elements*1 - 1) > numel(in)
            % buffer not large enough
            valid = uint8(0);
            bus.dataStore = zeros([1 1], 'uint8');
        else
            % mollify codegen
            assert(sz(1) <= uint16(30));
            % read and typecast data
            assert(elements <= uint16(30));
            bus.dataStore = zeros([sz uint16(1)], 'uint8');
            if elements > uint16(0)
                bus.dataStore(1:elements) = typecast(in(offset:offset+uint16(elements*1 - 1)), 'uint8');
                offset = offset + uint16(elements*1);
            end
        end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Deserializing variable-sized field subject
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Checking header
    if valid == uint8(0) || offset + uint16(20 - 1) > numel(in)
        valid = uint8(0);
    end
    if valid == uint8(0) || ~isequal(in(offset:offset+uint16(20-1)), ...
        uint8([1, 4, 0, typecast(uint16(7), 'uint8'), 'subject', typecast(uint16(4), 'uint8'), 'char', 8, 1]'))
        valid = uint8(0);
    end
    offset = offset + uint16(20);

    % Establishing size
    coder.varsize('bus.subject', 30);
    if valid == uint8(0) || offset + uint16(2 - 1) > numel(in)
        % buffer not large enough
        valid = uint8(0);
        bus.subject = zeros([30 1], 'uint8');
    else
        sz = typecast(in(offset:(offset+uint16(2-1))), 'uint16')';
        offset = offset + uint16(2);
        % check size
        if sz(1) > uint16(30), valid = uint8(0); end
        elements = uint16(1);
        for i = 1:1
             elements = elements * uint16(sz(i));
        end
        if valid == uint8(0) || offset + uint16(elements*1 - 1) > numel(in)
            % buffer not large enough
            valid = uint8(0);
            bus.subject = zeros([1 1], 'uint8');
        else
            % mollify codegen
            assert(sz(1) <= uint16(30));
            % read and typecast data
            assert(elements <= uint16(30));
            bus.subject = zeros([sz uint16(1)], 'uint8');
            if elements > uint16(0)
                bus.subject(1:elements) = typecast(in(offset:offset+uint16(elements*1 - 1)), 'uint8');
                offset = offset + uint16(elements*1);
            end
        end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Deserializing variable-sized field protocol
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Checking header
    if valid == uint8(0) || offset + uint16(21 - 1) > numel(in)
        valid = uint8(0);
    end
    if valid == uint8(0) || ~isequal(in(offset:offset+uint16(21-1)), ...
        uint8([1, 4, 0, typecast(uint16(8), 'uint8'), 'protocol', typecast(uint16(4), 'uint8'), 'char', 8, 1]'))
        valid = uint8(0);
    end
    offset = offset + uint16(21);

    % Establishing size
    coder.varsize('bus.protocol', 30);
    if valid == uint8(0) || offset + uint16(2 - 1) > numel(in)
        % buffer not large enough
        valid = uint8(0);
        bus.protocol = zeros([30 1], 'uint8');
    else
        sz = typecast(in(offset:(offset+uint16(2-1))), 'uint16')';
        offset = offset + uint16(2);
        % check size
        if sz(1) > uint16(30), valid = uint8(0); end
        elements = uint16(1);
        for i = 1:1
             elements = elements * uint16(sz(i));
        end
        if valid == uint8(0) || offset + uint16(elements*1 - 1) > numel(in)
            % buffer not large enough
            valid = uint8(0);
            bus.protocol = zeros([1 1], 'uint8');
        else
            % mollify codegen
            assert(sz(1) <= uint16(30));
            % read and typecast data
            assert(elements <= uint16(30));
            bus.protocol = zeros([sz uint16(1)], 'uint8');
            if elements > uint16(0)
                bus.protocol(1:elements) = typecast(in(offset:offset+uint16(elements*1 - 1)), 'uint8');
                offset = offset + uint16(elements*1);
            end
        end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Deserializing fixed-sized field protocolVersion
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Checking header
    if valid == uint8(0) || offset + uint16(24 - 1) > numel(in)
        valid = uint8(0);
    end
    if valid == uint8(0) || ~isequal(in(offset:offset+uint16(24-1)), ...
        uint8([0, 4, 0, typecast(uint16(15), 'uint8'), 'protocolVersion', typecast(uint16(0), 'uint8'), '', 7, 1]'))
        valid = uint8(0);
    end
    offset = offset + uint16(24);

    % Establishing size
    if valid == uint8(0) || offset + uint16(2 - 1) > numel(in)
        % buffer not large enough
        valid = uint8(0);
        bus.protocolVersion = zeros([1 1], 'uint32');
    else
        sz = typecast(in(offset:(offset+uint16(2-1))), 'uint16')';
        offset = offset + uint16(2);
        % check size
        if sz(1) ~= uint16(1), valid = uint8(0); end
        elements = uint16(1);
        for i = 1:1
             elements = elements * uint16(sz(i));
        end
        if valid == uint8(0) || offset + uint16(elements*4 - 1) > numel(in)
            % buffer not large enough
            valid = uint8(0);
            bus.protocolVersion = zeros([1 1], 'uint32');
        else
            % read and typecast data
            assert(elements <= uint16(1));
            bus.protocolVersion = zeros([1 1], 'uint32');
            if elements > uint16(0)
                bus.protocolVersion(1:elements) = typecast(in(offset:offset+uint16(elements*4 - 1)), 'uint32');
                offset = offset + uint16(elements*4);
            end
        end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Deserializing fixed-sized field saveTag
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Checking header
    if valid == uint8(0) || offset + uint16(16 - 1) > numel(in)
        valid = uint8(0);
    end
    if valid == uint8(0) || ~isequal(in(offset:offset+uint16(16-1)), ...
        uint8([0, 4, 0, typecast(uint16(7), 'uint8'), 'saveTag', typecast(uint16(0), 'uint8'), '', 7, 1]'))
        valid = uint8(0);
    end
    offset = offset + uint16(16);

    % Establishing size
    if valid == uint8(0) || offset + uint16(2 - 1) > numel(in)
        % buffer not large enough
        valid = uint8(0);
        bus.saveTag = zeros([1 1], 'uint32');
    else
        sz = typecast(in(offset:(offset+uint16(2-1))), 'uint16')';
        offset = offset + uint16(2);
        % check size
        if sz(1) ~= uint16(1), valid = uint8(0); end
        elements = uint16(1);
        for i = 1:1
             elements = elements * uint16(sz(i));
        end
        if valid == uint8(0) || offset + uint16(elements*4 - 1) > numel(in)
            % buffer not large enough
            valid = uint8(0);
            bus.saveTag = zeros([1 1], 'uint32');
        else
            % read and typecast data
            assert(elements <= uint16(1));
            bus.saveTag = zeros([1 1], 'uint32');
            if elements > uint16(0)
                bus.saveTag(1:elements) = typecast(in(offset:offset+uint16(elements*4 - 1)), 'uint32');
                offset = offset + uint16(elements*4);
            end
        end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Deserializing fixed-sized field nextTrial
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Checking header
    if valid == uint8(0) || offset + uint16(18 - 1) > numel(in)
        valid = uint8(0);
    end
    if valid == uint8(0) || ~isequal(in(offset:offset+uint16(18-1)), ...
        uint8([0, 4, 0, typecast(uint16(9), 'uint8'), 'nextTrial', typecast(uint16(0), 'uint8'), '', 3, 1]'))
        valid = uint8(0);
    end
    offset = offset + uint16(18);

    % Establishing size
    if valid == uint8(0) || offset + uint16(2 - 1) > numel(in)
        % buffer not large enough
        valid = uint8(0);
        bus.nextTrial = zeros([1 1], 'uint8');
    else
        sz = typecast(in(offset:(offset+uint16(2-1))), 'uint16')';
        offset = offset + uint16(2);
        % check size
        if sz(1) ~= uint16(1), valid = uint8(0); end
        elements = uint16(1);
        for i = 1:1
             elements = elements * uint16(sz(i));
        end
        if valid == uint8(0) || offset + uint16(elements*1 - 1) > numel(in)
            % buffer not large enough
            valid = uint8(0);
            bus.nextTrial = zeros([1 1], 'uint8');
        else
            % read and typecast data
            assert(elements <= uint16(1));
            bus.nextTrial = zeros([1 1], 'uint8');
            if elements > uint16(0)
                bus.nextTrial(1:elements) = typecast(in(offset:offset+uint16(elements*1 - 1)), 'uint8');
                offset = offset + uint16(elements*1);
            end
        end
    end


end