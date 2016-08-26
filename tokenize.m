function tokens = tokenize(text)
%TOKENIZE splits M-code into tokens
%   TOKENIZE(TEXT) splits the TEXT into interpretable parts.
%   It returns a struct array, where each struct contains a 'name' and
%   a 'text'. Concatenating all 'text's recreates the original TEXT.
%   'name' can be one of:
%   - 'keyword'
%   - 'variable'
%   - 'space'
%   - 'punctuation'
%   - 'string'
%   - 'number'
%   - 'pair'
%   - 'newline'
%   - 'comment'
%   - 'escape'

    punctuation = '=.&|><~+-*^/\:,@;';
    pairs = '{}[]()';
    escapes = '!%';
    keywords = {'for' 'try' 'while' 'if' 'switch' 'function' ...
                'classdef' 'methods' 'properties' 'events' 'enumeration' ...
                'parfor' 'end' 'elseif' 'case' 'default'};
    space = sprintf(' \t');
    breaks = sprintf('\n');
    number_start = '0123456789';
    number_body = [number_start 'eEij.'];
    name_start = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    name_body = [name_start '0123456789_'];

    loc = 1;
    tokens = struct('name', {}, 'text', {});
    text = [text sprintf('\n')];
    while loc < length(text)
        letter = text(loc);
        if any(letter == name_start)
            symbol = skip(name_body);
            if any(strcmp(symbol, keywords))
                add_token('keyword', symbol);
            else
                add_token('variable', symbol);
            end
        elseif any(letter == space)
            symbol = skip(space);
            add_token('space', symbol);
        elseif any(letter == punctuation)
            symbol = skip(punctuation);
            add_token('punctuation', symbol);
        elseif letter == ''''
            previous = tokens(end);
            % transpose operator:
            if (strcmp(previous.name, 'pair') && any(previous.text == '}])')) || ...
               strcmp(previous.name, 'variable') || strcmp(previous.name, 'number');
                add_token('punctuation', letter);
                loc = loc + 1;
            % element-wise transpose operator:
            elseif (strcmp(previous.name, 'punctuation') && previous.text(end) == '.')
                tokens(end) = struct('name', previous.name, ...
                                     'text', [previous.text letter]);
                loc = loc + 1;
            % strings:
            else
                str = skip_string();
                add_token('string', str);
            end
        elseif any(letter == pairs)
            add_token('pair', letter);
            loc = loc + 1;
        elseif any(letter == breaks)
            add_token('newline', letter);
            loc = loc + 1;
        elseif any(letter == number_start)
            symbol = skip(number_body);
            add_token('number', symbol);
        elseif any(letter == escapes)
            line = skip_line();
            if letter == '%'
                add_token('comment', line);
            else
                add_token('escape', line);
            end
        else
            error('unknown identifier');
        end
    end

    function add_token(name, text)
        tokens(length(tokens)+1) = struct('name', name, 'text', text);
    end

    function symbol = skip(letters)
        start = loc;
        while any(text(loc) == letters)
            loc = loc + 1;
        end
        symbol = text(start:loc-1);
    end

    function line = skip_line()
        start = loc;
        while text(loc) ~= sprintf('\n')
            loc = loc + 1;
        end
        line = text(start:loc-1);
    end

    function str = skip_string()
        start = loc;
        while true
            if text(loc) ~= '''' || loc == start
                loc = loc + 1;
            elseif length(text) > loc && text(loc+1) == ''''
                loc = loc + 2;
            else % text(loc) == ''''
                loc = loc + 1;
                break;
            end
        end
        str = text(start:loc-1);
    end
end
