function tokenlist = tokenize_code(source_code)
%TOKENIZE_CODE splits M-code into Tokens
%   TOKENIZE(SOURCE_CODE) splits the SOURCE_CODE into interpretable
%   parts. It returns an object array of Tokens TOKENLIST, where each
%   token has a 'type', a 'text', a 'line', and a 'col'. Concatenating
%   all 'text's recreates the original SOURCE_CODE.
%   'type' can be one of:
%   - 'keyword'
%   - 'identifier'
%   - 'space'
%   - 'punctuation'
%   - 'property'
%   - 'string'
%   - 'number'
%   - 'pair'
%   - 'linebreak'
%   - 'comment'
%   - 'escape'
%
% See also: Token

% (c) 2016, Bastian Bechtold
% This code is licensed under the terms of the BSD 3-clause license

    punctuation = '=.&|><~+-*^/\:@';
    open_pairs = '{[(';
    close_pairs = '}])';
    escapes = '!%';
    quotes = { '''', '"' };

    keywords = check_settings('keywords');
    
    operators = { '+'  '-'  '*'  '/'  '^'  '\' ...
                 '.+' '.-' '.*' './' '.^' '.\' ...
                 '>' '<' '~' '==' '>=' '<=' '~=' ...
                 '@' '=' ',' ';' '||' '&&' '|' '&' '...' ':'};
    unary_operators = '+-@~.';

    spaces = sprintf(' \t');
    breaks = sprintf('\n\r');
    number_start = '0123456789';
    number_body = [number_start 'eEij.'];
    name_start = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    name_body = [name_start '0123456789_'];

    tokenlist = Token.empty;
    pos = 1; % the current character position in the source_code
    line_num = 1; % the current line number
    line_start = pos; % where the current line started
    is_first_symbol = true; % the first symbol can have special meaning
    source_code = [source_code sprintf('\n')]; % ensure proper file end
    nesting = 0; % count braces, since some operators have different
                 % meaning inside and outside braces
    while pos < length(source_code)
        letter = source_code(pos);
        % a variable or a function or a keyword:
        if any(letter == name_start)
            symbol = skip(name_body);
            % keywords such as `if` or `classdef`
            if any(strcmp(symbol, keywords))
                is_first_symbol = false;
                add_token('keyword', symbol);
            % the keyword `end`:
            elseif strcmp(symbol, 'end') && nesting == 0
                add_token('keyword', symbol);
            % anything else is just a variable or function name:
            else
                add_token('identifier', symbol);
                % if this is the start of a command, the rest of the line
                % needs to be interpreted as strings:
                if is_first_symbol && nesting == 0
                    is_first_symbol = false;
                    saved_pos = pos;
                    first_space = skip(spaces);
                    first_word = skip_unless([spaces breaks ';,%']);
                    pos = saved_pos;
                    % commands are any single identifier that is not
                    % followed by space-operator-space:
                    if ~any(strcmp(first_word, operators)) && ...
                       ~isempty(first_space)
                        parse_command()
                    end
                end
            end
        % a sequence of one or more spaces or tabs:
        elseif any(letter == spaces)
            symbol = skip(spaces);
            add_token('space', symbol);
        % any binary or unary operator, such as `+`, `>=`, or `.foo`
        elseif any(letter == punctuation)
            is_first_symbol = false;
            % property access begins with a `.` operator, and includes a
            % name, such as `.foo`. Classifying this as punctuation makes
            % it easier to differentiate it from variable/function names.
            if letter == '.' && pos < length(source_code) && ...
               any(source_code(pos+1) == name_start)
                pos = pos + 1;
                symbol = [letter skip(name_body)];
                add_token('property', symbol);
            % any other operator:
            else
                symbol = skip(punctuation);
                % one operator:
                if any(strcmp(symbol, operators))
                    add_token('punctuation', symbol);
                % a binary operator, followed by a unary operator:
                elseif any(symbol(end) == unary_operators) && ...
                       any(strcmp(symbol(1:end-1), operators))
                    add_token('punctuation', symbol(1:end-1));
                    add_token('punctuation', symbol(end));
                % element-wise transpose operator:
                % This has to be parsed here, so as to not confuse the `'`
                % with the beginning of a string.
                elseif strcmp(symbol, '.') && source_code(pos) == ''''
                    pos = pos + 1;
                    add_token('punctuation', '.''');
                % struct access operator such as `.(foo)`:
                % There is normally no `.` operator, but it makes sense to
                % classify `.(` as such here.
                elseif strcmp(symbol, '.') && source_code(pos) == '('
                    add_token('punctuation', '.');
                % this should never happen:
                else
                    error(['unknown operator ''' symbol '''']);
                end
            end
        % strings and transpose begin with `'`. The `.'` operator has
        % already been handled above:
        elseif letter == ''''
            is_first_symbol = false;
            previous = tokenlist(end);
            % transpose operator:
            % To differentiate the start of a string from the transpose
            % operator, we need to check whether the previous token was a
            % value or an operator. If a value, `'` means transpose. If an
            % operator, `'` marks the start of a string.
            if previous.isEqual('pair', {'}' ']' ')'}) || ...
               previous.hasType({'identifier' 'number' 'property'})
                pos = pos + 1;
                add_token('punctuation', letter);
            % strings:
            else
                string = skip_string();
                add_token('string', string);
            end
        % string that starts with double quotes (")
        elseif letter == '"'
            is_first_symbol = false;
            string = skip_string();
            add_token('string', string);
        % we don't make any distinction between different kinds of parens:
        elseif any(letter == open_pairs)
            is_first_symbol = false;
            pos = pos + 1;
            nesting = nesting + 1;
            add_token('pair', letter);
        elseif any(letter == close_pairs)
            pos = pos + 1;
            nesting = nesting - 1;
            add_token('pair', letter);
        % new lines are line breaks and increment the line:
        elseif any(letter == breaks)
            % split into individual line breaks
            start = pos;
            line_breaks = regexp(skip(breaks), '(\n)|(\r\n)', 'match');
            pos = start;
            for line_break = line_breaks
                pos = pos + length(line_break{1});
                add_token('linebreak', line_break{1});
                % add the token before incrementing the line to to avoid
                % confusing add_token
                line_num = line_num + 1;
                line_start = pos;
            end
            is_first_symbol = true;
        % `,` and `;` are line breaks that do not increment the line,
        % or simple operators if they occur within a pair
        elseif any(letter == ';,')
            pos = pos + 1;
            if nesting == 0
                add_token('linebreak', letter);
                is_first_symbol = true;
            else
                add_token('punctuation', letter);
            end
        % numbers are easy, and may contain `.`, `e`, `E`, `i`, and `j`
        elseif any(letter == number_start)
            is_first_symbol = false;
            symbol = skip(number_body);
            add_token('number', symbol);
        % finally, comments and `!` include the rest of the line,
        % unless they are block comments, in which case they might include
        % much more.
        elseif any(letter == escapes)
            comment = skip_line();
            if letter == '%'
                if ~isempty(regexp(comment, '^\%\{\s*$', 'once')) && ...
                   is_first_symbol
                    comment = [comment skip_block_comment()]; %#ok
                end
                add_token('comment', comment);
            else
                add_token('escape', comment);
            end
        else
            error('unknown identifier');
        end
    end

    function add_token(token_type, token_text)
    %ADD_TOKEN adds a new token to the token list, and annotates it
    %   with the current line number and column. TOKEN_TYPE and TOKEN_TEXT
    %   become the Token's `type` and `text` property.
    %   this modifies TOKENLIST!

        char_num = pos-line_start-length(token_text)+1;
        tokenlist(length(tokenlist)+1) = Token(token_type, token_text, ...
                                               line_num, char_num);
    end

    function string = skip(letters)
    %SKIP skips LETTERS and returns skipped letters as STRING
    %   this modifies POS!

        string_start = pos;
        while any(source_code(pos) == letters) && pos < length(source_code)
            pos = pos + 1;
        end
        string = source_code(string_start:pos-1);
    end

    function string = skip_unless(letters)
    %SKIP_UNLESS skips letters not in LETTERS and returns skipped letters
    %   as STRING.
    %   this modifies POS!

        string_start = pos;
        while all(source_code(pos) ~= letters)
            pos = pos + 1;
        end
        string = source_code(string_start:pos-1);
    end

    function string = skip_line()
    %SKIP_LINE skips to the end of the line and returns the line as STRING
    %   this modifies POS!

        string_start = pos;
        while all(source_code(pos) ~= sprintf('\r\n'))
            pos = pos + 1;
        end
        string = source_code(string_start:pos-1);
    end

    function string = skip_string()
    %SKIP_STRING skips to the end of the string and returns the STRING
    %   the STRING includes both quotation marks.
    %   this modifies POS!

        string_start = pos;
        while true
            if ~any(strcmp(source_code(pos), quotes)) || pos == string_start
                pos = pos + 1;
            elseif length(source_code) > pos && any(strcmp(source_code(pos+1), quotes))
                pos = pos + 2;
            else % any(strcmp(source_code(pos), quotes))
                pos = pos + 1;
                break;
            end
        end
        string = source_code(string_start:pos-1);
    end

    function string = skip_block_comment()
    %SKIP_block_comment skips to the end of the block comment and returns
    %   the whole multi-line block comment as STRING.
    %   this modifies POS!

        block_start = pos;
        is_first_statement = false;
        while pos <= length(source_code)
            % line break:
            if any(source_code(pos) == sprintf('\n\r'))
                is_first_statement = true;
            % don't change `is_first_statement` while skipping spaces:
            elseif any(source_code(pos) == sprintf('\t '))
                % nothing changes
            % block comment ends must be alone on the line:
            elseif source_code(pos) == '%' && is_first_statement && ...
                   pos < length(source_code) && source_code(pos+1) == '}'
                pos = pos + 2;
                break
            % any other character is just part of the comment:
            else
                is_first_statement = false;
            end
            pos = pos + 1;
        end
        string = source_code(block_start:pos-1);
    end

    function parse_command()
    %PARSE_COMMAND parses to the end of a command, and appends all args
    %   to the token list.
    %   this modifies POS and TOKENLIST!

        while pos < length(source_code)
            letter = source_code(pos);
            % commands can contain literal strings:
            if any(strcmp(letter, quotes))
                string_literal = skip_string();
                add_token('string', string_literal);
            % commands can contain spaces:
            elseif any(letter == spaces)
                symbol = skip(spaces);
                add_token('space', symbol);
            % commands end at `\n`, `%`, `,`, or `;`:
            elseif any(letter == [breaks '%,;'])
                break
            % any other non-space sequence is interpreted as a string:
            else
                str = skip_unless([breaks spaces '%,;']);
                add_token('string', str);
            end
        end
    end
end
