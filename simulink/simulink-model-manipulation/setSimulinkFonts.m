function setSimulinkFonts(fontName, fontSize)

    sys = get_param(getCurrentRootSystem(), 'Handle');
    set(sys, 'DefaultLineFontName', fontName, 'DefaultLineFontSize', fontSize, ...
        'DefaultAnnotationFontName', fontName, 'DefaultAnnotationFontSize', fontSize, ...
        'DefaultBlockFontName', fontName, 'DefaultBlockFontSize', fontSize);
    
    hb = find_in_models(sys, 'FollowLinks', 'off', 'LookUnderMasks', 'all', 'Type', 'block');
    ha = find_in_models(sys, 'FollowLinks', 'off', 'LookUnderMasks', 'all', 'FindAll', 'on', 'Type', 'annotation');
    hl = find_in_models(sys, 'FollowLinks', 'off', 'LookUnderMasks', 'all', 'FindAll', 'on', 'Type', 'line');

    if ~isnumeric(hb)
        hb = cellfun(@(name) get_param(name, 'Handle'), hb);
    end
    
    hh = [hb; ha; hl];
    
    set(hh, 'FontName', fontName, 'FontSize', fontSize, 'FontWeight', 'normal');

end

