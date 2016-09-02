function value = check_settings(name)
    settings.lo_class_num_lines = 200;
    settings.hi_class_num_lines = 400;
    settings.lo_class_num_properties = 10;
    settings.hi_class_num_properties = 15;
    settings.lo_class_num_methods = 10;
    settings.hi_class_num_methods = 20;

    settings.lo_script_num_lines = 100;
    settings.hi_script_num_lines = 200;
    settings.lo_script_num_variables = 10;
    settings.hi_script_num_variables = 20;

    settings.lo_function_num_lines = 50;
    settings.hi_function_num_lines = 100;
    settings.lo_function_num_arguments = 3;
    settings.hi_function_num_arguments = 5;
    settings.lo_function_num_variables = 7;
    settings.hi_function_num_variables = 15;
    settings.lo_function_max_indentation = 3;
    settings.hi_function_max_indentation = 6;
    settings.lo_function_complexity = 10;
    settings.hi_function_complexity = 15;

    settings.lo_varname_short_length = 3;
    settings.lo_varname_short_spread = 3;
    settings.lo_varname_long_length = 5;
    settings.lo_varname_long_spread = 10;
    settings.hi_varname_short_length = 3;
    settings.hi_varname_short_spread = 5;
    settings.hi_varname_long_length = 5;
    settings.hi_varname_long_spread = 15;

    settings.do_check_comments = true;
    settings.do_check_documentation = true;
    settings.do_check_eval = true;
    settings.do_check_operators = true;
    settings.do_check_variables = true;
    settings.do_check_mlint_warnings = true;
    settings.do_check_line_length = true;
    settings.do_check_indentation = true;

    settings.indentation_step = 4;

    value = settings.(name);
end
