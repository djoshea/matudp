classdef ScreenObject < handle & matlab.mixin.Heterogeneous
    % Classes derived from ScreenObject represent persistent objects on screen.
    % Since Psychtoolbox requires everything to be redrawn each frame, ScreenObjects
    % feature a .draw() method which will use the provided ScreenDraw handle to draw
    % itself to the screen on each frame. It also exposes a .update() method which will
    % update the internal properties of the object on each frame

    properties
        zOrder = 0; % higher zOrder objects appear on top of lower zOrder
        visible = true; % .draw() is called on each frame if .visible
    end

    methods
        function show(obj)
            obj.visible = true;
        end

        function hide(obj)
            obj.visible = false;
        end

    end

    methods(Abstract)
        % a one-line string used to concisely describe this object
        str = describe(obj);

        % update the object, mgr is a ScreenObjectManager
        % can be used to add or remove objects from the manager as well
        update(obj, mgr, sd)

        % use the ScreenDraw object to draw this object onto the screen
        draw(obj, sd);
    end

end
