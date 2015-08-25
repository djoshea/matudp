%================================================================
% This class abstracts the API to an external Adder library.
% It implements static methods for updating the build information
% at compile time and build time.
%================================================================

classdef AdderAPI < coder.ExternalDependency
    %#codegen
    
    methods (Static)
        
        function bName = getDescriptiveName(~)
            bName = 'AdderAPI';
        end
        
        function tf = isSupportedContext(ctx)
            if  ctx.isMatlabHostTarget()
                tf = true;
            else
                error('adder library not available for this target');
            end
        end
        
        function updateBuildInfo(buildInfo, ctx)
            [~, linkLibExt, execLibExt, ~] = ctx.getStdLibInfo();
            
            % Header files
            hdrFilePath = 'C:\Users\djoshea\code\matudp\sandbox\cerebusParsing';
            buildInfo.addIncludePaths(hdrFilePath);
            
            buildInfo.addSourceFiles('C:\Users\djoshea\code\matudp\sandbox\cerebusParsing\cerebusParse.c');
            
            % Link files
%             linkFiles = strcat('cerebusParse', linkLibExt);
%             linkPath = hdrFilePath;
%             linkPriority = '';
%             linkPrecompiled = false;
%             linkLinkOnly = false;
%             group = '';
%             buildInfo.addLinkObjects(linkFiles, linkPath, ...
%                 linkPriority, linkPrecompiled, linkLinkOnly, group);
            
            % Non-build files
            nbFiles = 'cerebusParse';
            nbFiles = strcat(nbFiles, execLibExt);
            buildInfo.addNonBuildFiles(nbFiles,'','');
        end
        
        %API for library function 'adder'
        function c = callfoo(a, b)
            if coder.target('MATLAB')
                % running in MATLAB, use built-in addition
                c = a + b;
            else
                % running in generated code, call library function
                coder.cinclude('cerebusParse.h');
                coder.updateBuildInfo('C:\Users\djoshea\code\matudp\sandbox\cerebusParsing\cerebusParse.c');
                
                % Because MATLAB Coder generated adder, use the
                % housekeeping functions before and after calling
                % adder with coder.ceval.
                % Call initialize function before calling adder for the
                % first time.
                
%                 coder.ceval('adder_initialize');
                c = 0;
                c = coder.ceval('foo', a, b);
                
                
                % Call the terminate function after
                % calling adder for the last time.
                
%                 coder.ceval('adder_terminate');
            end
        end
    end
end