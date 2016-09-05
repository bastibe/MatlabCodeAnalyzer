function check(filename)
    %CHECK a source file for problems

    [requiredFiles, requiredProducts] = ...
        matlab.codetools.requiredFilesAndProducts(filename);
    % manually fetch file name, since checkcode won't do it correctly
    fullfilename = which(filename);
    mlintInfo = checkcode(fullfilename, '-cyc', '-id', '-struct' ,'-fullpath');

    text = fileread(filename);
    tokens = tokenize_code(text);
    func_report = analyze_file(fullfilename, tokens);

    fprintf('Code Analysis for <strong>%s</strong>\n\n', filename);

    fprintf('  Depends upon: ');
    for idx=1:length(requiredFiles)
        [~, basename, ext] = fileparts(requiredFiles{idx});
        fprintf('%s%s', basename, ext);
        if idx < length(requiredFiles)
            fprintf(', ');
        else
            fprintf('\n');
        end
    end

    fprintf('  Depends upon: ');
    for idx=1:length(requiredProducts)
        fprintf('%s%s', requiredProducts(idx).Name);
        if idx < length(requiredProducts)
            fprintf(', ');
        else
            fprintf('\n\n');
        end
    end

    for func=func_report
        print_func_report(func, mlintInfo, 2);
    end
end


function print_func_report(func, mlintInfo, indentation)
    prefix = repmat(' ', 1, indentation);
    fprintf('%s%s <strong>%s</strong> (<a href="%s">Line %i, col %i</a>): ', ...
            prefix, func.type, func.name.text, ...
            open_file_link(func.filename, func.name.line), ...
            func.name.line, func.name.col);
    fprintf('\n\n');

    if any(strcmp(func.type, {'Function', 'Subfunction', 'Nested Function'}))
        stats = get_function_stats(func, mlintInfo);
        print_function_stats(stats, indentation+2);
        fprintf('\n');
    elseif strcmp(func.type, 'Class')
        stats = get_class_stats(func);
        print_class_stats(stats, indentation+2);
        fprintf('\n');
    elseif strcmp(func.type, 'Script')
        stats = get_script_stats(func);
        print_script_stats(stats, indentation+2);
        fprintf('\n');
    end

    if any(strcmp(func.type, {'Function', 'Subfunction', 'Nested Function'}))
        reports = [check_variables(func.name, func.body, 'function') ...
                   check_documentation(func) ...
                   check_comments(func.body) ...
                   check_mlint_warnings(mlintInfo, func.body) ...
                   check_indentation(func) ...
                   check_line_length(func.body) ...
                   check_variables(func.arguments, func.body, 'function argument') ...
                   check_variables(func.returns, func.body, 'return argument') ...
                   check_variables(func.variables, func.body, 'variable') ...
                   check_operators(func.body) ...
                   check_eval(func.body)];
    else
         reports = [check_documentation(func) ...
                    check_comments(func.body) ...
                    check_mlint_warnings(mlintInfo, func.body) ...
                    check_indentation(func) ...
                    check_line_length(func.body) ...
                    check_variables(func.variables, func.body, 'variable') ...
                    check_operators(func.body) ...
                    check_eval(func.body)];
    end
    if ~isempty(reports)
        % First, secondary sort by column
        report_tokens = [reports.token];
        [~, sort_idx] = sort([report_tokens.col]);
        reports = reports(sort_idx);
        % Second, primary sort by line (preserves secondary
        % sorting order in case of collisions)
        report_tokens = [reports.token];
        [~, sort_idx] = sort([report_tokens.line]);
        reports = reports(sort_idx);
        print_report(reports, indentation+2, func.filename);
    end

    fprintf('\n\n');

    for subfunc=func.children
        print_func_report(subfunc, mlintInfo, indentation+4)
    end
end


function stats = get_class_stats(func)
    stats.num_lines = length(split_lines(func.body));
    stats.num_properties = length(func.variables);
    stats.num_methods = length(func.children);
end


