function [files, info] = listTrialFilesInSaveTagFolder(folderSaveTag)
% Occasionally the file list will contain the same trial id duplicated at
% nearby times. Here we remove duplicates if the timestamps are very close
% (within 5 seconds). 
    filesInfo = dir(fullfile(folderSaveTag, '*.mat'));
    files = {filesInfo.name}';
    [info, valid] = MatUdp.DataLoadEnv.parseTrialFileName(files);
    
    maxDeltaTimestamp = datenum([0 0 0 0 0 5]);
    
    if any(~valid)
        warning('Ignoring %d files with invalid file names', nnz(~valid));
    end
    
    info = info(valid);
    valid = valid(valid);
    
    infoSansTime = rmfield(info, 'datenum');
    [~, firstRow, whichUniqueRow] = unique(struct2table(infoSansTime));
    
    for i = 1:numel(firstRow)
        members = find(whichUniqueRow == i);
        if numel(members) > 1
            for j = 2:numel(members)
                if abs(info(members(j)).datenum - info(members(1)).datenum) < maxDeltaTimestamp
                    valid(members(j)) = false;
                end
            end
        end
    end
    
    if any(~valid)
        warning('Ignoring %d files with duplicate trialIds and proximal timestamps', nnz(~valid));
    end
    
    files = files(valid);
    info = info(valid);
end