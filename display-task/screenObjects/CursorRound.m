classdef CursorRound < Circle

    properties
        size;
        sizeTouching = 10;
        penWidthTouching = 1;

        sizeNotTouching = 10;

        touching = 0;
        seen = 0;
        lastNotSeen = [];
        threshNotSeenRecently = 0.5; % time in seconds that must elapse
    end

    properties(Dependent)
        notSeenRecently
    end

    methods
        function obj = CursorRound()
            size = 10;
            obj = obj@Circle(0,0,size);
            obj.size = 10;

            obj.borderColor = 0;
            obj.borderWidth = obj.penWidthTouching;
        end

        function set.seen(r, val)
            r.seen = val;

            if ~r.seen
                r.lastNotSeen = clock();
            end
        end

        function tf = get.notSeenRecently(r)
            if isempty(r.lastNotSeen)
                tf = false;
            else
                tf = etime(clock, r.lastNotSeen) < r.threshNotSeenRecently; 
            end
        end

        function str = describe(r)
            if r.touching
                touchStr = 'touching';
            else
                touchStr = 'notTouching';
            end

            if r.seen
                if r.notSeenRecently
                    seenStr = 'seen but missing recently';
                else
                    seenStr = 'seen';
                end
            else
                seenStr = 'not seen';
            end

            str = sprintf('(%d, %d) %s, %s', ...
                r.xc, r.yc, touchStr, seenStr);
        end

        function update(r, mgr, sd)
            % nothing here
        end

        function draw(r, sd)
            r.fill = true;
            r.borderWidth = r.penWidthTouching;
            if r.touching
                r.radius = r.sizeTouching / 2;
            else
                r.radius = r.sizeNotTouching / 2;
            end
            
            if r.seen
                r.fillColor = sd.white;
                r.borderColor = sd.black;
            else
                r.fillColor = sd.red;
                r.borderColor = sd.red;
            end
            draw@Circle(r, sd);
        end
       
    end

end

