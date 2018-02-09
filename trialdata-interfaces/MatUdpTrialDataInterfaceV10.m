classdef MatUdpTrialDataInterfaceV10 < TrialDataInterface
    % using analog channel groups where possible instead of lone analog
    % channels
    % adding special handling of analog channel groups
    % adding support for multiple spike channel groups
    
    properties
        includeSpikeData = true;
        includeWaveforms = true;
        includeContinuousNeuralData = true;

        waveformTvec = (-10:37)' / 30; % 48 sample waveform
        waveformScalingFactor = 0.25;
        
        continuousDataType = 'broadband'; % or e.g. lfp
        
        useAnalogChannelGroups = true; % false will use lone analog channels
    end

    % like V3, but uses millisecond timestamps as doubles
    properties(SetAccess=protected)
        trials % original struct array over trials
        meta % meta data merged over all trials
        nTrials
        timeUnits
        
        analogGroupChannelLists % struct where .group = {ch1 ch2 ch3}
        
        spikeTimeFieldLookup
        spikeChannelFieldLookup % spikeChannels field in trials to use for each unit
        spikeUnitFieldLookup
        spikeWaveFieldLookup
        channelUnits % col 1 is channel, col 2 is units
        unitFieldNames
        waveFieldNames

        nContinuousNeuralChannels
        continuousDataFieldsTrials % cellstr of continuousDataFields to draw data from in .trials
        continuousDataFieldsData % to assign into in trial data
        
        % these are used for streaming mode, where new trials, possibly with new channels are loaded in dynamically
        newR
        newMeta
    end

    methods
        % Constructor : bind to MatUdp R struct and parse channel info
        function td = MatUdpTrialDataInterfaceV10(trials, meta)
            assert(isvector(trials) && ~isempty(trials) && isstruct(trials), 'Trial data must be a struct vector');
            assert(isstruct(meta) && ~isempty(meta) && isvector(meta), 'Meta data must be a vector struct');
            td.trials = makecol(trials);
            td.meta = meta;
            td.nTrials = numel(trials);

            td.timeUnits = trials(1).timeUnits;
        end
    end

    % TrialDataInterface implementation
    methods
        % return a string describing the data set wrapped by this TDI
        function datasetName = getDatasetName(tdi, varargin) %#ok<INUSD>
            datasetName = '';
        end

        % return a scalar struct containing any arbitrary metadata
        function datasetMeta = getDatasetMeta(tdi, varargin) %#ok<INUSD>
            datasetMeta = [];
        end

        % return the number of trials wrapped by this interface
        function nTrials = getTrialCount(tdi, varargin)
            nTrials = numel(tdi.trials);
        end

        % return the name of the time unit used by this interface
        function timeUnitName = getTimeUnitName(tdi, varargin)
            timeUnitName = tdi.timeUnits;
        end

        % Describe the channels present in the dataset
        % channelDescriptors: scalar struct. fields are channel names, values are ChannelDescriptor
        function channelDescriptors = getChannelDescriptors(tdi, varargin)
            channelDescriptors = tdi.getChannelDescriptorsForTrials(tdi.trials, tdi.meta, false, varargin{:});
        end

        function channelDescriptors = getChannelDescriptorsForTrials(tdi, trials, meta, newOnly, varargin)
            % remove special fields
