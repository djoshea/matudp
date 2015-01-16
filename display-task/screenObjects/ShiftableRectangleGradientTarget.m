classdef ShiftableRectangleGradientTarget < RectangleGradientTarget
% a version of the rectangular textured target which can shift suddenly
% from one position/size to another

    methods 
        function shift(r, xcNew, ycNew, widthNew, depthNew)
            r.xc = xcNew;
            r.yc = ycNew;
            r.width = widthNew;
            r.depth = depthNew;
            r.pendingUpdateTexture = true;
        end
    end
end
