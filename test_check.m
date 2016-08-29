%% Tokenizing a text should not change the content
text = fileread('check.m');
tokens = tokenize(text);
reconstructed_text = horzcat(tokens.text);
assert(strcmp(reconstructed_text, text))

%% Function names should be extracted
report = analyze_functions(tokenize('function foo(); end'));
assert(strcmp(report.name, 'foo'))

report = analyze_functions(tokenize('function x = foo(); end'));
assert(strcmp(report.name, 'foo'))

report = analyze_functions(tokenize('function [x, y] = foo(); end'));
assert(strcmp(report.name, 'foo'))

%% Operators should be parsed correctly
tokens = tokenize('a>=-b');
assert(tokens(2).hasText('>='))
assert(tokens(3).hasText('-'))

%% Transpose Operators should not be strings
tokens = tokenize('a''');
assert(tokens(2).isEqual('punctuation', ''''))

tokens = tokenize('a.''');
assert(tokens(2).isEqual('punctuation', '.'''))

tokens = tokenize('a''+''a''.''');
assert(tokens(2).isEqual('punctuation', ''''))
assert(tokens(4).isEqual('string', '''a'''))
assert(tokens(5).isEqual('punctuation', '.'''))

%% differentiate commands from expressions
tokens = tokenize('help me please % test');
assert(tokens(1).isEqual('identifier', 'help'))
assert(tokens(3).isEqual('string', 'me'))
assert(tokens(5).isEqual('string', 'please'))
assert(tokens(7).isEqual('comment', '% test'))

%% differentiate keyword end from variable end
tokens = tokenize('if a(end); end');
assert(tokens(5).isEqual('identifier', 'end'))
assert(tokens(9).isEqual('keyword', 'end'))

%% differentiate semicolons from linebreaks
tokens = tokenize('[1;2];3');
assert(tokens(3).isEqual('punctuation', ';'))
assert(tokens(6).isEqual('linebreak', ';'))