function print_class_stats(stats, indentation)
    prefix = repmat(' ', 1, indentation);

    fprintf('%sNumber of lines: ', prefix);
    print_evaluation(stats.num_lines, ...
                     check_settings('lo_class_num_lines'), ...
                     check_settings('hi_class_num_lines'));

    fprintf('%sNumber of properties: ', prefix);
    print_evaluation(stats.num_properties, ...
                     check_settings('lo_class_num_properties'), ...
                     check_settings('hi_class_num_properties'));

    fprintf('%sNumber of methods: ', prefix);
    print_evaluation(stats.num_methods, ...
                     check_settings('lo_class_num_methods'), ...
                     check_settings('hi_class_num_methods'));
end


function stats = get_script_stats(func)
    stats.num_lines = length(split_lines(func.body));
    stats.num_variables = length(func.variables);
end


function print_script_stats(stats, indentation)
    prefix = repmat(' ', 1, indentation);

    fprintf('%sNumber of lines: ', prefix);
    print_evaluation(stats.num_lines, ...
                     check_settings('lo_script_num_lines'), ...
                     check_settings('hi_script_num_lines'));

    fprintf('%sNumber of variables: ', prefix);
    print_evaluation(stats.num_variables, ...
                     check_settings('lo_script_num_variables'), ...
                     check_settings('hi_script_num_variables'));
end


function stats = get_function_stats(func, mlintInfo)
    stats.num_lines = length(split_lines(func.body));
    stats.num_arguments = length(func.arguments);
    stats.num_variables = length(func.variables);

    % max indentation
    keywords = func.body(strcmp({func.body.type}, 'keyword'));
    indentation = 1;
    max_indentation = 0;
    for keyword=keywords
        if keyword.hasText({'if' 'for' 'parfor' 'while' 'switch'})
            indentation = indentation + 1;
            max_indentation = max(max_indentation, indentation);
        elseif keyword.hasText('end')
            indentation = indentation - 1;
        end
    end
    stats.max_indentation = max_indentation;

    % cyclomatic complexity
    mlintInfo = mlintInfo(strcmp({mlintInfo.id}, 'CABE'));
    mlintInfo = mlintInfo([mlintInfo.line] == func.body(1).line);
    assert(length(mlintInfo) == 1);
    pattern = 'The McCabe complexity of ''(?<f>[^'']+)'' is (?<n>[0-9]+)';
    matches = regexp(mlintInfo.message, pattern, 'names');
    stats.complexity = str2num(matches.n);
end


function print_function_stats(stats, indentation)
    prefix = repmat(' ', 1, indentation);

    fprintf('%sNumber of lines: ', prefix);
    print_evaluation(stats.num_lines, ...
                     check_settings('lo_function_num_lines'), ...
                     check_settings('hi_function_num_lines'));

    fprintf('%sNumber of function arguments: ', prefix);
    print_evaluation(stats.num_arguments, ...
                     check_settings('lo_function_num_arguments'), ...
                     check_settings('hi_function_num_arguments'));

    fprintf('%sNumber of used variables: ', prefix);
    print_evaluation(stats.num_variables, ...
                     check_settings('lo_function_num_variables'), ...
                     check_settings('hi_function_num_variables'));

    fprintf('%sMax level of nesting: ', prefix);
    print_evaluation(stats.max_indentation, ...
                     check_settings('lo_function_max_indentation'), ...
                     check_settings('hi_function_max_indentation'));

    fprintf('%sCyclomatic complexity: ', prefix);
    print_evaluation(stats.complexity, ...
                     check_settings('lo_function_complexity'), ...
                     check_settings('hi_function_complexity'));
end


function print_evaluation(value, low_thr, high_thr)
%PRINT_EVALUATION prints an evaluation of VALUE.
%   LOW_THR and HIGH_THR mark thresholds, above which the value is
%   described as "(good)" -> "(high)" -> "(too high)" in red

    if value < low_thr
        fprintf('%i (good)\n', value);
    elseif value < high_thr
        fprintf('%i (high)\n', value);
    else
        fprintf('%i [\b(too high)]\b\n', value);
    end
