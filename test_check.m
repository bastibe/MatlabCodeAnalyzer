%% Tokenizing a text should not change the content
text = fileread('check.m');
tokens = tokenize(text);
str = '';
for t=tokens
    str = [str t.text];
end
assert(strcmp(str, text))

%% Function names should be extracted
report = extract_functions(tokenize('function foo(); end'));
assert(strcmp(report.name, 'foo'))

report = extract_functions(tokenize('function x = foo(); end'));
assert(strcmp(report.name, 'foo'))

report = extract_functions(tokenize('function [x, y] = foo(); end'));
assert(strcmp(report.name, 'foo'))
