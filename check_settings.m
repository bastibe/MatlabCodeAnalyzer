function value = check_settings(name)
%CHECK_SETTINGS returns settings vor CHECK.
%   CHECK_SETTINGS(NAME) returns the VALUE of the settings called NAME.
%
%   Create a local copy of this file and overwrite values if you want
%   custom behavior in a specific project.

    % thresholds for the number of lines in classes:
    settings.lo_class_num_lines = 200;
    settings.hi_class_num_lines = 400;
    % thresholds for the number of properties in classes:
    settings.lo_class_num_properties = 10;
    settings.hi_class_num_properties = 15;
    % thresholds for the number of methods in classes:
    settings.lo_class_num_methods = 10;
    settings.hi_class_num_methods = 20;

    % thresholds for the number of lines in scripts:
    settings.lo_script_num_lines = 100;
    settings.hi_script_num_lines = 200;
    % thresholds for the number of variables in scripts:
    settings.lo_script_num_variables = 10;
    settings.hi_script_num_variables = 20;
    % thresholds for the level of indentation in scripts:
    settings.lo_script_max_indentation = 4;
    settings.hi_script_max_indentation = 8;

    % thresholds for the number of lines in functions:
    settings.lo_function_num_lines = 50;
    settings.hi_function_num_lines = 100;
    % thresholds for the number of arguments in functions:
    settings.lo_function_num_arguments = 3;
    settings.hi_function_num_arguments = 5;
    % thresholds for the number of variables in functions:
    settings.lo_function_num_variables = 7;
    settings.hi_function_num_variables = 15;
    % thresholds for the level of indentation in functions:
    settings.lo_function_max_indentation = 3;
    settings.hi_function_max_indentation = 6;
    % thresholds for the complexity of functions:
    settings.lo_function_complexity = 10;
    settings.hi_function_complexity = 15;

    % thresholds for the line length of files:
    settings.lo_line_length = 75;
    settings.hi_line_length = 90;

    % threshold for the variable length and spread (spread is the
    % number of lines in which a variable is used).
    % Read this as "if a variable name is less than 3 characters
    % long, it should be use in no more than 3 lines":
    settings.lo_varname_short_length = 3;
    settings.lo_varname_short_spread = 3;
    settings.lo_varname_long_length = 5;
    settings.lo_varname_long_spread = 10;
    settings.hi_varname_short_length = 3;
    settings.hi_varname_short_spread = 5;
    settings.hi_varname_long_length = 5;
    settings.hi_varname_long_spread = 15;

    % switches to switch whole modules on or off:
    settings.do_check_comments = true;
    settings.do_check_documentation = true;
    settings.do_check_eval = true;
    settings.do_check_operators = true;
    settings.do_check_variables = true;
    settings.do_check_mlint_warnings = true;
    settings.do_check_line_length = true;
    settings.do_check_indentation = true;

    % indent by this many spaces per level of indentation:
    settings.indentation_step = 4;
    % Matlab does not indent top-level function bodies. Most other
    % languages would think this behavior funny:
    settings.indentation_check_like_matlab = true;

    % keywords for tokenize_code
    settings.keywords = {'for' 'try' 'while' 'if' 'else' 'elseif' 'switch' ...
                'case' 'otherwise' 'function' 'classdef' 'methods' ...
                'properties' 'events' 'enumeration' 'parfor' ...
                'return' 'break' 'continue' 'catch'};

    % keyword beginnings which are considered for indentation calculation
    settings.beginnings = {'for' 'parfor' 'while' 'if' 'switch' 'classdef' ...
        'events' 'properties' 'enumeration' 'methods' ...
        'function' 'try'};
    % keyword middles which are considered for indentation calculation
    settings.middles = {'else' 'elseif' 'case' 'otherwise' 'catch'};

    value = settings.(name);
end
