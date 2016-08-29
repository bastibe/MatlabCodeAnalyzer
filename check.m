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
