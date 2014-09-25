function param = getBlockParamEval(block, param)

param = get_param(block, param);

try
    param = eval(param);
catch
end

if ischar(param) && numel(param) >= 2
    if param(1) == '''' && param(end) == ''''
        param = param(2:end-1);
    end
end