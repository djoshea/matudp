function GratingDemo
% GratingDemo
%
% Displays a stationary grating.  See also DriftDemo, DriftDemo2, DriftDemo3 and DriftWaitDemo.

% ---------- Program History ----------

% 07/01/1999 dgp Added arbitrary orientation.
% 12/10/2001 awi Added font conditional.
% 02/21/2002 dgp Mentioned DriftDemo.
% 04/03/2002 awi Merged OS9 and Win versions, which had fallen out of sync. 
% 04/13/2002 dgp Used Arial, eliminating need for conditional.
% 07/15/2003 dgp Added comments explaining f and lambda.
% 08/16/2006 rhh Added user-friendly parameters, such as tiltInDegrees,
%                pixelsPerPeriod, periodsCoveredByOneStandardDeviation and widthOfGrid.
% 08/18/2006 rhh Expanded comments and created comment sections.
% 10/04/2006 dhb Minimize warnings.
% 10/11/2006 dhb Use maximum available screen.
% 10/14/2006 dhb Save and restore altered prefs, more extensive comments for them
% 07/12/2006 prf Changed method of rotating the grating

% ---------- Parameter Setup ----------
% Initializes the program's parameters.

% Prevents MATLAB from reprinting the source code when the program runs.
echo off

theta = pi/4;
ecc = 0.95;
S = 200;
A = 1;

[im X Y contourX contourY f] = buildEllipseImage('amp', A, 'spacing', 1, ...
            'theta', theta, 'ecc', ecc, 'size', S, 'showPlot', false);

screenRect = [0 0 800 800];

% For an explanation of the try-catch block, see the section "Error Handling"
% at the end of this document.
try
    
	% ---------- Window Setup ----------
	% Opens a window.

	% Screen is able to do a lot of configuration and performance checks on
	% open, and will print out a fair amount of detailed information when
	% it does.  These commands supress that checking behavior and just let
    % the demo go straight into action.  See ScreenTest for an example of
    % how to do detailed checking.
	oldVisualDebugLevel = Screen('Preference', 'VisualDebugLevel', 3);
    oldSupressAllWarnings = Screen('Preference', 'SuppressAllWarnings', 1);
	
    % Find out how many screens and use largest screen number.
    whichScreen = max(Screen('Screens'));
    
	% Hides the mouse cursor
	HideCursor;
	
	% Opens a graphics window on the main monitor (screen 0).  If you have
	% multiple monitors connected to your computer, then you can specify
	% a different monitor by supplying a different number in the second
	% argument to OpenWindow, e.g. Screen('OpenWindow', 2).
	window = Screen('OpenWindow', whichScreen, [0 0 0], screenRect, [], [], [], [], [], 32);
	  
    tex = Screen('MakeTexture', window, im*255);
	% ---------- Color Setup ----------
	% Gets color values.

	% Retrieves color codes for black and white and gray.
	black = BlackIndex(window);  % Retrieves the CLUT color code for black.
	white = WhiteIndex(window);  % Retrieves the CLUT color code for white.
	gray = (black + white) / 2;  % Computes the CLUT color code for gray.
	if round(gray)==white
		gray=black;
    end
	 
	% Taking the absolute value of the difference between white and gray will
	% help keep the grating consistent regardless of whether the CLUT color
	% code for white is less or greater than the CLUT color code for black.
	absoluteDifferenceBetweenWhiteAndGray = abs(white - gray);

    imageMatrix = im*2 - 1;

	grayscaleImageMatrix = gray + absoluteDifferenceBetweenWhiteAndGray * imageMatrix;

	% ---------- Image Display ---------- 
	% Displays the image in the window.
	 
	% Colors the entire window gray.
	Screen('FillRect', window, gray);

	% Writes the image to the window.
	Screen('DrawTexture', window, tex);

	% Writes text to the window.
%	currentTextRow = 0;
%	Screen('DrawText', window, sprintf('black = %d, white = %d', black, white), 0, currentTextRow, black);
	%currentTextRow = currentTextRow + 20;
	%Screen('DrawText', window, 'Press any key to exit.', 0, currentTextRow, black);

	% Updates the screen to reflect our changes to the window.
	Screen('Flip', window);

	% Waits for the user to press a key.
	KbWait;

	% ---------- Window Cleanup ---------- 

	% Closes all windows.
	Screen('CloseAll');
	 
	% Restores the mouse cursor.
	ShowCursor;

    % Restore preferences
    Screen('Preference', 'VisualDebugLevel', oldVisualDebugLevel);
    Screen('Preference', 'SuppressAllWarnings', oldSupressAllWarnings);
catch
   
	% ---------- Error Handling ---------- 
	% If there is an error in our code, we will end up here.

	% The try-catch block ensures that Screen will restore the display and return us
	% to the MATLAB prompt even if there is an error in our code.  Without this try-catch
	% block, Screen could still have control of the display when MATLAB throws an error, in
	% which case the user will not see the MATLAB prompt.
	Screen('CloseAll');

	% Restores the mouse cursor.
	ShowCursor;
    
    % Restore preferences
    Screen('Preference', 'VisualDebugLevel', oldVisualDebugLevel);
    Screen('Preference', 'SuppressAllWarnings', oldSupressAllWarnings);

	% We throw the error again so the user sees the error description.
	psychrethrow(psychlasterror);
    
end
