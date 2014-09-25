function v = getEnumAsValueStruct(enumName)
% get a struct containing each member of enum enumName as a field whose
% value is the numeric value assigned to that member 

    if ~exist(enumName, 'class')
    error('Enum %s does not exist', enumName);
    end

    % class already exists, check for equivalency
    mc = meta.class.fromName(enumName);
    cMembers = {mc.EnumerationMemberList.Name};
    cValues = cellfun(@(m) int32(eval([enumName '.' m])), cMembers);

    v = struct();
    for i = 1:numel(cMembers)
        v.(cMembers{i}) = cValues(i);
    end

end
    
    
    