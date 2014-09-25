function rendered = replaceTokensInTemplate(template, tokenStruct, conditionalFlags)
% given a string template, which contains tokens of the form {{ tokenName }},
% replace each tokenName with the value in tokenStruct.(tokenName). Also
% for each boolean flag in conditionalFlags, substitute either the
% trueClause or falseClause depending on whether conditionalFlags.(flag) is
% true or false. In the template, this looks like:
%
% {{ if:flag }}
%     trueClause
% {{ else:flag }}
%     falseClause
% {{ endif:flag }}
%

    if nargin < 3
        conditionalFlags = struct();
    end

    % replace {{ token }} with tokenStruct.(token)
    tokens = fieldnames(tokenStruct);

    regexes = cellfun(@(token) sprintf('{{\\s*%s\\s*}}', token), tokens, ...
        'UniformOutput', false);
    
    values = cell(size(regexes));
    for iV = 1:numel(tokens)
        if ischar(tokenStruct.(tokens{iV}))
            values{iV} = tokenStruct.(tokens{iV});
        else
            values{iV} = mat2str(tokenStruct.(tokens{iV}), 'class');
        end
    end
    
    rendered = regexprep(template, regexes, values);

    % find {{ if:flag }} conditional content {{ endif:flag }}
    flags = fieldnames(conditionalFlags);
    for iF = 1:numel(flags)
        % first match inner (which may contain and else:flag clause)
        pat = sprintf('(?<={{\\s*if:%s\\s*}})(?<inner>.*)(?={{\\s*endif:%s\\s*}})', ...
            flags{iF}, flags{iF});
        
        while true
            % get first match
            byName = regexp(rendered, pat, 'names', 'once');
            if isempty(byName)
                continue;
            end
            
            % split into true and false clauses
            patWithElse = '(?<trueClause>.?+){{ else:flag }}(?<falseClause>.?)';
            clauses = regexp(byName.inner, patWithElse, 'names', 'once');
            if isempty(clauses)
                % no else flag, just a positive clause
                clauses.trueClause = byName.innner;
                clauses.falseClause = '';
            end
                
            % replace this single match in the string
            if conditionalFlags.(flags{iF})
                rendered = regexprep(rendered, pat, clauses.trueClause, 'once');
            else
                rendered = regexprep(rendered, pat, clauses.falseClause, 'once');
            end
        end
    end
    

end
