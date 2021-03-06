function testGetScreenPhysicalSize(screenIdx, pixelPitch)
% testGetScreenPhysicalSize(screenIdx, pixelPitch in mm)
% displays the screen half-rect and a 100 mm square

if nargin < 1
    screenIdx = max(Screen('Screens'));
end

[pw, ph] = Screen('WindowSize', screenIdx);
[mmWidth, mmHeight] = Screen('DisplaySize', screenIdx);

if nargin < 2
    % compute 100 mm center square
    
    
    pixelPitch(1) = mmWidth / pw;
    pixelPitch(2) = mmHeight / ph;
else
    if numel(pixelPitch) == 1
        pixelPitch(2) = pixelPitch(1);
    end
end

fprintf('Pixel pitch is [%g w, %g h]\n', pixelPitch(1), pixelPitch(2));

% For an explanation of the try-catch block, see the section "Error Handling"
% at the end of this document.
try
	
	% Opens a graphics window on the main monitor (screen 0).  If you have
	% multiple monitors connected to your computer, then you can specify
	% a different monitor by supplying a different number in the second
	% argument to OpenWindow, e.g. Screen('OpenWindow', 2).
	window = Screen('OpenWindow', screenIdx);
    
	% Retrieves color codes for black and white and gray.
	black = BlackIndex(window);  % Retrieves the CLUT color code for black.
	white = WhiteIndex(window);  % Retrieves the CLUT color code for white.
    darkGray = [50 50 50];
    
    
    rectWidth = pw/2;
    rectHeight = ph/2;
    left = pw/4;
    top = ph/4;
    % left, top, right, bottom
    halfRect = [left, top, left+rectWidth, top+rectHeight];

    squareWidth = 100 / pixelPitch(1);
    squareHeight = 100 / pixelPitch(2);
    squareLeft = (pw-squareWidth)/2;
    squareTop = (ph-squareHeight)/2;
    square = [squareLeft, squareTop, squareLeft+squareWidth, squareTop+squareHeight];
    red = [white black black];
    
	% Colors the entire window gray.
    Screen('FillRect', window, black);
    
	Screen('FillRect', window, darkGray, halfRect)
    
    Screen('FillRect', window, red, square)
    
	% Writes text to the window.
	currentTextRow = 100;
	Screen('DrawText', window, sprintf('screen size [%.0f, %.0f] pixels', pw, ph), 0, currentTextRow, white);
	currentTextRow = currentTextRow + 20;
    Screen('DrawText', window, sprintf('physical size [%.0f, %.0f] mm', mmWidth, mmHeight), 0, currentTextRow, white);
    currentTextRow = currentTextRow + 20;
	Screen('DrawText', window, 'Press any key to exit.', 0, currentTextRow, white);

	% Updates the screen to reflect our changes to the window.
	Screen('Flip', window);

	% Waits for the user to press a key.
	KbWait;

	% ---------- Window Cleanup ---------- 

	% Closes all windows.
	Screen('CloseAll');
	 
	% Restores the mouse cursor.
	ShowCursor;
catch
   
	% ---------- Error Handling ---------- 
	% If there is an error in our code, we will end up here.

	% The try-catch block ensures that Screen will restore the display and return us
	% to the MATLAB prompt even if there is an error in our code.  Without this try-catch
	% block, Screen could still have control of the display when MATLAB throws an error, in
	% which case the user will not see the MATLAB prompt.
	Screen('CloseAll');

	% We throw the error again so the user sees the error description.
	psychrethrow(psychlasterror);
    
end
