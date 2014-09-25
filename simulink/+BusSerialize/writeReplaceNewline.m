function writeReplaceNewline(fid, varargin)
    persistent replaceNewLine;
    if isempty(replaceNewLine)
        replaceNewLine = char(java.lang.System.getProperty('line.separator'));
    end
    
    fmatStr = varargin{1};
    origNewLine = '\n';
    fmatStr = strrep(fmatStr, origNewLine, replaceNewLine);
    fprintf(fid, fmatStr, varargin{2:end});
end
