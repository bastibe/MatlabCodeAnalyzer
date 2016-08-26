function report = check(funcname)
    % [files, products] = matlab.codetools.requiredFilesAndProducts(funcname);

    text = fileread(funcname);
    tokens = tokenize(text);

    report = containers.Map();
    report('functions') = functions(tokens);
    report('variables') = variables(tokens);
end

function variables = variables(tokens)
    variables = containers.Map();
    for pos = 1:length(tokens)
        token = tokens(pos);
        if strcmp(token.name, 'punctuation') && strcmp(token.text, '=')
            start = search_token('newline', [], tokens, pos, -1);
            for t=tokens(start:pos)
                if strcmp(t.name, 'identifier')
                    variables(t.text) = true;
                end
            end
        end
    end
    variables = variables.keys();
end

function functions = functions(tokens)
    beginnings = {'for' 'parfor' 'while' 'if' 'switch' 'classdef' ...
                  'events' 'properties' 'enumeration' 'methods' ...
                  'function'};

    functions = struct('name', {}, 'body', {}, 'indent', {});
    stack = struct('start', {}, 'indent', {});
    indent = 0;
    for pos = 1:length(tokens)
        token = tokens(pos);
        if strcmp(token.name, 'keyword') && any(strcmp(token.text, beginnings))
            indent = indent + 1;
        elseif strcmp(token.name, 'keyword') && strcmp(token.text, 'end')
            indent = indent - 1;
        end
        if strcmp(token.name, 'keyword') && strcmp(token.text, 'function')
            stack = [stack struct('start', pos, 'indent', indent-1)];
        elseif (strcmp(token.name, 'keyword') && strcmp(token.text, 'end') && ...
                ~isempty(stack) && indent == stack(end).indent)
            body = tokens(stack(end).start:pos);
            functions = [functions struct('name', get_funcname(body), ...
                                          'body', body, 'indent', stack(end).indent)];
            stack(end) = [];
        end
    end
end

function name = get_funcname(tokens)
    pos = search_token('pair', '(', tokens, 1, +1);
    pos = search_token('identifier', [], tokens, pos, -1);
    name = tokens(pos).text;
end

function pos = search_token(name, text, tokens, pos, increment)
    if ~isempty(name) && ~isempty(text)
        while ~( strcmp(tokens(pos).name, name) && strcmp(tokens(pos).text, text) )
            if pos == 1 || pos == length(tokens), break, end
            pos = pos + increment;
        end
    elseif ~isempty(text)
        while ~strcmp(tokens(pos).text, text)
            if pos == 1 || pos == length(tokens), break, end
            pos = pos + increment;
        end
    elseif ~isempty(name)
        while ~strcmp(tokens(pos).name, name)
            if pos == 1 || pos == length(tokens), break, end
            pos = pos + increment;
        end
    end
end