%             maskSpecial = ismember({fieldInfo.name}, ...
%                 {'subject', 'protocol', 'protocolVersion', 'trialId', 'duration', ...
%                  'saveTag', 'tsStartWallclock', 'tsStopWallclock', ...
%                  'tUnits', 'version', 'time'});
            p = inputParser();
            p.addParameter('suppressWarnings', false, @islogical);
            p.parse(varargin{:});
            suppressWarnings = p.Results.suppressWarnings;

            iChannel = 1;
            groups = meta(1).groups;
            signals = meta(1).signals;

            
            % append any missing groups and signals from subsequent trials
            for iT = 2:numel(trials)
                newFlds = setdiff(fieldnames(meta(iT).groups), fieldnames(groups));
                for iN = 1:numel(newFlds)
                    groups.(newFlds{iN}) = meta(iT).groups.(newFlds{iN});
                end
                
                newFlds = setdiff(fieldnames(meta(iT).signals), fieldnames(signals));
                for iN = 1:numel(newFlds)
                    signals.(newFlds{iN}) = meta(iT).signals.(newFlds{iN});
                end
            end
            groupNames = fieldnames(groups);
            nGroups = numel(groupNames);

            nChannels = sum(cellfun(@(name) numel(groups.(name).signalNames), groupNames));

            if newOnly
                prog = ProgressBar(nChannels, 'Checking for new channels');
            else
                prog = ProgressBar(nChannels, 'Inferring channel data characteristics');
            end

            tdi.analogGroupChannelLists = struct();
            
            iSignal = 0;
            for iG = 1:nGroups
                groupName = groupNames{iG};
                group = groups.(groupName);

                % first detect spiking data group
                if endsWith(group.name, 'spikeData') && strcmp(group.type, 'Analog')
                    if ~tdi.includeSpikeData
                        continue;
                    end
                    tokens = regexp(group.name, '(\w*)spikeData', 'tokens');
                    assert(~isempty(tokens));
                    prefix = tokens{1}{1};
                    if isempty(prefix)
                        prefix = 'neural';
                    end
                    timeField = sprintf('%sspikeData_time', prefix);
                    chanField = sprintf('%sspikeChannels', prefix);
                    unitField = sprintf('%sspikeUnits', prefix);
                    waveField = sprintf('%sspikeWaveforms', prefix);

                    if isfield(trials, chanField) && isfield(trials, unitField)
                        % uniquify channel + unit combinations
                        channelUnits = unique([cat(1, trials.(chanField)), cat(1, trials.(unitField))], 'rows'); %#ok<*PROPLC,*PROP>
                        nUnits = size(channelUnits, 1);

                        unitFieldNames = cell(nUnits, 1);
                        waveFieldNames = cell(nUnits, 1);
                        maskKeep = falsevec(nUnits);

                        waveformsClass = ChannelDescriptor.getCellElementClass({trials.(waveField)});

                        prog = ProgressBar(nUnits, 'Adding spike units and waveforms');
                        padToWidth = ceil(log10(nUnits+1));
                        for iU = 1:nUnits
                            prog.update(iU);
                            % use prefix as the array name
                            unitName = sprintf('%s%0*d_%d', prefix, padToWidth, channelUnits(iU, 1), channelUnits(iU, 2));

                            if newOnly && isfield(tdi.trials, unitName)
                                continue;
                            end

                            cd = SpikeChannelDescriptor.build(unitName);
                            unitFieldNames{iU} = unitName;

                            % note that this assumes a homogenous scale factor of 250 (or divide by 0.25 to get uV)
                            if tdi.includeWaveforms && isfield(trials, waveField)
                                wavefield = sprintf('%s_waveforms', unitName);
                                waveFieldNames{iU} = wavefield;
                                waveLims = [-32768 32767];
                                cd = cd.addWaveformsField(wavefield, 'time', tdi.waveformTvec, 'dataClass', waveformsClass, ...
                                    'scaleFromLims', waveLims, 'scaleToLims', waveLims * tdi.waveformScalingFactor);
                            end

                            maskKeep(iU) = true;
                            channelDescriptors(iChannel) = cd; %#ok<AGROW>
                            iChannel = iChannel + 1;
                        end
                        prog.finish();
                        
                        spikeTimeFieldLookup = repmat({timeField}, nnz(maskKeep), 1);
                        spikeUnitFieldLookup = repmat({unitField}, nnz(maskKeep), 1);
                        spikeChannelFieldLookup = repmat({chanField}, nnz(maskKeep), 1);
                        spikeWaveFieldLookup = repmat({waveField}, nnz(maskKeep), 1);
                        
                        tdi.spikeTimeFieldLookup = cat(1, tdi.spikeTimeFieldLookup, spikeTimeFieldLookup);
                        tdi.spikeChannelFieldLookup = cat(1, tdi.spikeChannelFieldLookup, spikeChannelFieldLookup);
                        tdi.spikeUnitFieldLookup = cat(1, tdi.spikeUnitFieldLookup, spikeUnitFieldLookup);
                        tdi.spikeWaveFieldLookup = cat(1, tdi.spikeWaveFieldLookup, spikeWaveFieldLookup);
                        tdi.channelUnits = cat(1, tdi.channelUnits, channelUnits(maskKeep, :));
                        tdi.unitFieldNames = cat(1, tdi.unitFieldNames, unitFieldNames(maskKeep));
                        tdi.waveFieldNames = cat(1, tdi.waveFieldNames, waveFieldNames(maskKeep));
                    end
                    
                    continue;
                end
                
                % process continuous data group
                if endsWith(group.name, 'continuousData') && strcmp(group.type, 'Analog') 
                    tokens = regexp(group.name, '(\w*)continuousData', 'tokens');
                    assert(~isempty(tokens));
                    prefix = tokens{1}{1};
                    contField = sprintf('%scontinuousData', prefix);
                    
                    if isfield(tdi.trials, contField) && newOnly
                        continue;
                    end    
                    
                    if tdi.includeContinuousNeuralData && isfield(trials, contField)
                        % load the continuous data as LFP channels

                        % if the number of continuous channels changes in mid
                        % trial, the field will be a cell array since concatenation
                        % doesn't make sense. just throw away that trial
                        hasValidContinuousData = arrayfun(@(t) ~iscell(t.(contField)) && numel(t.(contField)) > 0, trials);
                        % how many channels?              
                        nCh = max(arrayfun(@(t) size(t.(contField), 1), trials(hasValidContinuousData)));

                        % save this so we can check later
                        tdi.nContinuousNeuralChannels = nCh;

                        % detect data class used in memory
                        continuousNeuralClass = ChannelDescriptor.getCellElementClass({trials.(contField)});

                        % build the continuous_data channel group
                        cdGroup = ContinuousNeuralChannelGroupDescriptor.buildFromTypeArray(tdi.continuousDataType, prefix, ...
                            'uV', 'ms', ...
                            'scaleFromLims', [-32768 32767], ...
                            'scaleToLims', [-8191 8191], ...
                            'dataClass', continuousNeuralClass);
                        channelDescriptors(iChannel) = cdGroup;
                        iChannel = iChannel + 1;

                        % here we build each continuous channel as a shared matrix
                        % column of the field .continuousData, which we'll
                        % transpose to have each channel along a column when we provide the .trials struct
                        prog = ProgressBar(nCh, 'Adding continuous neural channels');
                        padToWidth = max(3, ceil(log10(nCh+1)));
                        for iCh = 1:nCh
                            prog.update(iCh);
                            chName = sprintf('%s_%s%0*d', tdi.continuousDataType, prefix, padToWidth, iCh);
                            channelDescriptors(iChannel) = cdGroup.buildIndividualSubChannel(chName, iCh);
                            iChannel = iChannel + 1;
                        end
                        prog.finish();
                        
                        if isempty(tdi.continuousDataFieldsTrials)
                            tdi.continuousDataFieldsTrials = {contField};
                            tdi.continuousDataFieldsData = {cdGroup.name};
                        else
                            tdi.continuousDataFieldsTrials = cat(1, tdi.continuousDataFieldsTrials, {contField});
                            tdi.continuousDataFieldsData = cat(1, tdi.continuousDataFieldsData, {cdGroup.name});
                        end
                    end
                    
                    continue;
                end

                if strcmpi(group.type, 'event')
                    % for event groups, the meta signalNames field is unreliable unless we take
                    % the union of all signal names
                    names = arrayfun(@(m) m.groups.(groupNames{iG}).signalNames, ...
                        meta, 'UniformOutput', false, 'ErrorHandler', @(varargin) {});
                    group.signalNames = unique(cat(1, names{:}));
                end
                
                % create analog groups for signals sent as a unit, grouped
                % by data class
                if tdi.useAnalogChannelGroups && strcmpi(group.type, 'analog')
                    % first lets mask out non-analog channels
                    signalMask = cellfun(@(sigName) strcmpi(signals.(sigName).type, 'analog') && isempty(strfind(sigName, '_timestampOffsets')), group.signalNames);
                    
                    firstSignal = signals.(group.signalNames{1});
                    timeField = firstSignal.timeFieldName;
                    timeClass = ChannelDescriptor.getCellElementClass({tdi.trials.(timeField)});
                    unitsBySignal = cellfun(@(sigName) signals.(sigName).units, group.signalNames, 'UniformOutput', false);
                    if numel(unique(unitsBySignal)) == 1
                        units = unitsBySignal{1};
                    else
                        units = 'mixed';
                    end
                    
                    % determine data class for each analog group
                    dataClasses = cellfun(@(sigName) ChannelDescriptor.getCellElementClass({tdi.trials.(sigName)}), ...
                        group.signalNames, 'UniformOutput', false); 
                    dataClassUnique = unique(dataClasses(signalMask)); % only consider signals in signalMask
                    nChannelGroups = numel(dataClassUnique);
                    [~, whichChannelGroup] = ismember(dataClasses, dataClassUnique);
                    whichChannelColumn = nan(numel(group.signalNames), 1);
                    whichChannelGroup(~signalMask) = NaN;
                    whichChannelColumn(~signalMask) = NaN;
                    
                    % add one analog channel group for each data class
                    analogGroupCDs = cell(nChannelGroups, 1);
                    for iCG = 1:nChannelGroups
                        if nChannelGroups == 1 || strcmp(dataClassUnique{iCG}, 'double')
                            channelGroupName = groupName;
                        else
                            channelGroupName = sprintf('%s_%s', groupName, dataClassUnique{iCG});
                        end
                        analogGroupCDs{iCG} = AnalogChannelGroupDescriptor.buildAnalogGroup(...
                            channelGroupName, timeField, units, tdi.timeUnits, ...
                            'dataClass', dataClassUnique{iCG}, 'timeClass', timeClass);
                        channelDescriptors(iChannel) = analogGroupCDs{iCG};
                        iChannel = iChannel + 1;
                        
                        % determine which channels belong in group
                        mask = false(numel(group.signalNames), 1);
                        for iS = 1:numel(group.signalNames)
                            mask(iS) = signalMask(iS) && whichChannelGroup(iS) == iCG;
                        end
                        tdi.analogGroupChannelLists.(channelGroupName) = MatUdp.Utils.makecol(group.signalNames(mask));
                        
                        % and stick this subset of columns in order into
                        % the analog group
                        whichChannelColumn(mask) = 1:nnz(mask);
                    end
                    
                    useAnalogGroup = true;
                else
                    useAnalogGroup = false;
                end

                nSignals = numel(group.signalNames);
                for iS = 1:nSignals
                    iSignal = iSignal + 1;
                    name = group.signalNames{iS};
                    prog.update(iSignal, 'Inferring channel characteristics: %s', name);

                    % this is a bug with meta building in the data logger
                    % as of version 6. this field is used internally to add
                    % offsets to the analog signal, but it won't actually
                    % be present in the trials struct
                    if strcmpi(group.type, 'analog') && ~isempty(strfind(name, '_timestampOffsets'))
                        continue;
                    end

                    if ~strcmpi(group.type, 'event')
                        % event fields won't have an entry in signals table
                        if ~isfield(signals, name)
                            if ~suppressWarnings
                                warning('Could not find signal %s', name);
                            end
                            continue;
                        end
                        signalInfo = signals.(name);
                    else
                        signalInfo = struct('type', 'Event', 'units', tdi.timeUnits);
                    end
                    dataFieldMain = name;

                    % skip this field if already processed
                    if newOnly && isfield(tdi.trials, dataFieldMain)
                        continue;
                    end

                    dataCell = {trials.(dataFieldMain)};
                
                    % fix bug with 'enum' units
                    if strcmp(signalInfo.units, 'enum')
                        signalInfo.units = '';    
                    end
                    
                    if strcmpi(signalInfo.type, 'Analog') && strcmpi(group.type, 'Param')
                        % signal can't be analog if group is param
                        signalInfo.type = 'Param';
                    end
                    
                    switch(lower(signalInfo.type))
                        case 'analog'
                            timeField = signalInfo.timeFieldName;
                            
                            if ~useAnalogGroup
                                cd = AnalogChannelDescriptor.buildVectorAnalog(name, timeField, signalInfo.units, tdi.timeUnits);
                            else
                                cd = analogGroupCDs{whichChannelGroup(iS)}.buildIndividualSubChannel(name, whichChannelColumn(iS));
                            end
                            timeCell = {tdi.trials.(timeField)};
                            cd = cd.inferAttributesFromData(dataCell, timeCell);
                        case 'event'
                            cd = EventChannelDescriptor.buildMultipleEvent(name, tdi.timeUnits);
                            cd = cd.inferAttributesFromData(dataCell);
                        case 'param'
                            cd = ParamChannelDescriptor.buildFromValues(name, dataCell, signalInfo.units);
                        otherwise
                            error('Unknown field type %s for channel %s', signalType, name);
                    end

                    cd.groupName = group.name;

                    % store original field name to ease lookup in getDataForChannel()
                    cd.meta.originalField = dataFieldMain;

                    channelDescriptors(iChannel) = cd;

                    iChannel = iChannel + 1;
                end
            end
            prog.finish();

            if ~newOnly
                % now detect units
                channelDescriptors(iChannel) = ParamChannelDescriptor.buildBooleanParam('hasNeuralData');
            end
            
            if ~exist('channelDescriptors', 'var')
                channelDescriptors = [];
            end
        end

        % return a nTrials x 1 struct with all the data for each specified channel
        % in channelNames cellstr array
        %
        % the fields of this struct are determined as:
        % .channelName for the primary data associated with that channel
        % .channelName_extraData for extra data fields associated with that channel
        %   e.g. for an AnalogChannel, .channelName_time
        %   e.g. for an EventChannel, .channelName_tags
        %
        % channelNames may include any of the channels returned by getChannelDescriptors()
        %   as well as any of the following "special" channels used by TrialData:
        %
        %   trialId : a unique numeric identifier for this trial
        %   trialIdStr : a unique string for describing this trial
        %   subject : string, subject from whom the data were collected
        %   protocol : string, protocol in which the data were collected
        %   protocolVersion: numeric version identifier for that protocol
        %   saveTag : a numeric identifier for the containing block of trials
        %   duration : time length of each trial in tUnits
        %   timeStartWallclock : wallclock datenum indicating when this trial began
        %
        function channelData = getChannelData(tdi, channelDescriptors, varargin)
            channelData = tdi.getChannelDataForTrials(tdi.trials, channelDescriptors, varargin{:});
        end

        function channelData = getChannelDataForTrials(tdi, trials, channelDescriptors, varargin) %#ok<INUSD>
            %debug('Converting / repairing channel data...\n');
            if tdi.useAnalogChannelGroups
                analogGroups = fieldnames(tdi.analogGroupChannelLists);
                analogChannelsInGroups = cellfun(@(grp) tdi.analogGroupChannelLists.(grp), analogGroups, 'UniformOutput', false);
                analogChannelsInGroups = cat(1, analogChannelsInGroups{:});
            else
                analogChannelsInGroups = {};
            end
            
            fieldsToRemove = cat(1, analogChannelsInGroups, {'spikeUnits'; 'spikeChannels'; 'spikeData_time'; ...
                'spikeWaveforms'; 'continuousData'});
            channelData = rmfield(trials, intersect(fieldnames(trials), fieldsToRemove));

            % rename special channels
            for i = 1:numel(channelData)
                channelData(i).timeStartWallclock = channelData(i).wallclockStart;
                channelData(i).TrialStart = 0;
                channelData(i).TrialEnd = channelData(i).duration;
            end
            
            % combine analog channel groups
            for iG = 1:numel(analogGroups)
                groupName = analogGroups{iG};
                signalNames = tdi.analogGroupChannelLists.(groupName);
                
                % concatenate as columns into combined field
                prog = ProgressBar(numel(channelData), 'Combining analog group %s', groupName);
                for iT = 1:numel(channelData)
                    
                    dataBySignal = cell(numel(signalNames), 1);
                    nSamples = nan(numel(signalNames), 1);
                    for iS = 1:numel(signalNames)
                        dataBySignal{iS} = trials(iT).(signalNames{iS});
                        nSamples(iS) = numel(dataBySignal{iS});
                    end
                    nSamplesMax = max(nSamples);
                    assert(all(nSamples == nSamplesMax | nSamples == 0), 'Analog channel group signals have mismatched lengths');
                    
                    if nSamplesMax > 0
                        if any(nSamples == 0)
                            nonEmpty = dataBySignal{find(nSamples == nSamplesMax, 1)};
                            empty = nan(nSamplesMax, 1, 'like', nonEmpty);
                            dataBySignal(nSamples == 0) = empty;
                        end
                        channelData(iT).(groupName) = cat(2, dataBySignal{:});
                    else
                        channelData(iT).(groupName) = [];
                    end
                    
                    prog.update(iT);
                end
                prog.finish();
            end
                    
            % add spike data
            if tdi.includeSpikeData
                nUnits = size(tdi.channelUnits, 1);
                prog = ProgressBar(numel(channelData), 'Extracting spike data for trials');
                for iT = 1:numel(channelData)
                    prog.update(iT);
                    channelData(iT).hasNeuralData = false;
                                        
                    % mark as zero if no spikes at all occurred on this trial,
                    % USE CAUTION IF FIRING RATES ARE VERY LOW!!
                    
                    for iU = 1:nUnits
                        mask = trials(iT).(tdi.spikeChannelFieldLookup{iU}) == tdi.channelUnits(iU, 1) & ...
                            trials(iT).(tdi.spikeUnitFieldLookup{iU}) == tdi.channelUnits(iU, 2);

                        if any(mask)
                            channelData(iT).hasNeuralData = true;
                        end
                        
                        fld = tdi.unitFieldNames{iU};
                        channelData(iT).(fld) = trials(iT).(tdi.spikeTimeFieldLookup{iU})(mask);
                        if tdi.includeWaveforms
                            wfld = tdi.waveFieldNames{iU};
                            channelData(iT).(wfld) = trials(iT).(tdi.spikeWaveFieldLookup{iU})(:, mask)';
                        end
                    end
                end
                prog.finish();
            end

            % copy continuous data fields
            if tdi.includeContinuousNeuralData 
                for iG = 1:numel(tdi.continuousDataFieldsTrials)
                    fld = tdi.continuousDataFieldsTrials{iG};
                    fldOut = tdi.continuousDataFieldsData{iG};
                    % determine memory class
                    memClass = 'single';
                    for iT = 1:numel(trials)
                        v = trials(iT).(fld);
                        if ~isempty(v) && ~iscell(v)
                            memClass = class(v);
                            break;
                        end
                    end

                    % build the nan/zeros fn in case we need to reallocate data
                    if ismember(memClass, {'single', 'double'})
                        allocFn = @(varargin) nan(varargin{:}, memClass);
                    else
                        allocFn = @(varargin) zeros(varargin{:}, memClass);
                    end

                    timeFld = sprintf('%s_time', fld);
                    timeFldOut = sprintf('%s_time', fldOut);
                        
                    assert(isfield(trials, timeFld), 'Missing continuous neural data time field %s', timeFld);
                    prog = ProgressBar(numel(channelData), 'Extracting continuous neural data for trials');
                    maskChangedTrialCount = falsevec(numel(channelData));
                    for iT = 1:numel(channelData)
                        prog.update(iT);
                        % if continuousData is a cell, the number of
                        % channels changed mid trial and we discard
                        if iscell(trials(iT).(fld))
                            maskChangedTrialCount(iT) = true;
                            channelData(iT).(fldOut) = allocFn(0, tdi.nContinuousNeuralChannels);

                            continue;
                        end
                        
                        channelData(iT).(timeFldOut) = trials(iT).(timeFld);

                        nChThisTrial = size(trials(iT).continuousData, 1);
                        nSamples = size(trials(iT).continuousData, 2);
                        if nChThisTrial ~= tdi.nContinuousNeuralChannels
                            maskChangedTrialCount(iT) = true;
                            channelData(iT).(fldOut) = allocFn(nSamples, tdi.nContinuousNeuralChannels);
                            channelData(iT).(fldOut)(:, 1:nChThisTrial) = trials(iT).(fld)';
                        else
                            % transpose so that each channel is along a column, not
                            % a row. 
                            trials(iT).(fld) = trials(iT).(fld)';
                            channelData(iT).(fldOut) = trials(iT).(fld);
                        end
                        
                    end
                    prog.finish();

                    if any(maskChangedTrialCount)
                        warning('%d Trials had different number of continuous neural channels, some trials have %d', nnz(maskChangedTrialCount), tdi.nContinuousNeuralChannels);
                    end
                end
            end
        end
    end

    % Support for appending new trials with new channels on the fly
    methods
        % add these trials to the pending buffer
        function receiveNewTrials(tdi, R, meta)
            if isempty(tdi.newR)
                tdi.newR = R;
                tdi.newMeta = meta;
            else
                tdi.newR = TrialDataUtilities.Data.structcat(1, tdi.newR, R);
                tdi.newMeta = TrialDataUtilities.Data.structcat(1, tdi.newMeta, meta);
            end
        end

        % The equivalent of getChannelDescriptors, except only new channels that do not exist
        % need be added
        function channelDescriptors = getNewChannelDescriptors(tdi, varargin)
            channelDescriptors = tdi.getChannelDescriptorsForTrials(tdi.newR, tdi.newMeta, true);
        end

        function channelData = getNewChannelData(tdi, channelDescriptors, varargin)
            channelData = tdi.getChannelDataForTrials(tdi.newR, channelDescriptors, varargin{:});
        end

        function markNewChannelDataAsReceived(tdi)
            tdi.trials = TrialDataUtilities.Data.structcat(1, tdi.trials, tdi.newR);
            tdi.meta = TrialDataUtilities.Data.structcat(1, tdi.meta, tdi.newMeta);
            tdi.newR = [];
            tdi.newMeta = [];
        end
    end
end
