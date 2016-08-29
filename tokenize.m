function tokens = tokenize(text)
%TOKENIZE splits M-code into tokens
%   TOKENIZE(TEXT) splits the TEXT into interpretable parts.
%   It returns a struct array, where each struct contains a 'type' and
%   a 'text'. Concatenating all 'text's recreates the original TEXT.
%   'type' can be one of:
%   - 'keyword'
%   - 'identifier'
%   - 'space'
%   - 'punctuation'
%   - 'property'
%   - 'string'
%   - 'number'
%   - 'pair'
%   - 'newline'
%   - 'comment'
%   - 'escape'

    punctuation = '=.&|><~+-*^/\:@';
    open_pairs = '{[(';
    close_pairs = '}])';
    escapes = '!%';

    keywords = {'for' 'try' 'while' 'if' 'else' 'elseif' 'switch' ...
                'case' 'default' 'function' 'classdef' 'methods' ...
                'properties' 'events' 'enumeration' 'parfor' ...
                'elseif' 'case' 'default' 'break'...
                'continue'};
    operators = { '+'  '-'  '*'  '/'  '^'  '\' ...
                 '.+' '.-' '.*' './' '.^' '.\' ...
                 '>' '<' '~' '==' '>=' '<=' '~=' ...
                 '@' '=' ',' ';' '||' '&&' '|' '&'};
    unary_operators = '+-@~';

    space = sprintf(' \t');
    breaks = sprintf('\n');
    number_start = '0123456789';
    number_body = [number_start 'eEij.'];
    name_start = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    name_body = [name_start '0123456789_'];

    loc = 1;
    line_num = 1;
    line_start = loc;
    tokens = struct('type', {}, 'text', {}, 'line', {}, 'char', {});
    text = [text sprintf('\n')];
    nesting = 0; % count braces to decide whether 'end' is an operator or a keyword
    while loc < length(text)
        letter = text(loc);
        if any(letter == name_start)
            symbol = skip(name_body);
            if any(strcmp(symbol, keywords))
                add_token('keyword', symbol);
            elseif strcmp(symbol, 'end') && nesting == 0
                add_token('keyword', symbol);
            else
                add_token('identifier', symbol);
            end
        elseif any(letter == space)
            symbol = skip(space);
            add_token('space', symbol);
        elseif any(letter == punctuation)
            % property access
            if letter == '.' && loc < length(text) && any(text(loc+1) == name_start)
                loc = loc + 1;
                symbol = [letter skip(name_body)];
                add_token('property', symbol);
            else
                symbol = skip(punctuation);
                % one operator:
                if any(strcmp(symbol, operators))
                    add_token('punctuation', symbol);
                % a binary operator, followed by a unary operator:
                elseif any(symbol(end) == unary_operators) && any(strcmp(symbol(1:end-1), operators))
                    add_token('punctuation', symbol(1:end-1));
                    add_token('punctuation', symbol(end));
                % element-wise transpose operator:
                elseif strcmp(symbol, '.') && text(loc) == ''''
                    loc = loc + 1;
                    add_token('punctuation', '.''');
                else
                    error(['unknown operator ''' symbol '''']);
                end
            end
        elseif letter == ''''
            previous = tokens(end);
            % transpose operator:
            if (strcmp(previous.type, 'pair') && any(previous.text == '}])')) || ...
               strcmp(previous.type, 'identifier') || strcmp(previous.type, 'number') || ...
               strcmp(previous.type, 'property');
                loc = loc + 1;
                add_token('punctuation', letter);
            % strings:
            else
                str = skip_string();
                add_token('string', str);
            end
        elseif any(letter == open_pairs)
            loc = loc + 1;
            nesting = nesting + 1;
            add_token('pair', letter);
        elseif any(letter == close_pairs)
            loc = loc + 1;
            nesting = nesting - 1;
            add_token('pair', letter);
        elseif any(letter == breaks)
            loc = loc + 1;
            add_token('newline', letter);
            % add the token before incrementing the line to to avoid
            % confusing add_token
            line_num = line_num + 1;
            line_start = loc;
        elseif any(letter == ';,')
            loc = loc + 1;
            if nesting == 0
                add_token('newline', letter);
            else
                add_token('punctuation', letter);
            end
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
        tokens(length(tokens)+1) = struct('type', name, 'text', text, ...
                                          'line', line_num, 'char', loc-line_start-length(text));
    end

    function symbol = skip(letters)
        start = loc;
        while any(text(loc) == letters)
            loc = loc + 1;
        end
        symbol = text(start:loc-1);

        function foobar()
        end

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