end


function print_report(report, indentation, filename)
%PRINT_REPORT prints the contents of REPORT at INDENTATION. Each REPORT
%   item is written as a link to the appropriate place in FILENAME.

    prefix = repmat(' ', 1, indentation);

    for report_entry = report
        % print severe report_entrys in red:
        % red text is created by surrounding it with `[<backspace>` and
        % `]<backspace>`. The `<backspace>` will delete the preceding
        % bracket and not show up in the text itself, but it will be
        % interpreted as a flag to change the text color. This is an
        % ancient ASCII convention.
        if report_entry.severity == 2
            fprintf('%s<a href="%s">Line %i, col %i</a>: [\b%s]\b\n', ...
                    prefix, ...
                    open_file_link(filename, report_entry.token.line), ...
                    report_entry.token.line, ...
                    report_entry.token.col, ...
                    report_entry.message);

        % print regular report_entrys in black:
        else
            fprintf('%s<a href="%s">Line %i, col %i</a>: %s\n', ...
                    prefix, ...
                    open_file_link(filename, report_entry.token.line), ...
                    report_entry.token.line, ...
                    report_entry.token.col, ...
                    report_entry.message);
        end
    end
end


function report = check_comments(tokenlist)
%CHECK_COMMENTS REPORTs on the number of comments in TOKENLIST.
%
%   Comments should not describe the code itself, but provide context
%   for reading the code. In other words, they should describe the
%   *why*, not the *what.
%
%   returns a struct array REPORT with fields `token`, `message`, and
%   `severity`.
%
%   This check can be switched off by setting `do_check_comments` in
%   CHECK_SETTINGS to FALSE.

    report = struct('token', {}, 'severity', {}, 'message', {});
    if ~check_settings('do_check_comments')
        return
    end

    linelist = split_lines(tokenlist);
    num_lines = length(linelist);
    num_comments = 0;
    for line_idx = 1:length(linelist)
        line_tokens = linelist{line_idx};
        if any(strcmp({line_tokens.type}, 'comment'))
            num_comments = num_comments + 1;
        end
    end

    usage = sprintf('(%i comments for %i lines of code)', ...
                    num_comments, num_lines);
    if num_comments/num_lines < 0.1
        report = struct('token', tokenlist(1), ...
                        'severity', 2, ...
                        'message', ['too few comments ' usage]);
    elseif num_comments/num_lines < 0.2
        report = struct('token', tokenlist(1), ...
                        'severity', 1, ...
                        'message', ['very few comments ' usage]);
    end
end


function report = check_documentation(func_struct)
%CHECK_DOCUMENTATION REPORTs on problems with the documentation of the
%   function in FUNC_STRUCT.
%
%   Documentation is very important for humans. Code is not primarily
%   written for the machine to execute, but mostly for humans to read.
%   But many ideas are more efficiently described in prose than in code,
%   hence we write documentation. Functions in particular should always
%   be documented.
%
%   Problems might be:
%   - the function name is not mentioned in the documentation
%   - the function arguments are not mentioned
%   - the function return values are not mentioned
%   - there is no documentation
%
%   returns a struct array REPORT with fields `token`, `message`, and
%   `severity`.
%
%   This check can be switched off by setting `do_check_documentation` in
%   CHECK_SETTINGS to FALSE.

    report = struct('token', {}, 'severity', {}, 'message', {});
    if ~check_settings('do_check_documentation')
        return
    end

    doc_text = get_function_documentation(func_struct.body);
    if isempty(doc_text)
        msg = 'there is no documentation';
        report = [report struct('token', func_struct.body(1), ...
                                'severity', 2, ...
                                'message', msg)];
        return
    end
    template = '%s ''%s'' is not mentioned in the documentation';
    if isempty(strfind(lower(doc_text), lower(func_struct.name.text)))
        msg = sprintf(template, 'function name', func_struct.name.text);
        report = [report struct('token', func_struct.name, ...
                                'severity', 2, ...
                                'message', msg)];
    end
    for variable = func_struct.arguments
        if isempty(strfind(lower(doc_text), lower(variable.text)))
            msg = sprintf(template, 'function argument', variable.text);
            report = [report struct('token', variable, ...
                                    'severity', 2, ...
                                    'message', msg)]; %#ok
        end
    end
    for variable = func_struct.returns
        if isempty(strfind(lower(doc_text), lower(variable.text)))
            msg = sprintf(template, 'return argument', variable.text);
            report = [report struct('token', variable, ...
                                    'severity', 2, ...
                                    'message', msg)]; %#ok
        end
    end
