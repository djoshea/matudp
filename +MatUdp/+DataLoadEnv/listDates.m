function [dateStrList, dateNumList, searchFolder] = listDates(varargin)
    searchFolder = MatUdp.DataLoadEnv.buildPathToSubjectRoot(varargin{:});
    
    if ~exist(searchFolder, 'dir')
        warning('Subject folder %s not found', searchFolder);
    end
    
    % enumerate saveTag folders in that directory
    list = dir(searchFolder);
    mask = false(numel(list), 1);
    dateStrList = cell(numel(list));
    dateNumList = nan(numel(list), 1);

    for i = 1:numel(list)
        if ~list(i).isdir, continue, end;
        try
            dateNumList(i) = datenum(list(i).name, 'YYYY-MM-DD');
            dateStrList{i} = list(i).name;
            mask(i) = true;
        catch
        end
    end

    dateNumList = dateNumList(mask);
    dateStrList = dateStrList(mask);
end

