function functions = analyze_file(filename, tokens)
    beginnings = {'for' 'parfor' 'while' 'if' 'switch' 'classdef' ...
                  'events' 'properties' 'enumeration' 'methods' ...
                  'function'};

    functions = struct('name', {}, 'body', {}, 'nesting', {}, ...
                       'children', {}, 'variables', {}, ...
                       'arguments', {}, 'returns', {}, ...
                       'type', {});
    stack = struct('start', {}, 'nesting', {}, 'children', {});
    nesting = 0;
    first = true;
    main_type = '';
    for pos = 1:length(tokens)
        token = tokens(pos);
        % count the 'end's to figure out when functions end
        if token.isEqual('keyword', beginnings)
            nesting = nesting + 1;
        elseif token.isEqual('keyword', 'end')
            nesting = nesting - 1;
        end
        if isempty(main_type) && ~token.hasType({'newline', 'comment'})
            if token.isEqual('keyword', 'function')
                main_type = 'Function';
            elseif token.isEqual('keyword', 'classdef')
                main_type = 'Class';
            else
                main_type = 'Script';
            end
        end
        % remember function starts and ends
        if token.isEqual('keyword', 'function')
            if pos > 1 && tokens(pos-1).hasType('space')
                start = pos - 1;
            else
                start = pos;
            end
            stack = [stack struct('start', start, 'nesting', nesting-1, 'children', [])];
        elseif (token.isEqual('keyword', 'end') && ...
                ~isempty(stack) && nesting == stack(end).nesting) || ...
               (pos == length(tokens) && ~isempty(stack)) % allow functions without end
            body = tokens(stack(end).start:pos);
            if nesting > 0 && pos ~= length(tokens)
                type = 'Nested Function';
            elseif first
                type = main_type;
                first = false;
            else
                type = 'Subfunction';
            end
            func = struct('name', get_funcname(body), ...
                          'body', body, ...
                          'nesting', stack(end).nesting, ...
                          'children', stack(end).children, ...
                          'variables', {get_funcvariables(body)}, ...
                          'arguments', {get_funcarguments(body)}, ...
                          'returns', {get_funreturns(body)}, ...
                          'type', type);
            stack(end) = [];
            if nesting > 0 && ~isempty(stack)
                if isempty(stack(end).children)
                    stack(end).children = func;
                else
                    stack(end).children = [stack(end).children func];
                end
            else
                functions = [functions func];
            end
        elseif pos == length(tokens) && strcmp(main_type, 'Script')
            functions = struct('name', Token('special', filename, 0, 0), ...
                               'body', tokens, ...
                               'nesting', 0, ...
                               'children', functions, ...
                               'variables', {get_variables(tokens)}, ...
                               'arguments', [], ...
                               'returns', [], ...
                               'type', main_type);
        elseif pos == length(tokens) && strcmp(main_type, 'Class')
            functions = struct('name', Token('special', filename, 0, 0), ...
                               'body', tokens, ...
                               'nesting', 0, ...
                               'children', functions, ...
                               'variables', {get_properties(tokens)}, ...
                               'arguments', [], ...
                               'returns', [], ...
                               'type', main_type);
        end
    end
end


function variables = get_properties(tokens)
    variables = Token.empty;
    in_properties = false;
    is_first = false;
    for pos = 1:length(tokens)
        token = tokens(pos);
        if token.isEqual('keyword', 'properties')
            in_properties = true;
            is_first = false;
        elseif in_properties && token.isEqual('keyword', 'end')
            in_properties = false;
        end
        if token.hasType('linebreak')
            is_first = true;
        elseif token.hasType('identifier') && is_first && in_properties
            variables = [variables token];
            is_first = false;
        end
    end
end


function variables = get_funcvariables(tokens)
    func_start = search_token('pair', ')', tokens, 1, +1);
    variables = get_variables(tokens(func_start:end));
end


function variables = get_variables(tokens)
    variables = containers.Map();
    for pos = 1:length(tokens)
        token = tokens(pos);
        if token.isEqual('punctuation', '=')
            start = search_token('linebreak', [], tokens, pos, -1);
            lhs_tokens = tokens(start:pos);
            % strip white space from beginning and end
            if lhs_tokens(1).hasType('space')
                lhs_tokens = lhs_tokens(2:end);
            end
            if lhs_tokens(end).hasType('space')
                lhs_tokens = lhs_tokens(1:end-1);
            end
            % strip parens from beginning and end
            if lhs_tokens(1).hasType('pair') && lhs_tokens(end).hasType('pair')
                lhs_tokens = lhs_tokens(2:end-1);
            end
            % all non-nested identifiers are assigned variable names
            nesting = 0;
            for t=lhs_tokens
                if t.isEqual('pair', '[{(')
                    nesting = nesting + 1;
                elseif t.isEqual('pair', ']})')
                    nesting = nesting - 1;
                elseif t.hasType('identifier') && nesting == 0 && ~variables.isKey(t.text)
                    variables(t.text) = t;
                end
            end
        end
    end
    variables = variables.values();
    variables = [variables{:}]; % convert to object array
    if ~isempty(variables)
        % sort by char:
        [~, idx] = sort([variables.char]);
        variables = variables(idx);
        % sort by line (in case of collision, this preserves char ordering):
        [~, idx] = sort([variables.line]);
        variables = variables(idx);
    end
end


function name = get_funcname(tokens)
    pos = search_token('pair', '(', tokens, 1, +1);
    pos = search_token('identifier', [], tokens, pos, -1);
    name = tokens(pos);
end


function arguments = get_funcarguments(tokens)
    start = search_token('pair', '(', tokens, 1, +1);
    stop = search_token('pair', ')', tokens, start, +1);
    arguments = tokens(start+1:stop-1);
    % extract all identifiers:
    arguments = arguments(strcmp({arguments.type}, 'identifier'));
end


function returns = get_funreturns(tokens)
    start = search_token('keyword', 'function', tokens, 1, +1);
    pos = search_token('pair', '(', tokens, start, +1);
    stop = search_token('identifier', [], tokens, pos, -1);
    returns = tokens(start+1:stop-1);
    % extract all identifiers:
    returns = returns(strcmp({returns.type}, 'identifier'));
end


function pos = search_token(name, text, tokens, pos, increment)
    if ~isempty(name) && ~isempty(text)
        while ~tokens(pos).isEqual(name, text)
            if pos + increment < 1 || pos + increment > length(tokens)
                break
            end
            pos = pos + increment;
        end
    elseif ~isempty(text)
        while ~tokens(pos).hasText(text)
            if pos + increment < 1 || pos + increment > length(tokens)
                break
            end
            pos = pos + increment;
        end
    elseif ~isempty(name)
        while ~tokens(pos).hasType(name)
            if pos + increment < 1 || pos + increment > length(tokens)
                break
            end
            pos = pos + increment;
        end
    end
end
