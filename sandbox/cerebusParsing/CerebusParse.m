classdef CerebusParse < coder.ExternalDependency
    %#codegen
    % Author: Dan O'Shea [ dan { at } djoshea.com ] (c) 2015
    
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
            % get path to this file
            stack = dbstack('-completenames');
            filePath = fileparts(stack(1).file);
            buildInfo.addIncludePaths(filePath);
            buildInfo.addIncludeFiles('cerebusParse.h');
            buildInfo.addSourcePaths(filePath);
            buildInfo.addSourceFiles('cerebusParse.c');
            
            % for nblib.h
            buildInfo.addIncludePaths(fullfile(matlabroot, 'toolbox\rtw\targets\xpc\target\build\xpcblocks\include'));
            buildInfo.addSourcePaths(fullfile(matlabroot, 'toolbox\rtw\targets\xpc\target\build\xpcblocks\'));
            
            % for cnblib.h
%             buildInfo.addIncludePaths(fullfile(matlabroot, 'toolbox\shared\xpc\canad\utils'));
%             buildInfo.addIncludePaths(fullfile(matlabroot, 'toolbox\shared\xpc\canad\utils\include'));
%             buildInfo.addSourcePaths(fullfile(matlabroot, 'toolbox\shared\xpc\canad\utils'));
%             buildInfo.addSourceFiles(fullfile(matlabroot, 'toolbox\shared\xpc\canad\utils\cnblib.c'));
            
%             [~, linkLibExt, ~, ~] = ctx.getStdLibInfo();
            
%             % Link files
%             linkPath = fullfile(matlabroot, 'toolbox\rtw\targets\xpc\target\build\xpcblocks\lib');
%             linkPriority = '';
%             linkPrecompiled = true;
%             linkLinkOnly = true;
%             group = '';
%             buildInfo.addLinkObjects('nblib_vc.lib', linkPath, ...
%                 linkPriority, linkPrecompiled, linkLinkOnly, group);
%             
%             buildInfo.addLinkObjects('xpcip_vc.lib', linkPath, ...
%                 linkPriority, linkPrecompiled, linkLinkOnly, group);
%             
%             buildInfo.addLinkObjects('etherlib_vc.lib', linkPath, ...
%                 linkPriority, linkPrecompiled, linkLinkOnly, group);
%             
%             buildInfo.addLinkObjects('ether8255x_vc.lib', linkPath, ...
%                 linkPriority, linkPrecompiled, linkLinkOnly, group);

%             buildInfo.addLinkObjects();
        end
        
        % use nbExtractPacketData when the data is stored
        % inside a network buffer. pp is the pointer to the cbPKT data that
        % gets passed to the other functions below. pBufferEnd is a pointer
        % to the end of the data in memory that is used by hasNext below.
        function [pp, pBufferEnd] = nbExtractPacketData(nbInput)
            coder.cinclude('cerebusParse.h');
            pp = coder.opaque('cbPKT_GENERIC*', 'NULL');
            pBufferEnd = coder.opaque('UINT8_T*', 'NULL');
            
            packetLen = uint32(0);
            pp = coder.ceval('cb_nbExtractPacketData', nbInput, coder.ref(packetLen));
                    
            % returns NULL on error
            if cast(pp, 'uint32') == 0
                error('CerebusParse: Could not extract packet data');
            end
            
            % grab pointer to end of data buffer
            pBufferEnd = coder.ceval('cb_getPointerToBufferEnd', pp, packetLen);
        end
        
        function nbFree(nbInput)
            tf = coder.nullcopy(uint8(0));
            tf = coder.ceval('cb_nbFree', nbInput);
            if tf
                error('CerebusParse: Error freeing packet data');
            end 
        end
        
        % use this function when you're manually passing in the data as a
        % uint8 vector. 
        % 
        % returns opaque cbPKT_GENERIC*, opaque UINT8_T*
        function [pp, pBufferEnd] = getPointersFromRawData(data)
            coder.cinclude('cerebusParse.h');
            assert(isa(data, 'uint8'));
            pp = coder.opaque('cbPKT_GENERIC*', 'NULL');
            pBufferEnd = coder.opaque('UINT8_T*', 'NULL');
            pp = coder.ceval('cb_getPointer', coder.ref(data));
            pBufferEnd = coder.ceval('cb_getPointerToBufferEnd', pp, uint32(numel(data)));
        end
        
        function [pp, pBufferEnd] = getPointersFromDataPtr(dataPtr, dataLen)
            coder.cinclude('cerebusParse.h');
            assert(isa(dataPtr, 'uint32'));
            pp = coder.opaque('cbPKT_GENERIC*', 'NULL');
            pBufferEnd = coder.opaque('UINT8_T*', 'NULL');
            pp = coder.ceval('(cbPKT_GENERIC*)', dataPtr); % do a cast operation
            pBufferEnd = coder.ceval('cb_getPointerToBufferEnd', pp, uint32(dataLen));
        end
        
        % returns logical as uint8
        function tf = hasNext(pp, pBufferEnd)
            coder.cinclude('cerebusParse.h');
            tf = coder.nullcopy(uint8(0));
            tf = coder.ceval('cb_hasNext', pp, pBufferEnd);
        end
        
        % returns opaque cbPKT_GENERIC*
        function pNext = getNext(pp)
            coder.cinclude('cerebusParse.h');
            pNext = coder.opaque('cbPKT_GENERIC*', 'NULL');
            pNext = coder.ceval('cb_getNext', pp);
        end
        
        % returns uint32
        function t = getTime(pp)
            coder.cinclude('cerebusParse.h');
            t = coder.nullcopy(uint32(0));
            t = coder.ceval('cb_getTime', pp);
        end
        
        % returns uint16
        function c = getChannel(pp)
            coder.cinclude('cerebusParse.h');
            c = coder.nullcopy(uint16(0));
            c = coder.ceval('cb_getChannel', pp);
        end
        
        % return logical as uint8
        function tf = isSpikePacket(pp)
            coder.cinclude('cerebusParse.h');
            tf = coder.nullcopy(uint8(0));
            tf = coder.ceval('cb_isSpikePacket', pp);
        end
        
        % returns logical as uint8
        function tf = isContinuousPacketForGroup(pp, group)
            coder.cinclude('cerebusParse.h');
            tf = coder.nullcopy(uint8(0));
            tf = coder.ceval('cb_isContinuousPacketForGroup', pp, uint8(group));
        end 
        
        % returns uint8
        function u = getSpikeUnit(pp)
            coder.cinclude('cerebusParse.h');
            u = coder.nullcopy(uint8(0));
            u = coder.ceval('cb_getSpikeUnit', pp);
        end
        
        % the buffer is returned from this function solely so that code
        % generation treats the buffer as mutable and doesn't make a copy
        % before passing it in
        function buffer = copySpikeWaveformToBufferColumn(pp, buffer, col)
            coder.cinclude('cerebusParse.h');
            assert(nargout > 0, 'Store the buffer output from this function so that it is properly written to');
            coder.ceval('cb_copySpikeWaveform', pp, coder.ref(buffer(1, col)), size(buffer, 1)); 
        end
            
        % the buffer is returned from this function solely so that code
        % generation treats the buffer as mutable and doesn't make a copy
        % before passing it in
        function buffer = copyContinuousSamplesToBufferColumn(pp, buffer, col)
            coder.cinclude('cerebusParse.h');
            assert(nargout > 0, 'Store the buffer output from this function so that it is properly written to');
            coder.ceval('cb_copyContinuousSamples', pp, coder.ref(buffer(1, col)), size(buffer, 1)); 
        end
    end
end
