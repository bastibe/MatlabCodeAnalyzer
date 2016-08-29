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

%% Operators should be parsed correctly
tokens = tokenize('a>=-b')
assert(strcmp(tokens(2).text, '>='))
assert(strcmp(tokens(3).text, '-'))

%% Transpose Operators should not be strings
tokens = tokenize('a''')
assert(strcmp(tokens(2).text, ''''))
assert(strcmp(tokens(2).type, 'punctuation'))

tokens = tokenize('a.''')
assert(strcmp(tokens(2).text, '.'''))
assert(strcmp(tokens(2).type, 'punctuation'))

tokens = tokenize('a''+''a''.''')
assert(strcmp(tokens(2).text, ''''))
assert(strcmp(tokens(2).type, 'punctuation'))

assert(strcmp(tokens(4).text, '''a'''))
assert(strcmp(tokens(4).type, 'string'))

assert(strcmp(tokens(5).text, '.'''))
assert(strcmp(tokens(5).type, 'punctuation'))
