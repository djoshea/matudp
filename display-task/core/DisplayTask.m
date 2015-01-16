classdef DisplayTask < handle

    properties
        name % for debug purposes
        dc % display controller, will be assigned before initialize is called
        version = NaN;
    end

    methods
        function task = DisplayTask()
            task.name = 'DisplayTask';
        end

        function initialize(task) %#ok<*MANU>
            % called when task becomes active
        end

        function update(task, data) %#ok<*INUSD>
            % called once each frame
        end

        function cleanup(task)
            % called when task is becoming inactive
        end

        function runCommand(task, command, dataMap)
            % called when a tagged packet <taskCommand>command</taskCommand> comes in
        end
    end
end
