classdef MatUdpTrialDataInterfaceV8 < TrialDataInterface
    % adding special handling of analog channel groups
    
    properties
        includeSpikeData = true;
        includeWaveforms = true;
        includeContinuousNeuralData = true;

        waveformTvec = (-10:37)' / 30; % 48 sample waveform
    end

    % like V3, but uses millisecond timestamps as doubles
    properties(SetAccess=protected)
        trials % original struct array over trials
        meta % meta data merged over all trials
        nTrials
        timeUnits

        channelUnits % col 1 is channel, col 2 is units
        unitFieldNames
        waveFieldNames

        nContinuousNeuralChannels

        % these are used for streaming mode, where new trials, possibly with new channels are loaded in dynamically
        newR
        newMeta
    end

    methods
        % Constructor : bind to MatUdp R struct and parse channel info
        function td = MatUdpTrialDataInterfaceV8(trials, meta)
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
            groupNames = fieldnames(groups);
            nGroups = numel(groupNames);

            nChannels = sum(cellfun(@(name) numel(groups.(name).signalNames), groupNames));

            if newOnly
                prog = ProgressBar(nChannels, 'Checking for new channels');
            else
                prog = ProgressBar(nChannels, 'Inferring channel data characteristics');
            end

            iSignal = 0;
            for iG = 1:nGroups
                group = groups.(groupNames{iG});

                if ismember(group.name, {'spikeData', 'continuousData'})
                    continue; % handled specially below
                end

                if strcmpi(group.type, 'event')
                    % for event groups, the meta signalNames field is unreliable unless we take
                    % the union of all signal names
                    names = arrayfun(@(m) m.groups.(groupNames{iG}).signalNames, ...
                        meta, 'UniformOutput', false, 'ErrorHandler', @(varargin) {});
                    group.signalNames = unique(cat(1, names{:}));
                end

                nSignals = numel(group.signalNames);
                for iS = 1:nSignals
                    iSignal = iSignal + 1;
                    name = group.signalNames{iS};
                    prog.update(iSignal, 'Inferrring channel characteristics: %s', name);

                    % this is a bug with meta building in the data logger
                    % as of version 6. this field is used internally to add
                    % offsets to the analog signal, but it won't actually
                    % be present in the trials struct
                    if strcmpi(group.type, 'analog') && ~isempty(strfind(name, '_timestampOffsets')) %#ok<STREMP>
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
                            cd = AnalogChannelDescriptor.buildVectorAnalog(name, timeField, signalInfo.units, tdi.timeUnits);
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

                    channelDescriptors(iChannel) = cd; %#ok<AGROW>

                    iChannel = iChannel + 1;
                end
            end
            prog.finish();

            if ~newOnly
                % now detect units
                channelDescriptors(iChannel) = ParamChannelDescriptor.buildBooleanParam('hasNeuralData');
            end
            
            if isfield(trials, 'spikeChannels') && isfield(trials, 'spikeUnits')
                channelUnits = unique([cat(1, trials.spikeChannels), cat(1, trials.spikeUnits)], 'rows'); %#ok<*PROPLC,*PROP>
                nUnits = size(channelUnits, 1);

                unitFieldNames = cell(nUnits, 1);
                waveFieldNames = cell(nUnits, 1);
                maskKeep = falsevec(nUnits);
                
                waveformsClass = ChannelDescriptor.getCellElementClass({trials.spikeWaveforms});

                prog = ProgressBar(nUnits, 'Adding spike units and waveforms');
                for iU = 1:nUnits
                    prog.update(iU);
                    unitName = sprintf('unit%d_%d', channelUnits(iU, 1), channelUnits(iU, 2));

                    if newOnly && isfield(tdi.trials, unitName)
                        continue;
                    end

                    cd = SpikeChannelDescriptor.build(unitName);
                    unitFieldNames{iU} = unitName;

                    % note that this assumes a homogenous scale factor of 250 (or divide by 0.25 to get uV)
                    if tdi.includeWaveforms && isfield(trials, 'spikeWaveforms')
                        wavefield = sprintf('%s_waveforms', unitName);
                        waveFieldNames{iU} = wavefield;
                        cd = cd.addWaveformsField(wavefield, 'time', tdi.waveformTvec, 'dataClass', waveformsClass); %, ...
