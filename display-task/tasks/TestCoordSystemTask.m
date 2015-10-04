classdef TestCoordSystemTask < DisplayTask 

    properties 
        gridMinor = 10;
        gridMajor = 100;
    end

    methods
        function task = TestCoordSystemTask()
            task.name = 'TestCoordSystemTask';
        end

        function initialize(task)
            
        end

        function update(task, data) %#ok<*INUSD>
            sd = task.dc.sd;
                        
            % draw minor grid
            sd.penWidth = 0.5;
            sd.penColor = [0.3 0.3 0.3];
            sd.drawGrid(task.gridMinor, 0, 0);
            
            % draw major grid
            sd.penWidth = 0.75;
            sd.penColor = [0.5 0.5 0.5];
            sd.drawGrid(task.gridMajor, 0, 0);
            
            % draw origin axes
            sd.penWidth = 1.5;
            sd.penColor = [102 255 204]/255;
            sd.drawLine(0, 0, task.gridMajor, 0);
            sd.drawLine(0, 0, 0, task.gridMajor);
        end

        function runCommand(task, command, data)
            
        end
    end
end
