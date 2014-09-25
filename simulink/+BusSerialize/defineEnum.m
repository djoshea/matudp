function defineEnum(enumName, members, varargin)

p = inputParser();
p.addOptional('values', 0:(numel(members)-1), @(x) isnumeric(x) && isvector(x));
p.addParamValue('default', [], @(x) isempty(x) || ischar(x));
p.addParamValue('description', '', @ischar);
p.parse(varargin{:});

values = p.Results.values;

if isempty(p.Results.default)
    default = members{1};
else
    default = p.Results.default;
end 

if isempty(p.Results.description)
    extraArgs = {};
else
    extraArgs = {'Description', p.Results.description};
end

if ~exist(enumName, 'class')
    % pass this along to simulink
    Simulink.defineIntEnumType(enumName, members, p.Results.values, 'DefaultValue', default, ...
        'AddClassNameToEnumNames', true, extraArgs{:});

else
    % class already exists, check for equivalency
    mc = meta.class.fromName(enumName);
    cMembers = {mc.EnumerationMemberList.Name};
    
    % check whether member lists are the same
    diff = false;
    xor = setxor(cMembers, members);
    if ~isempty(xor)
        diff = true;
    else
        % check values are the same
        cValues = cellfun(@(m) int32(eval([enumName '.' m])), members);
        
        if ~isequal(int32(values), cValues)
            diff = true;
        else
            % check whether default values are the same
            def = char(eval([enumName '.getDefaultValue()']));
            
            if ~strcmp(default, def)
                diff = true;
            end
        end
    end
    
    % if differs, issue a warning
    if diff
        warning('Specification of enum %s differs from existing class definition. Close all systems and clear classes to overwrite this definition', enumName);
    end
end
            
        
    
    
    
    