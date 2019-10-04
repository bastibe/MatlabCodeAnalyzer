classdef TokenizeTests < matlab.unittest.TestCase
    %TOKENIZETESTS Tests for tokenize_code
    
    methods(Test)
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
        
        %todo: "let's go", 'He said, "hi"'
    end
end