function setBlockLinkDisabled(block)

try
    setBlockParam(block, 'LinkStatus', 'inactive');
catch
    
end

end