function lines = generateCoderVarsizeStatementsForBus(busName, varName)
% for buses containing variable size elements, the top level matlab
% function blocks must include calls to coder.varsize indicating the upper
% bounds on each variable-sized bus element. This function aggregates a
% list of these calls that you can copy into this function, including top
% those needed for nested buses. Var name is the name of the top level
% variable for which the coder.varsize statements will be constructed
 
    [busObject, busSpec] = BusSerialize.getBusFromBusName(busName);
    elements = busObject.Elements;
    
    lines = {};
    
    for iElement = 1:numel(elements)
        e = elements(iElement);        
        signalSpec = busSpec.signals(iElement);
        
        if ~signalSpec.includeForSerialization
            continue;
        end

        if signalSpec.isBus
            dims = e.Dimensions;
            numElements = prod(dims);

            linesSub = cell(numElements, 1);
            for iSub = 1:numElements
                subName = sprintf('%s.%s(%d)', varName, e.Name, iSub);
                linesSub{iSub} = BusSerialize.generateCoderVarsizeStatementsForBus(signalSpec.busName, subName);
            end
            lines = cat(1, lines, linesSub);
            
        else
            if signalSpec.isVariable
                thisLine = sprintf('coder.varsize(''%s.%s'', %s, %s);', ...
                    varName, e.Name, mat2str(signalSpec.maxSize), mat2str(signalSpec.isVariableByDim));
                lines = cat(1, lines, thisLine);
            end
        end
    end
    
    if nargout == 0
        fprintf('%% generated by BusSerialize.generateCoderVarsizeStatementsForBus(''%s'', ''%s'');\n', ...
            busName, varName);
        for i = 1:numel(lines)
            fprintf('%s\n', lines{i});
        end
        fprintf('\n');
    end
end
