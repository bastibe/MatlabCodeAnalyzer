function blocks = analyze_file(filename, tokenlist)
%ANALYZE_FILE analyzes TOKENLIST and extracts information about BLOCKS
%   in FILENAME. TOKENLIST is assumed to be the content of FILENAME.
%
%   Returns a struct array with fields:
%   - name: the function name
%   - body: the tokens that make up the body of the function
%   - nesting: how deeply is this block nested within other blocks
%   - children: other blocks nested within this block
%               (again as a struct array)
%   - variables: variables defined in this block, or properties if the
%                block is a class.
%   - arguments: function arguments of this block (if a function)
%   - returns: return variable names of this block (if a function)
%   - type: one of 'Function', 'Nested Function', 'Subfunction',
%           'Class', or 'Script'.
%   - filename: the FILENAME.

% (c) 2016, Bastian Bechtold
% This code is licensed under the terms of the BSD 3-clause license

    beginnings = check_settings('beginnings');

    blocks = struct('name', {}, 'body', {}, 'nesting', {}, ...
                    'children', {}, 'variables', {}, ...
                    'arguments', {}, 'returns', {}, ...
                    'type', {}, 'filename', {});
    function_stack = struct('start', {}, 'nesting', {}, 'children', {});
    nesting = 0;
    is_first_block = true;
    main_type = '';
    for current_pos = 1:length(tokenlist)
        current_token = tokenlist(current_pos);

        % count the 'end's to figure out function extents:
        if current_token.isEqual('keyword', beginnings)
            nesting = nesting + 1;
        elseif current_token.isEqual('keyword', 'end')
            nesting = nesting - 1;
        end

        % determine file type (Script, Function, or Class):
        if isempty(main_type) && ...
           ~current_token.hasType({'newline', 'comment'})
            if current_token.isEqual('keyword', 'function')
                main_type = 'Function';
            elseif current_token.isEqual('keyword', 'classdef')
                main_type = 'Class';
            else
                main_type = 'Script';
            end
        end

        % pre-compute intermediate values for better readability:
        is_end_of_block = current_token.isEqual('keyword', 'end') && ...
                          ~isempty(function_stack) && ...
                          nesting == function_stack(end).nesting;
        is_end_of_function_file = current_pos == length(tokenlist) && ...
                                  ~isempty(function_stack);
        is_end_of_other_file = current_pos == length(tokenlist) && ...
                               any(strcmp(main_type, {'Script' 'Class'}));

        % build a stack of function definitions:
        % We don't know where these functions end, yet. As soon as we
        % know the end, it will get appended to the block list. For
        % now, only record where the function starts.
        if current_token.isEqual('keyword', 'function')
            % include any leading space in the function body, so that
            % later analysis steps can figure out the initial
            % indentation of the function:
            if current_pos > 1 && tokenlist(current_pos-1).hasType('space')
                function_start = current_pos - 1;
            else
                function_start = current_pos;
            end

            % save the new function on the function stack:
            stack_frame = struct('start', function_start, ...
                                 'nesting', nesting-1, ...
                                 'children', []);
            function_stack = [function_stack stack_frame]; %#ok

        elseif is_end_of_block || is_end_of_function_file
            function_body = ...
                tokenlist(function_stack(end).start:current_pos);

            % determine function type (Top-Level, Nested, or Subfunction):
            if nesting > 0 && current_pos ~= length(tokenlist)
                block_type = 'Nested Function';
            elseif is_first_block
                block_type = main_type;
                is_first_block = false;
            else
                block_type = 'Subfunction';
            end

            % build block struct:
            new_block = struct( ...
                'name', get_funcname(function_body), ...
                'body', function_body, ...
                'nesting', function_stack(end).nesting, ...
                'children', function_stack(end).children, ...
                'variables', {get_funcvariables(function_body)}, ...
                'arguments', {get_funcarguments(function_body)}, ...
                'returns', {get_funcreturns(function_body)}, ...
                'type', block_type, 'filename', filename);

            % update function stack with new block struct:
            function_stack(end) = [];
            if nesting > 0 && ~isempty(function_stack)
                if isempty(function_stack(end).children)
                    function_stack(end).children = new_block;
                else
                    function_stack(end).children = ...
                        [function_stack(end).children new_block];
                end
            else
                blocks = [blocks new_block]; %#ok
            end

        elseif is_end_of_other_file
            % in classes, variables contains properties:
            if strcmp(main_type, 'Script')
                variables = {get_variables(tokenlist)};
            else
                variables = {get_properties(tokenlist)};
            end
            blocks = struct('name', Token('special', filename, 0, 0), ...
                            'body', tokenlist, ...
                            'nesting', 0, ...
                            'children', blocks, ...
                            'variables', variables, ...
                            'arguments', [], ...
                            'returns', [], ...
                            'type', main_type, ...
                            'filename', filename);
        end
    end
end


