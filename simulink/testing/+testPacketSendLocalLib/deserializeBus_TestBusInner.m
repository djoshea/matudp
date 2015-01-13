function [bus, valid, offset] = deserializeBus_TestBusInner(in, offset, valid)

    if nargin < 2
         offset = uint16(1);
    end
    if nargin < 3
         valid = uint8(1);
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        if valid == uint8(0) || offset + uint16(21 - 1) > numel(in)
        valid = uint8(0);
    end
    if valid == uint8(0) || ~isequal(in(offset:offset+uint16(21-1)), ...
        uint8([0, 2, 0, typecast(uint16(10), 'uint8'), 'centerSize', typecast(uint16(2), 'uint8'), 'mm', 3, 1]'))
        valid = uint8(0);
    end
    offset = offset + uint16(21);

        if valid == uint8(0) || offset + uint16(2 - 1) > numel(in)
                valid = uint8(0);
        bus.centerSize = zeros([2 1], 'uint8');
    else
        sz = typecast(in(offset:(offset+uint16(2-1))), 'uint16')';
        offset = offset + uint16(2);
                if sz(1) ~= uint16(2), valid = uint8(0); end
        elements = uint16(1);
        for i = 1:1
             elements = elements * uint16(sz(i));
        end
        if valid == uint8(0) || offset + uint16(elements*1 - 1) > numel(in)
                        valid = uint8(0);
            bus.centerSize = zeros([2 1], 'uint8');
        else
                        assert(elements <= uint16(2));
            bus.centerSize = zeros([2 1], 'uint8');
            if elements > uint16(0)
                bus.centerSize(1:elements) = typecast(in(offset:offset+uint16(elements*1 - 1)), 'uint8');
                offset = offset + uint16(elements*1);
            end
        end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        if valid == uint8(0) || offset + uint16(27 - 1) > numel(in)
        valid = uint8(0);
    end
    if valid == uint8(0) || ~isequal(in(offset:offset+uint16(27-1)), ...
        uint8([0, 2, 0, typecast(uint16(16), 'uint8'), 'holdWindowCenter', typecast(uint16(2), 'uint8'), 'mm', 3, 1]'))
        valid = uint8(0);
    end
    offset = offset + uint16(27);

        if valid == uint8(0) || offset + uint16(2 - 1) > numel(in)
                valid = uint8(0);
        bus.holdWindowCenter = zeros([1 1], 'uint8');
    else
        sz = typecast(in(offset:(offset+uint16(2-1))), 'uint16')';
        offset = offset + uint16(2);
                if sz(1) ~= uint16(1), valid = uint8(0); end
        elements = uint16(1);
        for i = 1:1
             elements = elements * uint16(sz(i));
        end
        if valid == uint8(0) || offset + uint16(elements*1 - 1) > numel(in)
                        valid = uint8(0);
            bus.holdWindowCenter = zeros([1 1], 'uint8');
        else
                        assert(elements <= uint16(1));
            bus.holdWindowCenter = zeros([1 1], 'uint8');
            if elements > uint16(0)
                bus.holdWindowCenter(1:elements) = typecast(in(offset:offset+uint16(elements*1 - 1)), 'uint8');
                offset = offset + uint16(elements*1);
            end
        end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        if valid == uint8(0) || offset + uint16(27 - 1) > numel(in)
        valid = uint8(0);
    end
    if valid == uint8(0) || ~isequal(in(offset:offset+uint16(27-1)), ...
        uint8([0, 2, 0, typecast(uint16(16), 'uint8'), 'holdWindowTarget', typecast(uint16(2), 'uint8'), 'mm', 5, 1]'))
        valid = uint8(0);
    end
    offset = offset + uint16(27);

        if valid == uint8(0) || offset + uint16(2 - 1) > numel(in)
                valid = uint8(0);
        bus.holdWindowTarget = zeros([1 1], 'uint16');
    else
        sz = typecast(in(offset:(offset+uint16(2-1))), 'uint16')';
        offset = offset + uint16(2);
                if sz(1) ~= uint16(1), valid = uint8(0); end
        elements = uint16(1);
        for i = 1:1
             elements = elements * uint16(sz(i));
        end
        if valid == uint8(0) || offset + uint16(elements*2 - 1) > numel(in)
                        valid = uint8(0);
            bus.holdWindowTarget = zeros([1 1], 'uint16');
        else
                        assert(elements <= uint16(1));
            bus.holdWindowTarget = zeros([1 1], 'uint16');
            if elements > uint16(0)
                bus.holdWindowTarget(1:elements) = typecast(in(offset:offset+uint16(elements*2 - 1)), 'uint16');
                offset = offset + uint16(elements*2);
            end
        end
    end


end