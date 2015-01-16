classdef TestMouseTask < DisplayTask 

    properties 
        cursor
    end

    methods
        function task = TestMouseTask()
            task.name = 'TestMouse';
        end

        function initialize(task)
            task.cursor = Cursor();
            task.cursor.hide();
            task.dc.mgr.add(task.cursor);
        end

        function update(task, data) %#ok<*INUSD>
            [task.cursor.xc, task.cursor.yc, buttons] = task.dc.sd.getMouse();
            task.cursor.touching = any(buttons);
            task.cursor.seen = true;
            task.cursor.show();
            
            sd = task.dc.sd;
            
            % draw 10 mm grid
            sd.penWidth = 0.5;
            sd.penColor = [0.3 0.3 0.3];
            sd.drawGrid(10, 0, 0);
            
            % draw 100 mm grid
            sd.penWidth = 0.75;
            sd.penColor = [0.5 0.5 0.5];
            sd.drawGrid(100, 0, 0);
            
            % draw 100 mm axes
            sd.penWidth = 1.5;
            sd.penColor = [102 255 204]/255;
            sd.drawLine(0, 0, 100, 0);
            sd.drawLine(0, 0, 0, 100);
        end

        function runCommand(task, command, data) %#ok<INUSL>
            fprintf('Unrecognized taskCommand %s\n', command);
        end
    end
end