end


function doc_text = get_function_documentation(tokenlist)
%GET_FUNCTION_DOCUMENTATION extracts function documentation from TOKENLIST
%
%   returns DOC_TEXT as a string

    % skip function declaration
    token_idx = 1;
    while token_idx <= length(tokenlist) && ...
          ~tokenlist(token_idx).isEqual('pair', ')')
        token_idx = token_idx + 1;
    end
    token_idx = token_idx + 2;

    % find documentation
    doc_types = {'comment' 'space' 'linebreak'};
    start = token_idx;
    while token_idx <= length(tokenlist) && ...
          tokenlist(token_idx).hasType(doc_types)
        token_idx = token_idx + 1;
    end

    % extract documentation text
    comment_tokens = tokenlist(start:token_idx-1);
    comment_tokens = ...
        comment_tokens(strcmp({comment_tokens.type}, 'comment'));
    doc_text = [comment_tokens.text];
end


function report = check_eval(tokenlist)
%CHECK_EVAL REPORTs on uses of `eval` in TOKENLIST.
%
%   Using `eval` is *never* the right thing to do. There is *always*
%   a better way. Seriously.
%
%   returns a struct array REPORT with fields `token`, `message`, and
%   `severity`.
%
%   This check can be switched off by setting `do_check_eval` in
%   CHECK_SETTINGS to FALSE.

    report = struct('token', {}, 'severity', {}, 'message', {});
    if ~check_settings('do_check_eval')
        return
    end

    eval_tokens = tokenlist(strcmp({tokenlist.text}, 'eval') & ...
                            strcmp({tokenlist.type}, 'identifier'));
    for t = eval_tokens
        msg = 'Eval should never be used';
        report = [report struct('token', t, ...
                                'severity', 2, ...
                                'message', msg)]; %#ok
    end
end


function report = check_operators(tokenlist)
%CHECK_OPERATORS reports on incorrectly used operators in TOKENLIST
%
%   To improve readability, operators should be treated like punctuation
%   in regular English, i.e. be preceded and followed by spaces just like
%   in English and math. In particular:
%   - relational operators such as `>`, `<`, `==`, `~=`, `<=`, `>=`, `=`,
%     `||`, and `&&` should be surrounded by spaces.
%   - punctuation such as `,` and `;` should be followed by a space.
%   - unary operators such as `@` and `...` should be preceded by a space.
%
%   returns a struct array REPORT with fields `token`, `message`, and
%   `severity`.
%
%   This check can be switched off by setting `do_check_operators` in
%   CHECK_SETTINGS to FALSE.

    report = struct('token', {}, 'severity', {}, 'message', {});
    if ~check_settings('do_check_operators')
        return
    end

    space_around_operators = { '>' '<' '==' '>=' '<=' '~=' ...
                               '=' '||' '&&'};
    space_after_operators = { ',' ';' };
    space_before_operators = { '@' '...' };

    op_indices = find(strcmp({tokenlist.type}, 'punctuation'));
    for op_idx = op_indices
        has_space_before = op_idx > 1 && ...
                           tokenlist(op_idx-1).hasType('space');
        has_space_after = op_idx < length(tokenlist) && ...
                          tokenlist(op_idx+1).hasType('space');
        has_newline_after = op_idx < length(tokenlist) && ...
                            tokenlist(op_idx+1).hasText(sprintf('\n'));
        if tokenlist(op_idx).hasText(space_around_operators) && ...
           (~has_space_before || ~has_space_after)
            msg = sprintf('no spaces around operator ''%s''', ...
                          tokenlist(op_idx).text);
            report = [report struct('token', tokenlist(op_idx), ...
                                    'severity', 1, ...
                                    'message', msg)]; %#ok
        elseif tokenlist(op_idx).hasText(space_after_operators) && ...
               ~has_space_after && ~has_newline_after
            msg = sprintf('no spaces after operator ''%s''', ...
                          tokenlist(op_idx).text);
            report = [report struct('token', tokenlist(op_idx), ...
                                    'severity', 1, ...
                                    'message', msg)]; %#ok
        elseif tokenlist(op_idx).hasText(space_before_operators) && ...
               ~has_space_before
            msg = sprintf('no spaces before operator ''%s''', ...
                          tokenlist(op_idx).text);
            report = [report struct('token', tokenlist(op_idx), ...
                                    'severity', 1, ...
                                    'message', msg)]; %#ok
        end
    end
