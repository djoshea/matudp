classdef ScreenMessage < ScreenObject

    properties
        x1
        y1
        message

        fontFace = 'Ubuntu Mono' % use a monospaced font to do wrapping well
        fontSize = 24;
        fontStyle = 0;
        color
    end

    methods
        function r = ScreenMessage(x1, y1)
            r.x1 = x1;
            r.y1 = y1;
        end

        function str = describe(r)
            str = sprintf('ScreenMessage : (%g, %g)', r.x1, r.y1);
        end

        function update(r, mgr, sd)

        end

        function draw(r, sd)
            if isempty(r.message)
                return;
            end

            %state = sd.saveState(); 
            %sd.fontFace = r.fontFace;
            %sd.fontStyle = r.fontStyle;
            %sd.fontSize = r.fontSize;

            if isempty(r.color)
                r.color = sd.white;
            end
            sd.penColor = r.color;
            sd.drawText(r.message, r.x1, r.y1);

            %sd.restoreState(state);
        end

    end

end

