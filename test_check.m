%% Tokenizing a text should not change the content
text = fileread('check.m');
tokens = tokenize_code(text);
reconstructed_text = horzcat(tokens.text);
assert(strcmp(reconstructed_text, text))


%% Function names should be extracted
report = analyze_file('', tokenize_code('function foo(); end'));
assert(strcmp(report.name.text, 'foo'))

report = analyze_file('', tokenize_code('function x = foo(); end'));
assert(strcmp(report.name.text, 'foo'))

report = analyze_file('', tokenize_code('function [x, y] = foo(); end'));
assert(strcmp(report.name.text, 'foo'))


%% Function return names should be extracted
report = analyze_file('', tokenize_code('function foo(); end'));
assert(isempty(report.returns))

report = analyze_file('', tokenize_code('function x = foo(); end'));
assert(strcmp(report.returns(1).text, 'x'))
assert(length(report.returns) == 1)

report = analyze_file('', tokenize_code('function [x, y] = foo(); end'));
assert(strcmp(report.returns(1).text, 'x'))
assert(strcmp(report.returns(2).text, 'y'))
assert(length(report.returns) == 2)


%% Function arguments should be extracted
report = analyze_file('', tokenize_code('function foo(); end'));
assert(isempty(report.arguments))

report = analyze_file('', tokenize_code('function foo(x); end'));
assert(strcmp(report.arguments(1).text, 'x'))
assert(length(report.arguments) == 1)

report = analyze_file('', tokenize_code('function foo(x, y); end'));
assert(strcmp(report.arguments(1).text, 'x'))
assert(strcmp(report.arguments(2).text, 'y'))
assert(length(report.arguments) == 2)


%% Operators should be parsed correctly
tokens = tokenize_code('a>=-b');
assert(tokens(2).hasText('>='))
assert(tokens(3).hasText('-'))


%% Transpose Operators should not be strings
tokens = tokenize_code('a''');
assert(tokens(2).isEqual('punctuation', ''''))

tokens = tokenize_code('a.''');
assert(tokens(2).isEqual('punctuation', '.'''))

tokens = tokenize_code('a''+''a''.''');
assert(tokens(2).isEqual('punctuation', ''''))
assert(tokens(4).isEqual('string', '''a'''))
assert(tokens(5).isEqual('punctuation', '.'''))


%% differentiate commands from expressions
tokens = tokenize_code('help me please % test');
assert(tokens(1).isEqual('identifier', 'help'))
assert(tokens(3).isEqual('string', 'me'))
assert(tokens(5).isEqual('string', 'please'))
assert(tokens(7).isEqual('comment', '% test'))


%% differentiate keyword end from variable end
tokens = tokenize_code('if a(end); end');
assert(tokens(5).isEqual('identifier', 'end'))
assert(tokens(9).isEqual('keyword', 'end'))


%% differentiate semicolons from linebreaks
tokens = tokenize_code('[1;2];3');
assert(tokens(3).isEqual('punctuation', ';'))
assert(tokens(6).isEqual('linebreak', ';'))


%% Identify block comments
comment = sprintf('%%{ \n foo bar \n %%}');
tokens = tokenize_code(comment);
assert(length(tokens) == 1)
assert(tokens.isEqual('comment', comment))

tokens = tokenize_code(sprintf('x\n%s\nx', comment));
assert(length(tokens) == 5)
assert(tokens(3).isEqual('comment', comment))


%% line breaks should break lines
tokens = tokenize_code(',foo bar');
assert(tokens(1).hasType('linebreak'))
assert(tokens(4).hasType('string'))

tokens = tokenize_code(';foo bar');
assert(tokens(1).hasType('linebreak'))
assert(tokens(4).hasType('string'))


%% line breaks should not break lines within brackets
tokens = tokenize_code('[a;b];');
assert(tokens(3).hasType('punctuation'))
assert(tokens(6).hasType('linebreak'))

tokens = tokenize_code('[a,b],');
assert(tokens(3).hasType('punctuation'))
assert(tokens(6).hasType('linebreak'))
