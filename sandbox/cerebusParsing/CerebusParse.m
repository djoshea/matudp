%================================================================
% This class abstracts the API to an external Adder library.
% It implements static methods for updating the build information
% at compile time and build time.
%================================================================

classdef CerebusParse < coder.ExternalDependency
    %#codegen
    
    methods (Static)
        function bName = getDescriptiveName(~)
            bName = 'CerebusParse';
        end
        
        function tf = isSupportedContext(ctx)
            if  ctx.isMatlabHostTarget()
                tf = true;
            else
                error('CerebusParse library not available for this target');
            end
        end
        
        function updateBuildInfo(buildInfo, ctx)
            %[~, linkLibExt, execLibExt, ~] = ctx.getStdLibInfo();
            
            filePath = 'C:\Users\djoshea\code\matudp\sandbox\cerebusParsing';
            buildInfo.addIncludePaths(filePath);
            buildInfo.addIncludeFiles('cerebusParse.h');
            buildInfo.addSourcePaths(filePath);
            buildInfo.addSourceFiles('cerebusParse.c');
        end
        
        % returns opaque cbPKT_GENERIC*, opaque UINT8_T*
        function [pp, pBufferEnd] = getPointers(data)
            assert(isa(data, 'uint8'));
            pp = coder.opaque('cbPKT_GENERIC*', 'NULL');
            pBufferEnd = coder.opaque('UINT8_T*', 'NULL');
            pp = coder.ceval('cb_getPointer', coder.ref(data));
            pBufferEnd = coder.ceval('cb_getPointerToBufferEnd', pp, uint32(numel(data)));
        end
        
        % returns logical as uint8
        function tf = hasNext(pp, pBufferEnd)
            tf = coder.nullcopy(uint8(0));
            tf = coder.ceval('cb_hasNext', pp, pBufferEnd);
        end
        
        % returns opaque cbPKT_GENERIC*
        function pNext = getNext(pp)
            pNext = coder.opaque('cbPKT_GENERIC*', 'NULL');
            pNext = coder.ceval('cb_getNext', pp);
        end
        
        % returns uint32
        function t = getTime(pp)
            t = coder.nullcopy(uint32(0));
            t = coder.ceval('cb_getTime', pp);
        end
        
        % returns uint16
        function c = getChannel(pp)
            c = coder.nullcopy(uint16(0));
            c = coder.ceval('cb_getChannel', pp);
        end
        
        % return logical as uint8
        function tf = isSpikePacket(pp)
            tf = coder.nullcopy(uint8(0));
            tf = coder.ceval('cb_isSpikePacket', pp);
        end
        
        function tf = isContinuousPacketForGroup(pp, group)
            tf = coder.nullcopy(uint8(0));
            tf = coder.ceval('cb_isContinuousPacketForGroup', pp, uint8(group));
        end 
        
        % returns uint8
        function u = getSpikeUnit(pp)
            u = coder.nullcopy(uint8(0));
            u = coder.ceval('cb_getSpikeUnit', pp);
        end
        
        % the buffer is returned from this function solely so that code
        % generation treats the buffer as mutable and doesn't make a copy
        % before passing it in
        function buffer = copySpikeWaveformToBufferColumn(pp, buffer, col)
            assert(nargout > 0, 'Store the buffer output from this function so that it is properly written to');
            coder.ceval('cb_copySpikeWaveform', pp, coder.ref(buffer(1, col)), size(buffer, 1)); 
        end
            
        % the buffer is returned from this function solely so that code
        % generation treats the buffer as mutable and doesn't make a copy
        % before passing it in
        function buffer = copyContinuousSamplesToBufferColumn(pp, buffer, col)
            assert(nargout > 0, 'Store the buffer output from this function so that it is properly written to');
            coder.ceval('cb_copyContinuousSamples', pp, coder.ref(buffer(1, col)), size(buffer, 1)); 
        end
    end
end