end


function report = check_variables(varlist, tokenlist, description)
%CHECK_VARIABLES checks all variables in VARLIST, as used in TOKENLIST,
%   and REPORTs on problems with these variables. DESCRIPTION is used
%   to describe the variable in REPORT.
%
%   Problems with variables can be:
%   - The variable shadows a built-in
%   - The variable has a very short name and is used very often.
%
%   In general, variable name lengths should correlate with the amount
%   of code they are used in. If variables are used over a long piece
%   of code, the programmer will stumble across the variable often,
%   and it should have a descriptive name. Short variable names are
%   only allowed if they are ephemeral, such as loop counters in small
%   loops. There, they don't need to be remembered for long, thus a short
%   name is permissible.
%
%   returns a struct array REPORT with fields `token`, `message`, and
%   `severity`.
%
%   This check can be switched off by setting `do_check_variables` in
%   CHECK_SETTINGS to FALSE.

    report = struct('token', {}, 'severity', {}, 'message', {});
    if ~check_settings('do_check_variables')
        return
    end

    for variable = varlist
        if does_shadow(variable.text)
            msg = sprintf('%s ''%s'' shadows a built-in', ...
                          description, variable.text);
            report = [report struct('token', variable, ...
                                    'severity', 2, ...
                                    'message', msg)]; %#ok
        end
        [numuses, spread] = get_variable_usage(variable.text, tokenlist);
        usage_descr = sprintf('(used %i times across %i lines)', ...
                              numuses, spread);
        varlen = length(variable.text);

        short_spread = check_settings('lo_varname_short_spread');
        short_length = check_settings('lo_varname_short_length');
        long_spread = check_settings('lo_varname_long_spread');
        long_length = check_settings('lo_varname_long_length');
        slightly_too_short = ...
            (spread > short_spread && varlen <= short_length) || ...
            (spread > long_spread && varlen <= long_length);

        short_spread = check_settings('hi_varname_short_spread');
        short_length = check_settings('hi_varname_short_length');
        long_spread = check_settings('hi_varname_long_spread');
        long_length = check_settings('hi_varname_long_length');
        much_too_short = ...
            (spread > short_spread && varlen <= short_length) || ...
            (spread > long_spread && varlen <= long_length);


        if slightly_too_short
            msg = sprintf('%s ''%s'' is very short %s', ...
                          description, variable.text, usage_descr);
            report = [report struct('token', variable, ...
                                    'severity', 1, ...
                                    'message', msg)]; %#ok
        elseif much_too_short
            msg = sprintf('%s ''%s'' is too short %s', ...
                          description, variable.text, usage_descr);
            report = [report struct('token', variable, ...
                                    'severity', 2, ...
                                    'message', msg)]; %#ok
        end
    end
end


