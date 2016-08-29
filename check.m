function report = check(filename)
    [requiredFiles, requiredProducts] = matlab.codetools.requiredFilesAndProducts(filename);

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
            fprintf('  Function <strong>%s</strong> (%s:%i:%i): ', func.name.text, filename, func.name.line, func.name.char);
            print_shadow(func.name.text);
            fprintf('\n\n');

            line_report = analyze_lines(func.body);
            for item=line_report
                fprintf('    Line %i: [\b%s]\b\n', item.line, item.message);
            end
            if ~isempty(line_report)
                fprintf('\n');
            end

            if isempty(func.arguments)
                fprintf('    No Arguments\n\n');
            else
                fprintf('    Arguments:\n');
                print_var_list(func.arguments, 6);
                fprintf('\n');
            end

            if isempty(func.returns)
                fprintf('    No Return Value\n\n');
            else
                fprintf('    Returns:\n');
                print_var_list(func.returns, 6);
                fprintf('\n');
            end

            if isempty(func.variables)
                fprintf('    No Variables\n\n');
            else
                fprintf('    Variables:\n');
                print_var_list(func.variables, 6);
                fprintf('\n');
            end
        end
    else
        report = func_report;
    end
end


function print_var_list(varlist, indent)
    for var=varlist
        fprintf(repmat(' ', 1, indent));
        fprintf('%s (%i:%i) ', var.text, var.line, var.char);
        print_shadow(var.text);
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
        if (length(shadow) >= length(matlabroot) && strcmp(shadow(1:length(matlabroot)), matlabroot)) || ...
           (length(shadow) >= length(builtinstr) && strcmp(shadow(1:length(builtinstr)), builtinstr)) || ...
           (length(shadow) >= length(builtinfun) && strcmp(shadow(end-length(builtinfun)+1:end), builtinfun))
            yesNo = true;
            return
        end
    end
end


function report = analyze_lines(tokens)
    beginnings = {'for' 'parfor' 'while' 'if' 'switch' 'classdef' ...
                  'events' 'properties' 'enumeration' 'methods' ...
                  'function'};

    report = struct('line', {}, 'message', {});

    previous_line = Token('dummy', '', -1, -1);
    indentation = tokens(1).char;
    line_start = 1;
    line_indentation = indentation;
    for pos = 1:length(tokens)
        token = tokens(pos);
        % count the 'end's to figure out the correct indentation
        if token.isEqual('keyword', beginnings)
            indentation = indentation + 4;
        elseif token.isEqual('keyword', 'end')
            indentation = indentation - 4;
        end
        if token.isEqual('linebreak', sprintf('\n'))
            line = tokens(line_start:pos-1);
            line_start = pos + 1;
            line_text = horzcat([line.text]);
            if isempty(line)
                continue
            end
            if length(line_text) > 75
                report = [report struct('line', line(1).line, ...
                                        'message', 'line too long')];
            end
            if line(1).hasType('space') && ~any(strcmp({previous_line.text}, '...')) && ...
               ~( ( ~line(2).isEqual('keyword', {'else', 'elseif', 'case', 'end'}) && ...
                    length(line(1).text) == line_indentation ) || ...
                  ( line(2).isEqual('keyword', {'else', 'elseif', 'case', 'end'}) && ...
                    length(line(1).text) == line_indentation-4 ) )
                report = [report struct('line', line(1).line, ...
                                        'message', 'incorrect indentation!')];
            elseif line(1).hasType('space') && any(strcmp({previous_line.text}, '...')) && ...
                   length(line(1).text) <= line_indentation
                report = [report struct('line', line(1).line, ...
                                        'message', 'continuation line with incorrect indentation!')];
            end
            if ~any(strcmp({line.text}, '...'))
                line_indentation = indentation;
            end
            previous_line = line;
        end
    end
end
