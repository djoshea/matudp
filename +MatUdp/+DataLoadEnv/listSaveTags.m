function [saveTags, searchFolder] = listSaveTags(varargin)
    folder = MatUdp.DataLoadEnv.buildPathToProtocol(varargin{:});
    
    if ~exist(folder, 'dir')
        warning('Date folder %s not found', folder);
    end
    
    % enumerate saveTag folders in that directory
    list = dir(folder);
    mask = falsevec(numel(list));
    saveTags = nanvec(numel(list));

    for i = 1:numel(list)
        if ~list(i).isdir, continue, end;
        r = regexp(list(i).name, 'saveTag(\d+)', 'tokens');
        if ~isempty(r)
            saveTags(i) = str2double(r{1});
            mask(i) = true;
        end
    end

    saveTags = saveTags(mask);
    searchFolder = folder;
end

