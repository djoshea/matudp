function [buffer, offset] = bytePackInBuffer(in, offset, varargin)
%#codegen

    nV = numel(varargin);
    if isempty(in)
        sz = 0;
        for iV = 1:nV
            sz = sz + numel(typecast(varargin{iV}(:), 'uint8'));
        end
        buffer = zeros(sz, 1, 'uint8');
    else
        buffer = uint8(in);
    end

    szbuffer = uint16(numel(buffer));

    for iV = 1:nV
        sz = uint16(numel(typecast(varargin{iV}(:), 'uint8')));

        if(offset+sz-uint16(1) > szbuffer) % buffer overrun checking
            %error('Buffer overflow!');
            break;
        end

        buffer(offset:(offset+sz-uint16(1))) = typecast(varargin{iV}(:), 'uint8');
        offset = offset + sz;
    end
    
end
