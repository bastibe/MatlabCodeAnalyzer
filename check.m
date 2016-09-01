function check(filename)
    %CHECK a source file for problems

    [requiredFiles, requiredProducts] = ...
        matlab.codetools.requiredFilesAndProducts(filename);
    % manually fetch file name, since checkcode won't do it correctly
    fullfilename = which(filename);
    mlintInfo = checkcode(fullfilename, '-cyc', '-id', '-struct' ,'-fullpath');

    text = fileread(filename);
    tokens = tokenize(text);
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

    func_start = func.body(1).line;
    func_end = func.body(end).line;

    if any(strcmp(func.type, {'Function', 'Subfunction', 'Nested Function'}))
        reports = [check_variables(func.name, func.body, 'function') ...
                   check_documentation(func) ...
                   check_comments(func.body) ...
                   check_mlint_warnings(mlintInfo, func_start, func_end) ...
                   check_indentation(func.body) ...
                   check_line_length(func.body) ...
                   check_variables(func.arguments, func.body, 'function argument') ...
                   check_variables(func.returns, func.body, 'return argument') ...
                   check_variables(func.variables, func.body, 'variable') ...
                   check_operators(func.body) ...
                   check_eval(func.body)];
    else
         reports = [check_documentation(func) ...
                    check_comments(func.body) ...
                    check_mlint_warnings(mlintInfo, func_start, func_end) ...
                    check_indentation(func.body) ...
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
    if value < low_thr
        fprintf('%i (good)\n', value);
    elseif value < high_thr
        fprintf('%i (high)\n', value);
    else
        fprintf('%i [\b(too high)]\b\n', value);
    end
end


function print_report(report, indentation, filename)
    prefix = repmat(' ', 1, indentation);

    for item=report
        if item.severity == 2
            fprintf('%s<a href="%s">Line %i, col %i</a>: [\b%s]\b\n', prefix, ...
                    open_file_link(filename, item.token.line), ...
                    item.token.line, item.token.col, item.message);
        else
            fprintf('%s<a href="%s">Line %i, col %i</a>: %s\n', prefix, ...
                    open_file_link(filename, item.token.line), ...
                    item.token.line, item.token.col, item.message);
        end
    end
end


function report = check_comments(tokens)
    report = struct('token', {}, 'severity', {}, 'message', {});
    if ~check_settings('do_check_comments')
        return
    end

    line_tokens = split_lines(tokens);
    num_lines = length(line_tokens);
    num_comments = 0;
    for line=line_tokens
        line = line{1};
        if any(strcmp({line.type}, 'comment'))
            num_comments = num_comments + 1;
        end
    end

    if num_comments/num_lines < 0.1
        msg = sprintf('too few comments (%i comments for %i lines of code)', ...
                      num_comments, num_lines);
        report = struct('token', tokens(1), ...
                        'severity', 2, ...
                        'message', msg);
    elseif num_comments/num_lines < 0.2
        msg = sprintf('very few comments (%i comments for %i lines of code)', ...
                      num_comments, num_lines);
        report = struct('token', tokens(1), ...
                        'severity', 1, ...
                        'message', msg);
    end
end


function report = check_documentation(func)
    report = struct('token', {}, 'severity', {}, 'message', {});
    if ~check_settings('do_check_documentation')
        return
    end

    doc_text = get_function_documentation(func.body);
    if isempty(doc_text)
        report = [report struct('token', func.body(1), ...
                                'severity', 2, ...
                                'message', 'there is no documentation')];
        return
    end
    for var=func.arguments
        if isempty(strfind(doc_text, var.text))
            msg = sprintf('function argument ''%s'' is not mentioned in the documentation', ...
                          var.text);
            report = [report struct('token', var, ...
                                    'severity', 2, ...
                                    'message', msg)];
        end
    end
    for var=func.returns
        if isempty(strfind(doc_text, var.text))
            msg = sprintf('return argument ''%s'' is not mentioned in the documentation', ...
                          var.text);
            report = [report struct('token', var, ...
                                    'severity', 2, ...
                                    'message', msg)];
        end
    end
end


function doc_text = get_function_documentation(tokens)
    % skip function declaration
    idx = 1;
    while idx <= length(tokens) && ~tokens(idx).isEqual('pair', ')')
        idx = idx + 1;
    end
    idx = idx + 1;

    % extract documentation text
    doc_types = {'comment' 'space' 'linebreak'};
    start = idx;
    while idx <= length(tokens) && tokens(idx).hasType(doc_types)
        idx = idx + 1;
    end
    comment_tokens = tokens(start:idx-1);
    comment_tokens = tokens(strcmp({comment_tokens.type}, 'comment'));
    doc_text = horzcat([comment_tokens.text]);
end


function report = check_eval(tokens)
    report = struct('token', {}, 'severity', {}, 'message', {});
    if ~check_settings('do_check_eval')
        return
    end

    eval_tokens = tokens(strcmp({tokens.text}, 'eval') & ...
                         strcmp({tokens.type}, 'identifier'));
    for t = eval_tokens
        report = [report struct('token', t, ...
                                'severity', 2, ...
                                'message', 'Eval should never be used')];
    end
end


function report = check_operators(tokens)
    report = struct('token', {}, 'severity', {}, 'message', {});
    if ~check_settings('do_check_operators')
        return
    end

    space_around_operators = { '>' '<' '==' '>=' '<=' '~=' ...
                               '=' '||' '&&' '|' '&'};
    space_after_operators = { ',' ';' };
    space_before_operators = { '@' '...' };

    op_indices = find(strcmp({tokens.type}, 'punctuation'));
    for idx=op_indices
        has_space_before = idx > 1 && tokens(idx-1).hasType('space');
        has_space_after = idx < length(tokens) && tokens(idx+1).hasType('space');
        has_newline_after = idx < length(tokens) && ...
                            tokens(idx+1).hasText(sprintf('\n'));
        if tokens(idx).hasText(space_around_operators) && ...
           (~has_space_before || ~has_space_after)
           msg = sprintf('no spaces around operator ''%s''', tokens(idx).text);
            report = [report struct('token', tokens(idx), ...
                                    'severity', 1, ...
                                    'message', msg)];
        elseif tokens(idx).hasText(space_after_operators) && ...
               ~has_space_after && ~has_newline_after
            msg = sprintf('no spaces after operator ''%s''', tokens(idx).text);
            report = [report struct('token', tokens(idx), ...
                                    'severity', 1, ...
                                    'message', msg)];
        elseif tokens(idx).hasText(space_before_operators) && ...
               ~has_space_before
            msg = sprintf('no spaces before operator ''%s''', tokens(idx).text);
            report = [report struct('token', tokens(idx), ...
                                    'severity', 1, ...
                                    'message', msg)];
        end
    end
end


function report = check_variables(varlist, scope_tokens, description)
    report = struct('token', {}, 'severity', {}, 'message', {});
    if ~check_settings('do_check_variables')
        return
    end

    for var=varlist
        if does_shadow(var.text)
            msg = sprintf('%s ''%s'' shadows a built-in', description, var.text);
            report = [report struct('token', var, ...
                                    'severity', 2, ...
                                    'message', msg)];
        end
        [usage, spread] = get_variable_usage(var.text, scope_tokens);
        if (spread > 3  && length(var.text) <= 3) || ...
           (spread > 10 && length(var.text) <= 5)
            msg = sprintf('%s ''%s'' is very short (used %i times across %i lines)', ...
                          description, var.text, usage, spread);
            report = [report struct('token', var, ...
                                    'severity', 1, ...
                                    'message', msg)];
        elseif (spread > 5  && length(var.text) <= 3) || ...
               (spread > 15 && length(var.text) <= 5)
            msg = sprintf('%s ''%s'' is too short (used %i times across %i lines)', ...
                          description, var.text, usage, spread);
            report = [report struct('token', var, ...
                                    'severity', 2, ...
                                    'message', msg)];
        end
    end
end


function [usage, spread] = get_variable_usage(name, tokens)
    uses = tokens(strcmp({tokens.text}, name) & ...
                  strcmp({tokens.type}, 'identifier'));
    usage = length(uses);
    lines = [uses.line];
    spread = max(lines)-min(lines);
end


function report = check_mlint_warnings(mlintInfo, func_start, func_stop)
    report = struct('token', {}, 'severity', {}, 'message', {});
    if ~check_settings('do_check_mlint_warnings')
        return
    end

    mlintInfo = mlintInfo([mlintInfo.line] >= func_start);
    mlintInfo = mlintInfo([mlintInfo.line] <= func_stop);
    mlintInfo = mlintInfo(~strcmp({mlintInfo.id}, 'CABE'));
    if isempty(mlintInfo)
        return
    end
    for idx=1:length(mlintInfo)
        info = mlintInfo(idx);
        token = Token('special', 'mlint warning', info.line, info.column(1));
        report = [report struct('token', token, ...
                                'severity', 2, ...
                                'message', info.message)];
    end
end


function print_shadow(varname)
    if does_shadow(varname)
        fprintf('[\bShadows a built-in!]\b');
    end
end


function yesNo = does_shadow(varname)
    yesNo = false;
    builtinfun = 'is a built-in method';
    builtinstr = 'built-in';
    shadows = which(varname, '-all');
    for idx=1:length(shadows)
        shadow = shadows{idx};
        if ( length(shadow) >= length(matlabroot) && ...
             strcmp(shadow(1:length(matlabroot)), matlabroot) ) || ...
           ( length(shadow) >= length(builtinstr) && ...
             strcmp(shadow(1:length(builtinstr)), builtinstr) ) || ...
           ( length(shadow) >= length(builtinfun) && ...
             strcmp(shadow(end-length(builtinfun)+1:end), builtinfun) )
            yesNo = true;
            return
        end
    end
end

function report = check_line_length(tokens)
    report = struct('token', {}, 'message', {}, 'severity', {});
    if ~check_settings('do_check_line_length')
        return
    end

    lines = split_lines(tokens);
    for line_idx=1:length(lines)
        line_tokens = lines{line_idx};
        line_text = horzcat([line_tokens.text]);
        if length(line_text) > 75
            token = Token('special', 'line warning', line_tokens(1).line, ...
                          length(line_text));
            report = [report struct('token', token, ...
                                    'message', 'line very long', ...
                                    'severity', 1)];
        elseif length(line_text) > 90
            token = Token('special', 'line warning', line_tokens(1).line, ...
                          length(line_text));
            report = [report struct('token', token, ...
                                    'message', 'line too long', ...
                                    'severity', 2)];
        end
    end
end


function report = check_indentation(tokens)
    report = struct('token', {}, 'message', {}, 'severity', {});
    if ~check_settings('do_check_indentation')
        return
    end

    beginnings = {'for' 'parfor' 'while' 'if' 'switch' 'classdef' ...
                  'events' 'properties' 'enumeration' 'methods' ...
                  'function'};
    middles = {'else' 'elseif' 'case'};
    ends = {'end'};

    lines = split_lines(tokens);
    previous_indent = get_line_indentation(lines{1});

    for line_idx=1:length(lines)
        line_tokens = lines{line_idx};
        if line_idx > 1
            previous_line = lines{line_idx-1};
            is_continuation = any(strcmp({previous_line.text}, '...'));
        else
            is_continuation = false;
        end

        if isempty(line_tokens)
            continue
        end

        first_nonspace = get_first_nonspace(line_tokens);

        indent = check_settings('indentation_step');
        if first_nonspace.isEqual('keyword', beginnings)
            expected_indent = previous_indent;
            previous_indent = previous_indent + indent;
        elseif first_nonspace.isEqual('keyword', middles)
            expected_indent = previous_indent - indent;
        elseif first_nonspace.isEqual('keyword', ends)
            expected_indent = previous_indent - indent;
            previous_indent = previous_indent - indent;
        elseif is_continuation
            % same rules as in previous line
        else
            expected_indent = previous_indent;
        end

        current_indent = get_line_indentation(line_tokens);

        if first_nonspace.hasType('comment')
            if ~(current_indent >= expected_indent) && current_indent ~= expected_indent-indent
                token = Token('special', 'indentation warning', ...
                              line_tokens(1).line, line_tokens(1).col);
                report = [report struct('token', token, ...
                                        'message', 'incorrect indentation!', ...
                                        'severity', 2)];
            end
        elseif ~is_continuation && current_indent ~= expected_indent
            token = Token('special', 'indentation warning', ...
                          line_tokens(1).line, line_tokens(1).col);
            report = [report struct('token', token, ...
                                    'message', 'incorrect indentation!', ...
                                    'severity', 2)];
        elseif is_continuation && current_indent <= expected_indent
            token = Token('special', 'indentation warning', ...
                          line_tokens(1).line, line_tokens(1).col);
            report = [report struct('token', token, ...
                                    'message', 'not enough indentation!', ...
                                    'severity', 2)];
        end
    end
end


function indentation = get_line_indentation(tokens)
    if ~isempty(tokens) && tokens(1).hasType('space')
        indentation = length(tokens(1).text);
    else
        indentation = 0;
    end
end


function token = get_first_nonspace(tokens)
    idx = 1;
    while idx < length(tokens) && tokens(idx).hasType('space')
        idx = idx + 1;
    end
    token = tokens(idx);
end


function lines = split_lines(tokens)
    lines = {};
    line_start = 1;
    for pos=1:length(tokens)
        if tokens(pos).isEqual('linebreak', sprintf('\n'))
            lines = [lines {tokens(line_start:pos-1)}];
            line_start = pos + 1;
        end
    end
end


function link = open_file_link(filename, linenum)
    prefix = 'matlab.desktop.editor.openAndGoToLine';
    link = sprintf('matlab:%s(''%s'', %i);', prefix, filename, linenum);
end
