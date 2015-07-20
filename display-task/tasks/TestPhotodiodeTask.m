classdef TestPhotodiodeTask < DisplayTask
    
    properties
        fixLocation = true;
        photobox
        counter = 0;
    end
    
    methods
        function task = TestPhotodiodeTask()
            task.name = 'TestPhotodiode';
        end
        
        function initialize(task)
            KbName('UnifyKeyNames');
            task.photobox = Photobox(task.dc.cxt);
            task.photobox.hide();
            task.dc.mgr.add(task.photobox);
        end
        
        function update(task, data) %#ok<*INUSD>
            % use mouse to position photobox position
            
            if ~task.fixLocation
                [task.photobox.xc, task.photobox.yc] = task.dc.sd.getMouse();
            end
            
            task.photobox.show();

            task.counter = task.counter + 1;
            if mod(task.counter, 60) <= 30
                task.photobox.on();
            else
                task.photobox.off();
            end
            
%             task.photobox.off();
            
            [~, ~, keyCodes] = KbCheck;
            if keyCodes(KbName('p'))
                % print cursor location
                fprintf('Current Photobox: x,y = (%g, %g), r = %g\n', ...
                    task.photobox.xc, task.photobox.yc, task.photobox.radius);
                
                %             elseif keyCodes(KbName('=+'))
                %                 % increase radius
                %                 if keyCodes(KbName('LeftShift'))
                %                     task.photobox.radius = task.photobox.radius + 10;
                %                 else
                %                     task.photobox.radius = task.photobox.radius + 1;
                %                 end
                %
                %             elseif keyCodes(KbName('-_'))
                %                 % decrease radius
                %                 if keyCodes(KbName('LeftShift'))
                %                     task.photobox.radius = task.photobox.radius + 10;
                %                 else
                %                     task.photobox.radius = task.photobox.radius + 1;
                %                 end
                %             end
            end
        end
        
        function runCommand(task, command, data) %#ok<INUSL>
            fprintf('Unrecognized taskCommand %s\n', command);
        end
    end
end

