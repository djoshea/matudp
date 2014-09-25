function writeInitializeBusCode(busName)
% writes an m-file initializeBus_*BusName* which can initialize a zeroed or
% empty bus for the purposes of code generation

    % write to temp file, copy later if files differ
    fnName = sprintf('initializeBus_%s', busName);
    fileName = BusSerialize.getGeneratedCodeFileName(fnName);
    temp = tempname();
    fid = fopen(temp, 'w+');
    
    [busObject, busSpec] = BusSerialize.getBusFromBusName(busName);
    elements = busObject.Elements;
    
    w = @(varargin) BusSerialize.writeReplaceNewline(fid, varargin{:});
    
    w('function bus = %s()\n', fnName);
    w('%%#codegen\n');
    w('%% DO NOT EDIT: Auto-generated by \n');
    w('%%   writeInitializeBusGeneratedCode(''%s'')\n', busName);
    w('\n');
    
    for iElement = 1:numel(elements)
        e = elements(iElement);
        
        signalSpec = busSpec.signals(iElement);

        % compute string to use for dimensions
        dims = e.Dimensions;
        ndims = numel(dims);
        if ndims == 1
            dimsStr = mat2str([dims 1]);
            dimsForEmpty = [dims 1];
        else
            dimsStr = mat2str(dims);
            dimsForEmpty = dims;
        end
        dimsForEmpty(signalSpec.isVariableByDim) = 0;
        
        if signalSpec.isBus
            % nested bus definition, write initialization code
            BusSerialize.writeInitializeBusCode(signalSpec.busName);
        
            subFnName = BusSerialize.getGeneratedCodeFunctionName(sprintf('initializeBus_%s', signalSpec.busName));
            w('    bus.%s = repmat(%s(), %s);\n', e.Name, subFnName, dimsStr);
            
        else
            % declare as variable size
            if signalSpec.isVariable
                w('    coder.varsize(''bus.%s'', %s, %s);\n', ...
                    e.Name, mat2str(signalSpec.maxSize), mat2str(signalSpec.isVariableByDim));
            end
            
            if signalSpec.isEnum
                w('    bus.%s = %s.%s;\n', e.Name, signalSpec.enumName, char(signalSpec.value));
                
            elseif isempty(signalSpec.value)
                % must explicitly initialize via call to zeros since []
                % won't work
                w('    bus.%s = zeros(%s, ''%s'');\n', e.Name, mat2str(dimsForEmpty), signalSpec.classSimulink);
                
            else
                % initialize to value in signalSpec
                val = cast(signalSpec.value, signalSpec.classSimulink);
                if isvector(val)
                    if e.Dimensions(1) > 1
                        % make column vector
                        val = val(:);
                    else
                        % make row vector
                        val = val(:)';
                    end
                end     
                str = mat2str(val, 'class');
                w('    bus.%s = %s;\n', e.Name, str);
            end
        end
    end
        
    w('\n');
    w('end');
    
    fclose(fid);
    
    % copy now if files differed
    update = BusSerialize.overwriteIfFilesDiffer(temp, fileName);
    delete(temp);
    if update
        fprintf('BusSerialize: Updating %s\n', fnName);
    end
end