function [numuses, linerange] = get_variable_usage(varname, tokenlist)
%GET_VARIABLE_USAGE finds all uses of variable VARNAME in TOKENLIST
%   Returns the number of uses NUMUSES and the range of lines LINERANGE
%   in which the variable is used.

    uses = tokenlist(strcmp({tokenlist.text}, varname) & ...
                     strcmp({tokenlist.type}, 'identifier'));
    numuses = length(uses);
    linelist = [uses.line];
    linerange = max(linelist)-min(linelist);
end


function report = check_mlint_warnings(mlint_info, tokenlist)
%CHECK_MLINT_WARNINGS reads through MLINT_INFO and REPORTs on all messages
%   that refer to the code in TOKENLIST.
%
%   returns a struct array REPORT with fields `token`, `message`, and
%   `severity`.
%
%   This check can be switched off by setting `do_check_mlint_warnings` in
%   CHECK_SETTINGS to FALSE.

    report = struct('token', {}, 'severity', {}, 'message', {});
    if ~check_settings('do_check_mlint_warnings')
        return
    end

    mlint_info = mlint_info([mlint_info.line] >= tokenlist(1).line);
    mlint_info = mlint_info([mlint_info.line] <= tokenlist(end).line);
    mlint_info = mlint_info(~strcmp({mlint_info.id}, 'CABE'));
    if isempty(mlint_info)
        return
    end
    for idx = 1:length(mlint_info)
        mlint_msg = mlint_info(idx);
        token = Token('special', 'mlint warning', ...
                      mlint_msg.line, mlint_msg.column(1));
        report = [report struct('token', token, ...
                                'severity', 2, ...
                                'message', mlint_msg.message)]; %#ok
    end
end


function is_builtin = does_shadow(varname)
%DOES_SHADOW figures out if variable with name VARNAME shadows a built-in
%   function or variable.
%
%   returns a boolean IS_BUILTIN.

    if any(exist(varname) == [2 3 4 5 6 8]) %#ok
        % now we know that something with name `varname` exists. But is it
        % a built-in, or something I wrote?
        % `which` can tell, in one of three spellings:
        shadows = which(varname, '-all');
        builtinfun = 'is a built-in method';
        builtinstr = 'built-in';
        for idx = 1:length(shadows)
            shadow = shadows{idx};
            if ( length(shadow) >= length(matlabroot) && ...
                 strcmp(shadow(1:length(matlabroot)), matlabroot) ) || ...
               ( length(shadow) >= length(builtinstr) && ...
                 strcmp(shadow(1:length(builtinstr)), builtinstr) ) || ...
               ( length(shadow) >= length(builtinfun) && ...
                 strcmp(shadow(end-length(builtinfun)+1:end), builtinfun) )
                is_builtin = true;
                return
            end
        end
    end
    is_builtin = false;
end


function report = check_line_length(tokenlist)
%CHECK_LINE_LENGTH walks through TOKENLIST and REPORTs on the length of
%   all lines.
%
%   While line length should not matter with today's high-resolution
%   displays, it is still useful to limit line lengths in order to be
%   able to fit several editor panes next to one another, or to be able
%   print the source code.
%
%   - By default, lines longer than 75 characters are flagged
%     as `very long`, and
%   - lines longer than 90 characters are flagged as `too long`.
%
%   returns a struct array REPORT with fields `token`, `message`, and
%   `severity`.
%
%   This check can be switched off by setting `do_check_line_length` in
%   CHECK_SETTINGS to FALSE.

    report = struct('token', {}, 'message', {}, 'severity', {});
    if ~check_settings('do_check_line_length')
        return
    end
    lo_line_length = check_settings('lo_line_length');
    hi_line_length = check_settings('hi_line_length');

    linelist = split_lines(tokenlist);
    for line_idx = 1:length(linelist)
        line_tokens = linelist{line_idx};
        line_text = [line_tokens.text];
        if length(line_text) > lo_line_length
            report_token = Token('special', 'line warning', ...
                                 line_tokens(1).line, ...
                                 length(line_text));
            report = [report struct('token', report_token, ...
                                    'message', 'line very long', ...
                                    'severity', 1)]; %#ok
        elseif length(line_text) > hi_line_length
            report_token = Token('special', 'line warning', ...
                                 line_tokens(1).line, ...
                                 length(line_text));
            report = [report struct('token', report_token, ...
                                    'message', 'line too long', ...
                                    'severity', 2)]; %#ok
        end
    end
