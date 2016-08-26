%% Tokenizing a text should not change the content
text = fileread('check.m');
tokens = tokenize(text);
str = '';
for t=tokens
    str = [str t.text];
end
assert(strcmp(str, text))
