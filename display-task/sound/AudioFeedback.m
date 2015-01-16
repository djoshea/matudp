classdef AudioFeedback < handle
% Loads wav files and plays sounds via PsychPortAudio
    
    properties
        waveData % containers.Map : key -> wave signal
        bufferMap % containers.Map : key -> PsychPortAudio buffer with each sound
        freq % sampling frequency for ALL files
        nChannels % channel count for ALL files
        paHandle % PsychPortAudio handle
    end

    properties(Dependent)
        soundKeys % loaded sound keys
    end
       
    methods % Generic functionality
        function r = AudioFeedback()
            r.waveData = containers.Map('KeyType', 'char', 'ValueType', 'any'); 
            r.bufferMap = containers.Map('KeyType', 'char', 'ValueType', 'any'); 

            r.loadDefaultSounds();

            % Perform basic initialization of the sound driver:
            InitializePsychSound;
            
            % Open the default audio device [], with default mode [] (==Only playback),
            % and a required latencyclass of zero 0 == no low-latency mode, as well as
            % a frequency of freq and nrchannels sound channels.
            % This returns a handle to the audio device:
            try
                % Try with the frequency we wanted:
                r.paHandle = PsychPortAudio('Open', [], [], 2, r.freq, r.nChannels);
            catch
                % Failed. Retry with default frequency as suggested by device:
                fprintf('\nCould not open device at wanted playback frequency of %i Hz. Will retry with device default frequency.\n', freq);
                fprintf('Sound may sound a bit out of tune, ...\n\n');

                psychlasterror('reset');
                r.paHandle = PsychPortAudio('Open', [], [], 0, [], r.nChannels);
            end
        end 

        function delete(r)
            try
                PsychPortAudio('Close', r.paHandle);
                for i = 1:length(r.soundKeys)
                    key = r.soundKeys{i};
                    buffer = r.bufferMap(key);
                    PsychPortAudio('DeleteBuffer', buffer);
                end
            catch
            end
        end

        function onsetTimestamp = play(r, key)
            % onsetTimestamp = .play(key)
            % play the sound file loaded with loadWav(key, ...)
            assert(r.bufferMap.isKey(key), 'Sound with key %s not found', key);
            
            % Retrieve the buffer
            buffer = r.bufferMap(key);
            
            % Fill the audio playback buffer with the audio data 'wavedata':
            PsychPortAudio('FillBuffer', r.paHandle, buffer);

            % Start audio playback for 'repetitions' repetitions of the sound data,
            % start it immediately (0) and wait for the playback to start, return onset
            % timestamp.
            repetitions = 1;
            onsetTimestamp = PsychPortAudio('Start', r.paHandle, repetitions, 0, 0);
        end

        function loadWav(r, key, fname)
            % loadWav(key, fname)
            % load from wav file fname from filesystem using wavread, store it in
            % this class's wav database under key
            % call .play(key) to play

            assert(~ismember(key, r.soundKeys), 'Key %s already loaded', key);

            [wav freq] = wavread(fname);
            wav = wav';
            nChannels = size(wav, 1);

            % check or store the sampling frequency and channel count
            if isempty(r.freq)
                r.freq = freq;
            else
                assert(r.freq == freq, 'All sampling frequencies for loaded wav files must match');
            end
            if isempty(r.nChannels)
                r.nChannels = nChannels;
            else
                assert(r.nChannels == nChannels, 'All channel counts for loaded wav files must match');
            end

            % store wave data in containers.Map
            r.waveData(key) = wav;

            % create a buffer for this wavedata
            buffer = PsychPortAudio('CreateBuffer', r.paHandle, wav);

            r.bufferMap(key) = buffer;
        end
            
        function soundKeys = get.soundKeys(r)
            soundKeys = r.waveData.keys;
        end

        function playTonePulseTrain(r, toneHz, msOn, msOff, reps)
            if nargin < 2
                toneHz = 1000;
            end
            if nargin < 3 
                msOn = 1000;
            end
            if nargin < 4
                msOff = 0;
            end
            if nargin < 5
                reps = 1;
            end

            if reps == 1
                T = msOn/1000;
            else
                T = (reps*msOn+(reps-1)*msOff)/1000;
            end
            tvec = 0:1/r.freq:T;
            
            v = zeros(size(tvec));
            tOffset = 0;
            for i = 1:reps
                tOffset = (i-1)*(msOn+msOff)/1000;
                mask = tvec >= tOffset & tvec < tOffset + msOn/1000;
                v(mask) = sin(2*pi*toneHz*(tvec(mask) - tOffset));
            end

            %PyschPortAudio('Stop', r.paHandle, 0, 0);
            PsychPortAudio('FillBuffer', r.paHandle, v);
            PsychPortAudio('Start', r.paHandle, 1, 0, 0);
        end

    end

    methods % specific file loading
        function loadDefaultSounds(r)
            % add more calls to loadWav(keyString, filename) for more sounds
            % you can then play them via r.play(keyString)

            filePath = fileparts(mfilename('fullpath')); % search relative to this file's location
            r.loadWav('failure', fullfile(filePath,'failure.wav'));
            r.loadWav('success', fullfile(filePath,'success.wav'));
            r.loadWav('buzz', fullfile(filePath,'buzz.wav'));
        end

        function playFailure(r)
            r.play('failure');
        end
        
        function playSuccess(r)
            r.play('success');
        end

        function playBuzz(r)
            r.play('buzz');
        end
    end
end
