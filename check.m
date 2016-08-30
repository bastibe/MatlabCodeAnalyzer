function report = check(filename)
    [requiredFiles, requiredProducts] = ...
        matlab.codetools.requiredFilesAndProducts(filename);
    mlintInfo = checkcode(filename, '-cyc', '-id');

    text = fileread(filename);
    tokens = tokenize(text);
    func_report = analyze_functions(tokens);

    if nargout == 0
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
            fprintf('  Function <strong>%s</strong> (%s:%i:%i): ', ...
                    func.name.text, filename, func.name.line, func.name.char);
            print_shadow(func.name.text);
            fprintf('\n\n');

            line_report = check_indentation(func.body);
            print_line_report(line_report);

            line_report = check_line_length(func.body);
            print_line_report(line_report);

            print_complexity(mlintInfo, func.body(1).line);
            print_mlint_warnings(mlintInfo, func.body(1).line, func.body(end).line);

            print_var_list(func.arguments, 6, 'Arguments');
            print_var_list(func.returns, 6, 'Returns');
            print_var_list(func.variables, 6, 'Variables');
        end
    else
        report = func_report;
    end
end


function print_line_report(line_report)
    for item=line_report
        if item.severity == 2
            fprintf('    Line %i: [\b%s]\b\n', item.line, item.message);
        else
            fprintf('    Line %i: %s\n', item.line, item.message);
        end
    end
    if ~isempty(line_report)
        fprintf('\n');
    end
end


function print_complexity(mlintInfo, func_start)
    mlintInfo = mlintInfo(strcmp({mlintInfo.id}, 'CABE'));
    mlintInfo = mlintInfo([mlintInfo.line] == func_start);
    if isempty(mlintInfo)
        return
    end
    assert(length(mlintInfo) == 1);

    pattern = 'The McCabe complexity of ''(?<f>[^'']+)'' is (?<n>[0-9]+)';

    matches = regexp(mlintInfo.message, pattern, 'names');
    complexity = str2num(matches.n);
    fprintf('    McCabe complexity: %i ', complexity);
    if complexity < 10
        fprintf('(good)\n\n');
    elseif complexity < 15
        fprintf('(high)\n\n');
    else
        fprintf('[\b(too high)]\b\n\n');
    end
end


function print_mlint_warnings(mlintInfo, func_start, func_stop)
    mlintInfo = mlintInfo([mlintInfo.line] >= func_start);
    mlintInfo = mlintInfo([mlintInfo.line] <= func_stop);
    mlintInfo = mlintInfo(~strcmp({mlintInfo.id}, 'CABE'));
    if isempty(mlintInfo)
        return
    end
    fprintf('    MLint messages:\n');
    for idx=1:length(mlintInfo)
        info = mlintInfo(idx);
        fprintf('      [\b%s]\b (%i:%i)\n', ...
                info.message, info.line, info.column(1));
    end
    fprintf('\n');
end


function print_var_list(varlist, indent, label)
    if isempty(varlist)
        fprintf('    No %s\n\n', label);
    else
        fprintf('    %s:\n', label);
        for var=varlist
            fprintf(repmat(' ', 1, indent));
            fprintf('%s (%i:%i) ', var.text, var.line, var.char);
            print_shadow(var.text);
            fprintf('\n');
        end
        fprintf('\n');
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
    report = struct('line', {}, 'message', {}, 'severity', {});
    lines = line_list(tokens);
    for line_idx=1:length(lines)
        line_tokens = lines{line_idx};
        line_text = horzcat([line_tokens.text]);
        if length(line_text) > 75
            report = [report struct('line', line_tokens(1).line, ...
                                    'message', 'line very long', ...
                                    'severity', 1)];
        elseif length(line_text) > 90
            report = [report struct('line', line_tokens(1).line, ...
                                    'message', 'line too long', ...
                                    'severity', 2)];
        end
    end
end


function report = check_indentation(tokens)
    beginnings = {'for' 'parfor' 'while' 'if' 'switch' 'classdef' ...
                  'events' 'properties' 'enumeration' 'methods' ...
                  'function'};
    middles = {'else' 'elseif' 'case'};
    ends = {'end'};

    report = struct('line', {}, 'message', {}, 'severity', {});

    lines = line_list(tokens);
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

        if first_nonspace.isEqual('keyword', beginnings)
            expected_indent = previous_indent;
            previous_indent = previous_indent + 4;
        elseif first_nonspace.isEqual('keyword', middles)
            expected_indent = previous_indent - 4;
        elseif first_nonspace.isEqual('keyword', ends)
            expected_indent = previous_indent - 4;
            previous_indent = previous_indent - 4;
        elseif is_continuation
            % same rules as in previous line
        else
            expected_indent = previous_indent;
        end

        current_indent = get_line_indentation(line_tokens);

        if ~is_continuation && current_indent ~= expected_indent
            report = [report struct('line', line_tokens(1).line, ...
                                    'message', 'incorrect indentation!', ...
                                    'severity', 2)];
        elseif is_continuation && current_indent <= expected_indent
            report = [report struct('line', line_tokens(1).line, ...
                                    'message', 'not enough indentation!', ...
                                    'severity', 2)];
        end
    end
end


function indentation = get_line_indentation(tokens)
    if tokens(1).hasType('space')
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


function lines = line_list(tokens)
    lines = {};
    line_start = 1;
    for pos=1:length(tokens)
        if tokens(pos).isEqual('linebreak', sprintf('\n'))
            lines = [lines {tokens(line_start:pos-1)}];
            line_start = pos + 1;
        end
    end
end
