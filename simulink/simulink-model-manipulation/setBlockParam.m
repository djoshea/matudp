function setBlockParam(blk, varargin)
% works just like set_param(blk, varargin{:}), excepts only calls set_param
% when the value of the parameter would change

if ~blockExists(blk)
    warning('Block does not exist');
end

params = varargin(1:2:end);
values = varargin(2:2:end);
setArgs = {};
for i = 1:length(params)
    val = get_param(blk, params{i});
    if ~isequal(val, values{i})
        setArgs(end+1:end+2) = [params(i) values(i)];
    end
end

if ~isempty(setArgs)
    set_param(blk, setArgs{:});
end  

end