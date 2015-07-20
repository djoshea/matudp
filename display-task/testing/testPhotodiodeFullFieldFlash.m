function testPhotodiodeFullFieldFlash(screenIdx)

if nargin < 1
    screenIdx = max(Screen('Screens'));
end


try	
	% Opens a graphics window on the main monitor (screen 0).  If you have
	% multiple monitors connected to your computer, then you can specify
	% a different monitor by supplying a different number in the second
	% argument to OpenWindow, e.g. Screen('OpenWindow', 2).
	window = Screen('OpenWindow', screenIdx);
 
	% Retrieves color codes for black and white and gray.
	black = BlackIndex(window);  % Retrieves the CLUT color code for black.
	white = WhiteIndex(window);  % Retrieves the CLUT color code for white.
    
    frameNum = 1;
    
    while ~KbCheck
        if mod(frameNum, 100) > 50
            Screen('FillRect', window, black);
        else
            Screen('FillRect', window, white);
        end
        
        Screen('Flip', window);
        frameNum = frameNum + 1; 
    end

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
