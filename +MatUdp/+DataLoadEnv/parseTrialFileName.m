function [info, valid] = parseTrialFileName(fname)
    pat = '(?<subject>[^_]+)_(?<protocol>[^_]+)_id(?<trialId>[\d]+)_time(?<timestamp>[\d\.]+)\.mat';
    
    match = regexp(fname, pat, 'names', 'once');
    
    if iscell(fname)
        % names is cell array of struct
        valid = false(numel(fname), 1);
        for i = 1:numel(fname)
            if ~isempty(match{i})
                info(i, 1).subject = match{i}.subject; %#ok<*AGROW>
                info(i, 1).protocol = match{i}.protocol;
                info(i, 1).trialId = str2double(match{i}.trialId);
                info(i, 1).datenum = datenum(match{i}.timestamp, 'yyyymmdd.HHMMSS.FFF');
                valid(i) = true;
            else
                info(i, 1).subject = '';
                info(i, 1).protocol = '';
                info(i, 1).trialId = NaN;
                info(i, 1).datenum = NaN;
            end
        end
        
    else
        if ~isempty(match)
            info.subject = match.subject;
            info.protocol = match.protocol;
            info.trialId = str2double(match.trialId);
            info.datenum = datenum(match.timestamp, 'yyyymmdd.HHMMSS.FFF');
            valid = true;
        else
            info.subject = '';
            info.protocol = '';
            info.trialId = NaN;
            info.datenum = NaN;
            valid = false;
        end
    end           
    
end