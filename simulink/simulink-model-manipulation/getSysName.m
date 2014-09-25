function sysName = getSysName(bName)
    % get system name from block name
    firstSlash = find(bName == '/', 1, 'first');
    if ~isempty(firstSlash)
        sysName = bName(1:firstSlash-1);
    else
        sysName = bName;
    end
end