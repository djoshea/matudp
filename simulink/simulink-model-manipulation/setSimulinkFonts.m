function setSimulinkFonts(fontName, fontSize)

    sys = get_param(getCurrentRootSystem(), 'Handle');
    set(sys, 'DefaultLineFontName', fontName, ...
        'DefaultAnnotationFontName', fontName, ...
        'DefaultBlockFontName', fontName);
    
    if nargin >= 2
        set(sys, 'DefaultLineFontSize', fontSize, ...
            'DefaultAnnotationFontSize', fontSize, ...
            'DefaultBlockFontSize', fontSize);
    end
    
    hb = find_in_models(sys, 'FollowLinks', 'off', 'LookUnderMasks', 'all', 'Type', 'block');
    ha = find_in_models(sys, 'FollowLinks', 'off', 'LookUnderMasks', 'all', 'FindAll', 'on', 'Type', 'annotation');
    hl = find_in_models(sys, 'FollowLinks', 'off', 'LookUnderMasks', 'all', 'FindAll', 'on', 'Type', 'line');

    if ~isnumeric(hb)
        hb = cellfun(@(name) get_param(name, 'Handle'), hb);
    end
    
    hh = [hb; ha; hl];
    
    if nargin < 2
        set(hh, 'FontName', fontName);
    else
        set(hh, 'FontName', fontName, 'FontSize', fontSize, 'FontWeight', 'normal');
    end
    
    % handle annotations separately;
    for iA = 1:numel(ha)
        h = ha(iA);
        t = get(h, 'Text');
        t = regexprep(t, 'font-family:''[\w ]+''', 'font-family:''Source Code Pro''');
        if nargin >= 2
            t = regexprep(t, 'font-size:\d+px', sprintf('font-size:%dpx', fontSize));
        end
        set(h, 'Text', t);       
    end

    
end