end


function report = check_indentation(func_struct)
%CHECK_INDENTATION parses FUNC_STRUCT and REPORTs about its indentation.
%
%   Indentation is one of the primary means of making code easy to read,
%   by highlighting the structure of the code. If code is not indented
%   correctly, it can be hard to see where where nested blocks (if, for,
%   etc.) begin and end.
%
%   The first line is assumed to be indented correctly, and subsequent
%   indentation follows the normal MATLAB indentation rules:
%
%   - Indent after `for`, `parfor`, `while`, `if`, `switch`, `classdef`,
%                  `events`, `properties`, `enumeration`, `methods`,
%                  `function`.
%   - Dedent for `end`
%   - Dedent momentarily for `else`, `elseif`, `case`.
%   - Comments are allowed to be indented one level out, and any amount of
%     deeper indentation than the source code.
%   - Continuation lines must be indented deeper than the surrounding
%     source code.
%
%   returns a struct array REPORT with fields `token`, `message`, and
%   `severity`.
%
%   This check can be switched off by setting `do_check_indentation` in
%   CHECK_SETTINGS to FALSE.
%
%   The setting `indentation_check_like_matlab` controls whether
%   indentation should be checked like MATLAB does it (top-level function
%   bodies are not indented in function files) or how every other language
%   on this planet does it (function bodies are always indented).

    report = struct('token', {}, 'message', {}, 'severity', {});
    if ~check_settings('do_check_indentation')
        return
    end

    linelist = split_lines(func_struct.body);

    nesting = func_struct.nesting;
    function_nesting = func_struct.nesting;

    for line_idx = 1:length(linelist)
        line_tokens = linelist{line_idx};
        is_continuation = is_continuation_line(line_idx, linelist);

        if isempty(line_tokens)
            continue
        end

        first_nonspace = get_first_nonspace(line_tokens);


        if ~is_continuation
            [nesting, function_nesting, correction] = ...
               indentation_rule(nesting, function_nesting, first_nonspace);
        end

        increment = check_settings('indentation_step');
        expected_indent = (nesting+correction) * increment;
        expected_indent = max(expected_indent, 0);

        current_indent = get_line_indentation(line_tokens);

        incorrect_comment = ...
            first_nonspace.hasType('comment') && ...
            ~(current_indent >= expected_indent) && ...
            current_indent ~= expected_indent-increment;
        incorrect_normal_line = ...
            ~first_nonspace.hasType('comment') && ...
            ~is_continuation && ...
            current_indent ~= expected_indent;
        incorrect_continuation_line = ...
            ~first_nonspace.hasType('comment') && ...
            is_continuation && ...
            current_indent <= expected_indent;

        if incorrect_comment || incorrect_normal_line || ...
           incorrect_continuation_line
            report_token = Token('special', 'indentation warning', ...
                             line_tokens(1).line, line_tokens(1).col);
            report_entry = struct('token', report_token, ...
                                  'message', 'incorrect indentation', ...
                                  'severity', 2);
            report = [report report_entry]; %#ok
        end
    end
end


function yesNo = is_continuation_line(line_idx, linelist)
%IS_CONTINUATION_LINE checks if LINELIST{LINE_IDX} is a continuation
%   of the previous line. YESNO is a boolean.

    if line_idx > 1
        previous_line = linelist{line_idx-1};
        yesNo = any(strcmp({previous_line.text}, '...'));
    else
        yesNo = false;
    end
end


