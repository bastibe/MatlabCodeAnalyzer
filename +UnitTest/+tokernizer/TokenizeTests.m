classdef TokenizeTests < matlab.unittest.TestCase
    %TOKENIZETESTS Tests for tokenize_code
    
    methods(Test)
        function testText(obj)
            %TESTTEXT Tokenizing a text should not change the content

            % Read file
            text = fileread('check.m');

            % Tokenize code
            tokens = tokenize_code(text);

            % Reconstruct text from tokens
            reconstructed_text = horzcat(tokens.text);

            % Compare with actual text
            obj.assertEqual(reconstructed_text, text)
        end

        function testDoubleQuote(obj)
            %TESTDOUBLEQUOTE Tests a double quoted string
            
            % Input data for the test
            input_str = '"test"'; % String: "test"
            
            % Construct expected output for comparison
            expected = Token('string', input_str, 1, 1);
            
            % Get actual output
            actual = tokenize_code(input_str);
            
            % Compare actual output with expected output
            obj.verifyEqual(actual, expected);
        end
        
        function testSoloDoubleQuote(obj)
            %TESTSOLODOUBLEQUOTE Tests a string with only a double quoted
            
            % Input data for the test
            input_str = 'output = "test"'; % String: output = 'test'
            
            % Construct expected output for comparison
            expected(1) = Token('identifier', 'output', 1, 1);
            expected(2) = Token('space', ' ', 1, 7);
            expected(3) = Token('punctuation', '=', 1, 8);
            expected(4) = Token('space', ' ', 1, 9);
            expected(5) = Token('string', '"test"', 1, 10);
            
            % Get actual output
            actual = tokenize_code(input_str);
            
            % Compare actual output with expected output
            obj.verifyEqual(actual, expected);
        end
        
        function testNestedQuote(obj)
            %TESTNESTEDQUOTE Tests a double quote inside single quote
            
            % Input data for the test
            input_str = '"let''s go"'; % String: "let's go"
            
            % Construct expected output for comparison
            expected = Token('string', input_str, 1, 1);
            
            % Get actual output
            actual = tokenize_code(input_str);
            
            % Compare actual output with expected output
            obj.verifyEqual(actual, expected);
        end
        
        function testNestedQuote2(obj)
            %TESTNESTEDQUOTE2 Tests a double quote inside single quote
            
            % Input data for the test
            input_str = '''He said, "hi"'''; % String: 'He said, "hi"'
            
            % Construct expected output for comparison
            expected = Token('string', input_str, 1, 1);
            
            % Get actual output
            actual = tokenize_code(input_str);
            
            % Compare actual output with expected output
            obj.verifyEqual(actual, expected);
        end

        function testFunctionNames(obj)
            %TESTFUNCTIONNAMES Function names should be extracted
            report = analyze_file('', tokenize_code('function foo(); end'));
            obj.assertEqual(report.name.text, 'foo')
            
            report = analyze_file('', tokenize_code('function x = foo(); end'));
            obj.assertEqual(report.name.text, 'foo')
            
            report = analyze_file('', tokenize_code('function [x, y] = foo(); end'));
            obj.assertEqual(report.name.text, 'foo')
        end

        function testFunctionReturnNames(obj)
            %TESTFUNCTIONRETURNNAMES Function return names should be extracted
            report = analyze_file('', tokenize_code('function foo(); end'));
            obj.assertEmpty(report.returns)
            
            report = analyze_file('', tokenize_code('function x = foo(); end'));
            obj.assertEqual(report.returns(1).text, 'x')
            obj.assertLength(report.returns, 1)
            
            report = analyze_file('', tokenize_code('function [x, y] = foo(); end'));
            obj.assertEqual(report.returns(1).text, 'x')
            obj.assertEqual(report.returns(2).text, 'y')
            obj.assertLength(report.returns, 2)
        end

        function testFunctionArguments(obj)
            %TESTFUNCTIONARGUMENTS Function arguments should be extracted
            report = analyze_file('', tokenize_code('function foo(); end'));
            obj.assertEmpty(report.arguments)
            
            report = analyze_file('', tokenize_code('function foo(x); end'));
            obj.assertEqual(report.arguments(1).text, 'x')
            obj.assertLength(report.arguments, 1)
            
            report = analyze_file('', tokenize_code('function foo(x, y); end'));
            obj.assertEqual(report.arguments(1).text, 'x')
            obj.assertEqual(report.arguments(2).text, 'y')
            obj.assertLength(report.arguments, 2)

        end

        function testOperatorsGeneral(obj)
            %TESTOPERATORSGENERAL Operators should be parsed correctly
            tokens = tokenize_code('a>=-b');
            obj.assertTrue(tokens(2).hasText('>='))
            obj.assertTrue(tokens(3).hasText('-'))
        end

        function testOperatorsTranspose(obj)
            %TESTOPERATORSTRANSPOSE Transpose Operators should not be strings
            tokens = tokenize_code('a''');
            obj.assertTrue(tokens(2).isEqual('punctuation', ''''))
            
            tokens = tokenize_code('a.''');
            obj.assertTrue(tokens(2).isEqual('punctuation', '.'''))
            
            tokens = tokenize_code('a''+''a''.''');
            obj.assertTrue(tokens(2).isEqual('punctuation', ''''))
            obj.assertTrue(tokens(4).isEqual('string', '''a'''))
            obj.assertTrue(tokens(5).isEqual('punctuation', '.'''))
        end

        function testCommands(obj)
            %TESTCOMMANDS Differentiate commands from expressions
            tokens = tokenize_code('help me please % test');
            obj.assertTrue(tokens(1).isEqual('identifier', 'help'))
            obj.assertTrue(tokens(3).isEqual('string', 'me'))
            obj.assertTrue(tokens(5).isEqual('string', 'please'))
            obj.assertTrue(tokens(7).isEqual('comment', '% test'))
        end

        function testEnd(obj)
            %TESTEND Differentiate keyword end from variable end
            tokens = tokenize_code('if a(end); end');
            obj.assertTrue(tokens(5).isEqual('identifier', 'end'))
            obj.assertTrue(tokens(9).isEqual('keyword', 'end'))
        end

        function testSimicolon(obj)
            %TESTSEMICOLONS Differentiate semicolons from linebreaks
            tokens = tokenize_code('[1;2];3');
            obj.assertTrue(tokens(3).isEqual('punctuation', ';'))
            obj.assertTrue(tokens(6).isEqual('linebreak', ';'))
        end

        function testBlock(obj)
            %TESTBLOCK Identify block comments
            comment = sprintf('%%{ \n foo bar \n %%}');
            tokens = tokenize_code(comment);
            obj.assertLength(tokens, 1)
            obj.assertTrue(tokens.isEqual('comment', comment))
            
            tokens = tokenize_code(sprintf('x\n%s\nx', comment));
            obj.assertLength(tokens, 5)
            obj.assertTrue(tokens(3).isEqual('comment', comment))
        end

        function testLinebreak(obj)
            %TESTLINEBREAK Test line breaks

            % Line breaks should break lines
            tokens = tokenize_code(',foo bar');
            obj.assertTrue(tokens(1).hasType('linebreak'))
            obj.assertTrue(tokens(4).hasType('string'))
            
            tokens = tokenize_code(';foo bar');
            obj.assertTrue(tokens(1).hasType('linebreak'))
            obj.assertTrue(tokens(4).hasType('string'))

            % Line breaks should not break lines within brackets
            tokens = tokenize_code('[a;b];');
            obj.assertTrue(tokens(3).hasType('punctuation'))
            obj.assertTrue(tokens(6).hasType('linebreak'))
            
            tokens = tokenize_code('[a,b],');
            obj.assertTrue(tokens(3).hasType('punctuation'))
            obj.assertTrue(tokens(6).hasType('linebreak'))
        end

        function testComment(obj)
            %TESTCOMMENT Test conventional comments in text
            
            % Conventional comments in text
            tokens = tokenize_code('% this is a comment');
            obj.assertLength(tokens, 1)
            obj.assertTrue(tokens(1).hasType('comment'));

            tokens = tokenize_code('    % this is a comment');
            obj.assertLength(tokens, 2)
            obj.assertTrue(tokens(1).hasType('space'));
            obj.assertTrue(tokens(2).hasType('comment'));

            txt = sprintf('%s\n%s', ...
                '    % this is a comment', ...
                '    && ...');
            tokens = tokenize_code(txt);
            obj.assertLength(tokens, 7)
            obj.assertTrue(tokens(1).hasType('space'));
            obj.assertTrue(tokens(2).hasType('comment'));
            obj.assertTrue(tokens(3).hasType('linebreak'));
            obj.assertTrue(tokens(4).hasType('space'));
            obj.assertTrue(tokens(5).hasType('punctuation'));
            obj.assertTrue(tokens(6).hasType('space'));
            obj.assertTrue(tokens(7).hasType('punctuation'));
        end

        function testCommentContinuationOperator(obj)
            %TESTCOMMENTCONTINUATIONOPERATOR Test comments that follow continuation operator 

            % Test comments that follow continuation operator
            tokens = tokenize_code('... % this is a comment');
            obj.assertLength(tokens, 3)
            obj.assertTrue(tokens(1).hasType('punctuation'));
            obj.assertTrue(tokens(2).hasType('space'));
            obj.assertTrue(tokens(3).hasType('comment'));
            
            tokens = tokenize_code('... this is a comment');
            obj.assertLength(tokens, 3)
            obj.assertTrue(tokens(1).hasType('punctuation'));
            obj.assertTrue(tokens(2).hasType('space'));
            obj.assertTrue(tokens(3).hasType('comment'));

            tokens = tokenize_code('    ... % this is a comment');
            obj.assertLength(tokens, 4)
            obj.assertTrue(tokens(1).hasType('space'));
            obj.assertTrue(tokens(2).hasType('punctuation'));
            obj.assertTrue(tokens(3).hasType('space'));
            obj.assertTrue(tokens(4).hasType('comment'));
            
            tokens = tokenize_code('....');
            obj.assertLength(tokens, 2)
            obj.assertTrue(tokens(1).hasType('punctuation'));
            obj.assertTrue(tokens(2).hasType('comment'));

            tokens = tokenize_code('..., this is a comment');
            obj.assertLength(tokens, 2)
            obj.assertTrue(tokens(1).hasType('punctuation'));
            obj.assertTrue(tokens(2).hasType('comment'));
            
            tokens = tokenize_code('.*...');
            obj.assertLength(tokens, 2)
            obj.assertTrue(tokens(1).hasType('punctuation'));
            obj.assertTrue(tokens(2).hasType('punctuation'));

            tokens = tokenize_code('    &&...this is a comment');
            obj.assertLength(tokens, 4)
            obj.assertTrue(tokens(1).hasType('space'));
            obj.assertTrue(tokens(2).hasType('punctuation'));
            obj.assertTrue(tokens(3).hasType('punctuation'));
            obj.assertTrue(tokens(4).hasType('comment'));
            
            tokens = tokenize_code('&... this is a comment');
            obj.assertLength(tokens, 4)
            obj.assertTrue(tokens(1).hasType('punctuation'));
            obj.assertTrue(tokens(2).hasType('punctuation'));
            obj.assertTrue(tokens(3).hasType('space'));
            obj.assertTrue(tokens(4).hasType('comment'));

            % Test comments that follow continuation operator with line break
            txt = sprintf('%s\n%s', ...
                '    |... this is a comment', ...
                '    ||.... this is a comment');
            tokens = tokenize_code(txt);
            obj.assertLength(tokens, 10)
            obj.assertTrue(tokens(1).hasType('space'));
            obj.assertTrue(tokens(2).hasType('punctuation'));
            obj.assertTrue(tokens(3).hasType('punctuation'));
            obj.assertTrue(tokens(4).hasType('space'));
            obj.assertTrue(tokens(5).hasType('comment'));
            obj.assertTrue(tokens(6).hasType('linebreak'));
            obj.assertTrue(tokens(7).hasType('space'));
            obj.assertTrue(tokens(8).hasType('punctuation'));
            obj.assertTrue(tokens(9).hasType('punctuation'));
            obj.assertTrue(tokens(10).hasType('comment'));

            txt = sprintf('%s\n%s\n%s', ...
                '    % this is a comment', ...
                '    true||.... this is a comment', ...
                '    false% this is a comment');
            tokens = tokenize_code(txt);
            obj.assertLength(tokens, 12)
            obj.assertTrue(tokens(1).hasType('space'));
            obj.assertTrue(tokens(2).hasType('comment'));
            obj.assertTrue(tokens(3).hasType('linebreak'));
            obj.assertTrue(tokens(4).hasType('space'));
            obj.assertTrue(tokens(5).hasType('identifier'));
            obj.assertTrue(tokens(6).hasType('punctuation'));
            obj.assertTrue(tokens(7).hasType('punctuation'));
            obj.assertTrue(tokens(8).hasType('comment'));
            obj.assertTrue(tokens(9).hasType('linebreak'));
            obj.assertTrue(tokens(10).hasType('space'));
            obj.assertTrue(tokens(11).hasType('identifier'));
            obj.assertTrue(tokens(12).hasType('comment'));
        end
    end
end