function functions = extract_functions(tokens)
    beginnings = {'for' 'parfor' 'while' 'if' 'switch' 'classdef' ...
                  'events' 'properties' 'enumeration' 'methods' ...
                  'function'};

    functions = struct('name', {}, 'body', {}, 'nesting', {}, 'children', {}, 'variables', {});
    stack = struct('start', {}, 'nesting', {}, 'children', {});
    nesting = 0;
    for pos = 1:length(tokens)
        token = tokens(pos);
        % count the 'end's to figure out when functions end
        if strcmp(token.type, 'keyword') && any(strcmp(token.text, beginnings))
            nesting = nesting + 1;
        elseif strcmp(token.type, 'keyword') && strcmp(token.text, 'end')
            nesting = nesting - 1;
        end
        % remember function starts and ends
        if strcmp(token.type, 'keyword') && strcmp(token.text, 'function')
            stack = [stack struct('start', pos, 'nesting', nesting-1, 'children', [])];
        elseif (strcmp(token.type, 'keyword') && strcmp(token.text, 'end') && ...
                ~isempty(stack) && nesting == stack(end).nesting)
            body = tokens(stack(end).start:pos);
            func = struct('name', get_funcname(body), ...
                          'body', body, ...
                          'nesting', stack(end).nesting, ...
                          'children', stack(end).children, ...
                          'variables', {variables(body)});
            stack(end) = [];
            if nesting > 0
                if isempty(stack(end).children)
                    stack(end).children = func;
                else
                    stack(end).children = [stack(end).children func];
                end
            else
                functions = [functions func];
            end
        end
    end
end


function variables = variables(tokens)
    variables = containers.Map();
    for pos = 1:length(tokens)
        token = tokens(pos);
        if strcmp(token.type, 'punctuation') && strcmp(token.text, '=')
            start = search_token('newline', [], tokens, pos, -1);
            lhs_tokens = tokens(start:pos);
            % strip white space from beginning and end
            if strcmp(lhs_tokens(1).type, 'space')
                lhs_tokens = lhs_tokens(2:end);
            end
            if strcmp(lhs_tokens(end).type, 'space')
                lhs_tokens = lhs_tokens(1:end-1);
            end
            % strip parens from beginning and end
            if strcmp(lhs_tokens(1).type, 'pair') && strcmp(lhs_tokens(end).type, 'pair')
                lhs_tokens = lhs_tokens(2:end-1);
            end
            % all non-nested identifiers are assigned variable names
            nesting = 0;
            for t=lhs_tokens
                if strcmp(t.type, 'pair') && any(t.text == '[{(')
                    nesting = nesting + 1;
                elseif strcmp(t.type, 'pair') && any(t.text == ']})')
                    nesting = nesting - 1;
                elseif strcmp(t.type, 'identifier') && nesting == 0
                    variables(t.text) = true;
                end
            end
        end
    end
    variables = variables.keys();
end


function name = get_funcname(tokens)
    % skip leading space
    if strcmp(tokens(1).type, 'space')
        tokens = tokens(2:end);
    end
    % skip function keyword
    tokens = tokens(2:end);
    if strcmp(tokens(1).type, 'space')
        tokens = tokens(2:end);
    end
    % function [...] = foobar(...)
    if strcmp(tokens(1).type, 'pair')
        pos = search_token('punctuation', '=', tokens, 1, +1);
        pos = search_token('identifier', [], tokens, pos, +1);
    % function varname = foobar(...)
    elseif strcmp(tokens(1).type, 'identifier') && ...
        ((strcmp(tokens(2).type, 'punctuation') && strcmp(tokens(2).text, '=')) || ...
         (strcmp(tokens(3).type, 'punctuation') && strcmp(tokens(3).text, '=')))
        pos = search_token('punctuation', '=', tokens, 1, +1);
        pos = search_token('identifier', [], tokens, pos, +1);
    % function foobar(...)
    else
        pos = search_token('pair', '(', tokens, 1, +1);
        pos = search_token('identifier', [], tokens, pos, -1);
    end
    name = tokens(pos).text;
end


function pos = search_token(name, text, tokens, pos, increment)
    if ~isempty(name) && ~isempty(text)
        while ~( strcmp(tokens(pos).type, name) && strcmp(tokens(pos).text, text) )
            if pos + increment < 1 || pos + increment > length(tokens), break, end
            pos = pos + increment;
        end
    elseif ~isempty(text)
        while ~strcmp(tokens(pos).text, text)
            if pos + increment < 1 || pos + increment > length(tokens), break, end
            pos = pos + increment;
        end
    elseif ~isempty(name)
        while ~strcmp(tokens(pos).type, name)
            if pos + increment < 1 || pos + increment > length(tokens), break, end
            pos = pos + increment;
        end
    end
end
