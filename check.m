function report = check(filename)
    % [files, products] = matlab.codetools.requiredFilesAndProducts(funcname);

    text = fileread(filename);
    tokens = tokenize(text);
    report = extract_functions(tokens);
end
