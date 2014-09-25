function tf = blockExists(bName)
    try
        get_param(bName, 'Handle');
        tf = true;
    catch
        tf = false;
    end 
end
