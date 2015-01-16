classdef TestCursorTask < DisplayTask 

    properties 
        cursor
        commandMap % containers.Map : command string -> method handle
    end

    methods
        function task = TestCursorTask()
            task.name = 'TestCursor';
            task.buildCommandMap();
        end

        function initialize(task)
            task.cursor = Cursor();
            task.cursor.hide();
            task.dc.mgr.add(task.cursor);
        end

        function update(task)
        end

        function cleanup(task)
        end

        function runCommand(task, command, data)
            if task.commandMap.isKey(command)
                fprintf('Running taskCommand %s\n', command);
                fn = task.commandMap(command);
                fn(data);
            else
                fprintf('Unrecognized taskCommand %s\n', command);
            end
        end

        function buildCommandMap(task)
            map = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

        function updateHand(task, handInfo)
            task.cursor.xc = handInfo.handPosition(1);
            task.cursor.yc = handInfo.handPosition(2);
            task.cursor.touching = handInfo.handTouching;
            task.cursor.seen = handInfo.handSeen;
            task.cursor.show();
        end
    end
end