function variables = get_properties(tokenlist)
%GET_PROPERTIES extracts all assigned property VARIABLES from TOKENLIST
%   returns an object array of Tokens.

    variables = Token.empty;
    in_properties = false; % true whenever the loop is inside a properties
                           % block.
    is_first = false; % true whenever the loop is between a line break and
                      % the beginning of the line's content.
    for pos = 1:length(tokenlist)
        token = tokenlist(pos);
        if token.isEqual('keyword', 'properties')
            in_properties = true;
            is_first = false;
        elseif in_properties && token.isEqual('keyword', 'end')
            in_properties = false;
        end
        if token.hasType('linebreak')
            is_first = true;
        elseif token.hasType('identifier') && is_first && in_properties
            variables = [variables token]; %#ok
            is_first = false;
        end
    end
end


function variables = get_funcvariables(tokenlist)
%GET_FUNCVARIABLES extracts all assigned VARIABLES from TOKENLIST
%
% See also: get_variables

    % skip the function declaration:
    end_declaration = search_token('pair', ')', tokenlist, 1, +1);
    variables = get_variables(tokenlist(end_declaration+1:end));
end


function variables = get_variables(tokenlist)
%GET_VARIABLES extracts all assigned VARIABLES from TOKENLIST
%   Variables are things on the left hand side of equal signs which are not
%   enclosed in braces.

    variables = containers.Map();
    for token_idx = 1:length(tokenlist)
        token = tokenlist(token_idx);
        if token.isEqual('punctuation', '=')
            start = search_token('linebreak', [], tokenlist, token_idx, -1);
            lhs_tokens = tokenlist(start:token_idx);
            % all non-nested identifiers are assigned variable names
            nesting = 0;
            for this_token = lhs_tokens
                if this_token.isEqual('pair', {'{' '('})
                    nesting = nesting + 1;
                elseif this_token.isEqual('pair', {'}' ')'})
                    nesting = nesting - 1;
                elseif this_token.hasType('identifier') && ...
                       nesting == 0 && ...
                       ~variables.isKey(this_token.text)
                    variables(this_token.text) = this_token;
                end
            end
        end
    end
    variables = variables.values();
    variables = [variables{:}]; % convert to object array
    if ~isempty(variables)
        % sort by column:
        [~, sort_idx] = sort([variables.col]);
        variables = variables(sort_idx);
        % sort by line (this preserves column ordering for variables
        % on the same line):
        [~, sort_idx] = sort([variables.line]);
        variables = variables(sort_idx);
    end
end


function name = get_funcname(tokenlist)
%GET_FUNCNAME analyzes TOKENLIST to find function name
%   NAME is a Token

    pos = search_token('pair', '(', tokenlist, 1, +1);
    pos = search_token('identifier', [], tokenlist, pos, -1);
    name = tokenlist(pos);
end


function arguments = get_funcarguments(tokenlist)
%GET_FUNCARGUMENTS analyzes TOKENLIST to find function return values
%   ARGUMENTS is an object array of Tokens.

    start = search_token('pair', '(', tokenlist, 1, +1);
    stop = search_token('pair', ')', tokenlist, start, +1);
    arguments = tokenlist(start+1:stop-1);
    % extract all identifiers:
    arguments = arguments(strcmp({arguments.type}, 'identifier'));
end


function returns = get_funcreturns(tokenlist)
%GET_FUNCRETURNS analyzes TOKENLIST to find function return values
%   RETURNS is an object array of Tokens.

    start = search_token('keyword', 'function', tokenlist, 1, +1);
    pos = search_token('pair', '(', tokenlist, start, +1);
    stop = search_token('identifier', [], tokenlist, pos, -1);
    returns = tokenlist(start+1:stop-1);
    % extract all identifiers:
    returns = returns(strcmp({returns.type}, 'identifier'));
end


function token_idx = search_token(token_type, token_text, tokenlist, token_idx, increment)
%SEARCH_TOKEN search TOKENLIST for token with TOKEN_TYPE and TOKEN_TEXT
%   starting from TOKEN_IDX and stepping with INCREMENT.
%
%   To search for any Token with a given TOKEN_TYPE, leave TOKEN_TEXT empty
%   To search for any Token with a given TOKEN_TEXT, leave TOKEN_TYPE empty
%   Set INCREMENT to 1 for forward searching and -1 for backward searching
%
%   Returns the TOKEN_IDX of the first matching token.

    if ~isempty(token_type) && ~isempty(token_text)
        while ~tokenlist(token_idx).isEqual(token_type, token_text)
            if token_idx + increment < 1 || ...
               token_idx + increment > length(tokenlist)
                break
            end
            token_idx = token_idx + increment;
        end
    elseif ~isempty(token_text)
        while ~tokenlist(token_idx).hasText(token_text)
            if token_idx + increment < 1 || ...
               token_idx + increment > length(tokenlist)
                break
            end
            token_idx = token_idx + increment;
        end
    elseif ~isempty(token_type)
        while ~tokenlist(token_idx).hasType(token_type)
            if token_idx + increment < 1 || ...
               token_idx + increment > length(tokenlist)
                break
            end
            token_idx = token_idx + increment;
        end
    end
end
