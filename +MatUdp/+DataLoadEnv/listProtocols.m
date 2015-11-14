function [protocolList, searchFolder] = listProtocols(varargin)
    searchFolder = MatUdp.DataLoadEnv.buildPathToDate(varargin{:});
    
    if ~exist(searchFolder, 'dir')
        warning('Date folder %s not found', searchFolder);
    end
    
    % enumerate saveTag folders in that directory
    list = dir(searchFolder);
    mask = false(numel(list), 1);
    protocolList = cell(numel(list), 1);

    for i = 1:numel(list)
        if ~list(i).isdir || strncmp(list(i).name, '.', 1), continue, end;
        protocolList{i} = list(i).name;
        mask(i) = ~isempty(MatUdp.DataLoadEnv.listSaveTags(varargin{:}, 'protocol', list(i).name));
    end

    protocolList = protocolList(mask);
end

