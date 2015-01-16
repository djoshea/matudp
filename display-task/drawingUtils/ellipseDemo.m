function ellipseDemo()

A = 1;
theta = pi/3;
delta = 2*pi/100;

eGUI = gui.autogui;
set(gcf, 'Position', [0 0 500 500]);
eGUI.Name = 'Oriented Ellipse Demo';
eccSlider = gui.slider('Eccentricity', [0 0.99999]);
eccSlider.Value = 0.9;
sizeSlider = gui.slider('Size', [0.001 20]);
thetaSlider = gui.slider('Theta', [0 2*pi]);
thetaSlider.Value = pi/4;

figH = gcf;
set(figH, 'NumberTitle', 'off', 'ToolBar', 'none', 'MenuBar', 'none', ...
    'Color', [0 0 0]);
ch = get(figH, 'Children');

cmap = zeros(1000, 3);
cmap(:,2) = linspace(0,1, size(cmap,1));
colormap(cmap);
figsize(6,9);

cla;
axis off;
set(get(gca, 'Parent'), 'BackgroundColor', [0 0 0]);

p = panel();
p.pack(1,1);
p(1,1).select();
p.margin = 0;

cmapGreen = zeros(1000, 3);
cmapGreen(:,2) = linspace(0,1, size(cmapGreen,1));

cmapRed = zeros(1000, 3);
cmapRed(:,1) = linspace(0,1, size(cmapRed,1));
colormap(cmapRed);

while ishandle(figH)
    if theta ~= thetaSlider.Value || S ~= sizeSlider.Value || ecc ~= eccSlider.Value
        theta = thetaSlider.Value;
        S = sizeSlider.Value;
        ecc = eccSlider.Value;
        %theta = mod(theta+delta, 2*pi);
        %fprintf('Theta %.3f\n', theta);

        [im X Y contourX contourY f] = buildEllipseImage('amp', A, 'spacing', 0.1, ...
            'theta', theta, 'ecc', ecc, 'size', S, 'showPlot', false);

        cla;
        h = pcolor(X, Y, im);
        set(h, 'EdgeColor', 'none');
        hold on
        h = plot(contourX, contourY, 'w-');        
        plot(0, 0, 'w+', 'MarkerSize', 10)
        box off

    %     xlim([xMin-xMargin xMax+xMargin])
    %     ylim([yMin-yMargin yMax+yMargin])
        axis tight;
        axis equal;
        axis off;
        drawnow;
        
        set(gcf, 'WindowButtonMotionFcn', @mouseMoveFn);
        set(get(gca, 'Children'), 'HitTest', 'off');
        title('Ellipse');
    end

    pause(0.1);
    %eGUI.waitForInput;
end

function mouseMoveFn(src, event)
    pt = get(gca, 'CurrentPoint');
    x = pt(1,1);
    y = pt(1,2);
    if insideContour(x, y, 2)
        str = 'Inside Ellipse!';
        colormap(cmapGreen);
    else
        str = 'Outside Ellipse';
        colormap(cmapRed);
    end
    title(sprintf('[%.2f, %.2f] %s', x, y, str));
end

function tf = insideContour(x, y, threshFactor)
    thresh = A*exp(-threshFactor^2 / 2);
    vals = f(x, y);
    
    tf = false(size(x));
    tf(vals > thresh) = true;     
end
    

end