function [nesting, function_nesting, correction] = indentation_rule(nesting, function_nesting, first_token)
%INDENTATION_RULE decides about the indentation of the current line
%   NESTING and FUNCTION_NESTING will change depending on the
%   FIRST_TOKEN on the current line.
%
%   NESTING holds the current nesting within if/for/function blocks and
%   FUNCTION_NESTING holds the current nesting within function blocks.
%   CORRECTION is an offset on NESTING for the current line only.
%
%   In case of scripts and class files, FUNCTION_NESTING is
%   effectively ignored. In case of function files, FUNCTION_NESTING
%   is used to determine whether the current function is a top-level
%   function (whose body should not be indented) or a nested function
%   (whose body should be indented).
%
%   All indentations are given and returned as integer levels of
%   indentation. Depending on your editor setup, one level might correspond
%   to 2, 3, 4, or 8 spaces.
%
%   The correct indentation for the current line is (by default):
%       (nesting + correction)*4 spaces

    beginnings = {'for' 'parfor' 'while' 'if' 'switch' 'classdef' ...
                  'events' 'properties' 'enumeration' 'methods' ...
                  'function'};
    middles = {'else' 'elseif' 'case'};

    % deactivate function file rules in class files:
    if first_token.isEqual('keyword', 'classdef')
        function_nesting = nan;
    end

    if ~check_settings('indentation_check_like_matlab')
        function_nesting = nan;
    end

    % beginning of a function:
    if first_token.isEqual('keyword', 'function')
        function_nesting = function_nesting + 1;
        nesting = nesting + 1;
        correction = -1;
    % any other beginning:
    elseif first_token.isEqual('keyword', beginnings)
        nesting = nesting + 1;
        correction = -1;
    % end of a function in:
    elseif first_token.isEqual('keyword', 'end') && ...
           nesting == function_nesting
        function_nesting = function_nesting - 1;
        nesting = nesting - 1;
        if function_nesting == 1
            correction = +1;
        else
            correction = 0;
        end
    % any other end:
    elseif first_token.isEqual('keyword', 'end')
        nesting = nesting - 1;
        correction = 0;
    % any middle (else, elseif, case):
    elseif first_token.isEqual('keyword', middles)
        correction = -1;
    % a normal line:
    else
        correction = 0;
    end

    % if this is in a top-level function:
    if function_nesting == 1
        correction = correction - 1;
    end
end


function indentation = get_line_indentation(line_tokens)
%GET_LINE_INDENTATION returns the number of spaces at the beginning of
%   LINE_TOKENS. INDENTATION is an integer.

    if ~isempty(line_tokens) && line_tokens(1).hasType('space')
        indentation = length(line_tokens(1).text);
    else
        indentation = 0;
    end
end


function token = get_first_nonspace(tokenlist)
%GET_FIRST_NONSPACE returns the first TOKEN in TOKENLIST that is not a
%   token of type space.
%   This can be useful to return the first "real" token on a line.

    token_idx = 1;
    while token_idx < length(tokenlist) && ...
          tokenlist(token_idx).hasType('space')
        token_idx = token_idx + 1;
    end
    token = tokenlist(token_idx);
end


function linelist = split_lines(tokens)
%SPLIT_LINES splits TOKENS into lines.
%   returns a cell array LINELIST of Token-arrays.

    linelist = {};
    line_start = 1;
    linebreaks = {sprintf('\n'), sprintf('\r\n')};
    for pos = 1:length(tokens)+1
        if pos == length(tokens)+1 || ...
           tokens(pos).isEqual('linebreak', linebreaks)
            linelist = [linelist {tokens(line_start:pos-1)}]; %#ok
            line_start = pos + 1;
        end
    end
end


function link = open_file_link(filename, linenum)
%OPEN_FILE_LINK returns a link target for HTML links
%   the LINK is supposed to be used in <a href="LINK">...</a> links inside
%   MATLAB. It will generate a linke that opens FILENAME at LINENUM in the
%   MATLAB editor.

    prefix = 'matlab.desktop.editor.openAndGoToLine';
    link = sprintf('matlab:%s(''%s'', %i);', prefix, filename, linenum);
end