%                             'scaleFromLims', [-32768 32767], 'scaleToLims', [-32768 32767]);
                    end

                    maskKeep(iU) = true;
                    channelDescriptors(iChannel) = cd;
                    iChannel = iChannel + 1;
                end
                prog.finish();

                if newOnly
                    tdi.channelUnits = cat(1, tdi.channelUnits, channelUnits(maskKeep, :));
                    tdi.unitFieldNames = cat(1, tdi.unitFieldNames, unitFieldNames(maskKeep));
                    tdi.waveFieldNames = cat(1, tdi.waveFieldNames, waveFieldNames(maskKeep));
                else
                    tdi.channelUnits = channelUnits;
                    tdi.unitFieldNames = unitFieldNames;
                    tdi.waveFieldNames = waveFieldNames;
                end
            else
                tdi.unitFieldNames = {};
                tdi.waveFieldNames = {};
                tdi.channelUnits = {};
            end

            if isfield(trials, 'continuousData') && ...
                    tdi.includeContinuousNeuralData
                % load the continuous data as LFP channels

                % if the number of continuous channels changes in mid
                % trial, the field will be a cell array since concatenation
                % doesn't make sense. just throw away that trial
                hasValidContinuousData = arrayfun(@(t) ~iscell(t.continuousData) && numel(t.continuousData) > 0, trials);
                % how many channels?              
                nCh = max(arrayfun(@(t) size(t.continuousData, 1), trials(hasValidContinuousData)));

                % save this so we can check later
                tdi.nContinuousNeuralChannels = nCh;
                
                % detect data class used in memory
                continuousNeuralClass = ChannelDescriptor.getCellElementClass({trials.continuousData});

                % build the continuous_data channel group
                cdGroup = ContinuousNeuralChannelGroupDescriptor.buildAnalogGroup('continuousData', 'continuousData_time', 'uV', 'ms', ...
                    'scaleFromLims', [-32768 32767], ...
                    'scaleToLims', [-8191 8191], ...
                    'dataClass', continuousNeuralClass);
                channelDescriptors(iChannel) = cdGroup;
                iChannel = iChannel + 1;
                
                % here we build each continuous channel as a shared matrix
                % column of the field .continuousData, which we'll
                % transpose to have each channel along a column when we provide the .trials struct
                prog = ProgressBar(nCh, 'Adding continuous neural channels');
                for iCh = 1:nCh
                    prog.update(iCh);
                    chName = sprintf('continuous%03d', iCh);
                    channelDescriptors(iChannel) = cdGroup.buildIndividualSubChannel(chName, iCh);
                    iChannel = iChannel + 1;
                end
                prog.finish();
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
            fieldsToRemove = {'spikeUnits', 'spikeChannels', 'spikeData_time', ...
                'spikeWaveforms', 'continuousData'};
            channelData = rmfield(trials, intersect(fieldnames(trials), fieldsToRemove));

            % rename special channels
            for i = 1:numel(channelData)
                channelData(i).timeStartWallclock = channelData(i).wallclockStart;
                channelData(i).TrialStart = 0;
                channelData(i).TrialEnd = channelData(i).duration;
            end

            % add spike data
            if tdi.includeSpikeData
                nUnits = size(tdi.channelUnits, 1);
                prog = ProgressBar(numel(channelData), 'Extracting spike data for trials');
                for iT = 1:numel(channelData)
                    prog.update(iT);
                    % mark as zero if no spikes at all occurred on this trial,
                    % USE CAUTION IF FIRING RATES ARE VERY LOW!!
                    channelData(iT).hasNeuralData = nUnits > 0 && ~isempty(trials(iT).spikeChannels);
                    for iU = 1:nUnits
                        mask = trials(iT).spikeChannels == tdi.channelUnits(iU, 1) & ...
                            trials(iT).spikeUnits == tdi.channelUnits(iU, 2);

                        fld = tdi.unitFieldNames{iU};
                        channelData(iT).(fld) = trials(iT).spikeData_time(mask);
                        if tdi.includeWaveforms
                            wfld = tdi.waveFieldNames{iU};
                            channelData(iT).(wfld) = trials(iT).spikeWaveforms(:, mask)' / 4; % over 4 is because I forgot to normalize the voltages
                        end
                    end
                end
                prog.finish();
            end

            % add continuous datas
            if tdi.includeContinuousNeuralData && isfield(trials, 'continuousData')
                
                % determine memory class
                memClass = 'single';
                for iT = 1:numel(trials)
                    v = trials(iT).continuousData;
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
                
                assert(isfield(trials, 'continuousData_time'), 'Missing continuous neural data time field continuousData_time');
                prog = ProgressBar(numel(channelData), 'Extracting continuous neural data for trials');
                maskChangedTrialCount = falsevec(numel(channelData));
                for iT = 1:numel(channelData)
                    prog.update(iT);
                    % if continuousData is a cell, the number of
                    % trials changed mid trial and we discard
                    if iscell(trials(iT).continuousData)
                        maskChangedTrialCount(iT) = true;
                        channelData(iT).continuousData = allocFn(0, tdi.nContinuousNeuralChannels);
                        
                        continue;
                    end
                        
                    nChThisTrial = size(trials(iT).continuousData, 1);
                    nSamples = size(trials(iT).continuousData, 2);
                    if nChThisTrial ~= tdi.nContinuousNeuralChannels
                        maskChangedTrialCount(iT) = true;
                        channelData(iT).continuousData = allocFn(nSamples, tdi.nContinuousNeuralChannels);
                        channelData(iT).continuousData(:, 1:nChThisTrial) = trials(iT).continuousData';
                    else
                        % transpose so that each channel is along a column, not
                        % a row. 
                        trials(iT).continuousData = trials(iT).continuousData';
                        channelData(iT).continuousData = trials(iT).continuousData;
                    end
                end
                prog.finish();
                
                if any(maskChangedTrialCount)
                    warning('%d Trials had different number of continuous neural channels, some trials have %d', nnz(maskChangedTrialCount), tdi.nContinuousNeuralChannels);
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
