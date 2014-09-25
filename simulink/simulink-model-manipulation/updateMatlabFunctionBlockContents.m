function updateMatlabFunctionBlockContents(block, varargin)
% updateMatlabFunctionBlockContents(block, ...)
% Param/value pairs supported:
%   inputTypes : cellstr
%   outputTypes : cellstr
%   code: char
%
% Programmatically update the code inside a matlab function block, as well
% as the input and output types to match cellstr inputTypes, outputTypes.
% If the contents or types of the block match already, nothing will be
% changed

p = inputParser;
p.addParamValue('inputTypes', {}, @iscellstr);
p.addParamValue('outputTypes', {}, @iscellstr);
p.addParamValue('code', '', @ischar);
p.addParamValue('inputSizes', {}, @iscell);
p.addParamValue('outputSizes', {}, @iscell);
p.addParamValue('inputSizesVariable', [], @islogical);
p.addParamValue('outputSizesVariable', [], @islogical);
p.parse(varargin{:});

% Get stateflow root
S = sfroot;

% Find this object
b = S.find('Path', block, '-isa', 'Stateflow.EMChart');

if isempty(b)
    fprintf('Could not locate EMChart for %s\n', block);
    return;
end

if ~ismember('code', p.UsingDefaults)    
    code = p.Results.code;
    
    % lazily update the contents
    if ~strcmp(b.Script, code)
        b.Script = code;
    end
end

if ~ismember('inputTypes', p.UsingDefaults)
    inputTypes = p.Results.inputTypes;
    in = b.Inputs;
    nInputs = numel(in);
    assert(numel(inputTypes) == nInputs, 'Number of inputs cannot change');
    
    % lazily update input types
    for i = 1:nInputs
        if ~strcmp(in(i).DataType, inputTypes{i});
            in(i).DataType = inputTypes{i};
        end
    end
end

if ~ismember('outputTypes', p.UsingDefaults)
    outputTypes = p.Results.outputTypes;
    out = b.Outputs;
    nOutputs = numel(out);
    assert(numel(outputTypes) == nOutputs, 'Number of outputs cannot change');

    % lazily update output types
    for i = 1:nOutputs
        if ~strcmp(out(i).DataType, outputTypes{i});
            out(i).DataType = outputTypes{i};
        end
    end
end

if ~ismember('inputSizes', p.UsingDefaults)
    inputSizes = p.Results.inputSizes;
    in = b.Inputs;
    nInputs = numel(in);
    assert(numel(inputSizes) == nInputs, 'Number of input sizes cannot change');
    
    inputSizeStr = cellfun(@mat2str, inputSizes, 'UniformOutput', false);
    
    % lazily update input size strings
    for i = 1:nInputs
        if ~strcmp(in(i).Props.Array.Size, inputSizeStr{i});
            in(i).Props.Array.Size = inputSizeStr{i};
        end
    end
end

if ~ismember('outputSizes', p.UsingDefaults)
    outputSizes = p.Results.outputSizes;
    out = b.Outputs;
    nOutputs = numel(out);
    assert(numel(outputSizes) == nOutputs, 'Number of outputs cannot change');

    outputSizeStr = cellfun(@mat2str, outputSizes, 'UniformOutput', false);
    
    % lazily update output size strings
    for i = 1:nOutputs
        if ~strcmp(out(i).Props.Array.Size, outputSizeStr{i});
            out(i).Props.Array.Size = outputSizeStr{i};
        end
    end
end

if ~ismember('inputSizesVariable', p.UsingDefaults)
    inputSizesVariable = p.Results.inputSizesVariable;
    in = b.Inputs;
    nInputs = numel(in);
    assert(numel(inputSizesVariable) == nInputs, 'Number of input sizes cannot change');
     
    % lazily update input size variable-size flag
    for i = 1:nInputs
        if ~isequal(in(i).Props.Array.IsDynamic, inputSizesVariable(i));
            in(i).Props.Array.IsDynamic = inputSizesVariable(i);
        end
    end
end

if ~ismember('outputSizesVariable', p.UsingDefaults)
    outputSizesVariable = p.Results.outputSizesVariable;
    out = b.Outputs;
    nOutputs = numel(out);
    assert(numel(outputSizesVariable) == nOutputs, 'Number of output sizes cannot change');
     
    % lazily update Output size variable-size flag
    for i = 1:nOutputs
        if ~isequal(out(i).Props.Array.IsDynamic, outputSizesVariable(i));
            out(i).Props.Array.IsDynamic = outputSizesVariable(i);
        end
    end
end
