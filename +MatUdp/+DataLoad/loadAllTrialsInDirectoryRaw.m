function [trials, meta] = loadAllTrialsInDirectoryRaw(folder, varargin)
% returns all trials and meta files as cell arrays
    p = inputParser();
    p.addParameter('maxTrials', Inf, @isscalar); % stop after max trials
    p.parse(varargin{:});
    maxTrials = p.Results.maxTrials;

    if ~exist(folder, 'dir')
        error('Folder %s does not exist', folder);
    end
    files = dir(fullfile(folder, '*.mat'));
    if isempty(files)
        error('No mat files found in %s', folder);
    end
        
    names = {files.name};
    nFiles = numel(files);
    if nargin > 1 && nFiles > maxTrials
        nFiles = maxTrials;
    end
    data = cellvec(nFiles);
    meta = cellvec(nFiles);
    valid = falsevec(nFiles);
    
    prog = ProgressBar(nFiles, 'Loading .mat in %s', folder);
    for i = 1:nFiles
        prog.update(i);
        d = load(fullfile(folder,names{i}), 'trial', 'meta');
        if ~isempty(d) && isfield(d, 'trial') && isfield(d, 'meta')
            
            % strip groups
            [data{i}, meta{i}] = deal(d.trial, d.meta);
            valid(i) = true;
        end
    end
    prog.finish();

    trials = data(valid);
    meta = meta(valid);
    
        
end
