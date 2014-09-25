function differed = overwriteIfFilesDiffer(fileFrom, fileTo)
% check whether the contents of fileFrom and fileTo differ. If they do,
% copy fileFrom to fileTo, thus replacing fileTo with fileFrom.

file1 = javaObject('java.io.File', fileFrom);
file2 = javaObject('java.io.File', fileTo);
filesSame = javaMethod('contentEquals','org.apache.commons.io.FileUtils', file1, file2);

if ~filesSame
    [success, message, messageId] = copyfile(fileFrom, fileTo, 'f');
    if ~success
        error('Error copying %s : %s', messageId, message);
    end
    differed = true;
else
    differed = false;
end
    
    


