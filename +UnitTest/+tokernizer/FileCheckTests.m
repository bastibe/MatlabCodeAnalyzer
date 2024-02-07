classdef FileCheckTests < matlab.unittest.TestCase
    
    methods(TestClassSetup)
        % Shared setup for the entire test class
        function setPathDef(~)
            addpath('testFiles')
        end
    end
    
    methods(TestClassTeardown)
        % Setup for each test
        function rmPathDef(~)
            rmpath('testFiles')
        end
    end
    
    methods(Test)
        % Test methods
        
        function testMatlabIndentedClass(testCase)
            % Matlab indentation class test
            H = @() check('MatlabIndentedClass.m');
            testCase.verifyWarningFree(H);
        end

        function testMatlabArgumentValidation(testCase)
            % Argument validation test

            % Argument validation not supported by versions earlier than 9.7
            % (earlier than R2019b)
            testCase.assumeFalse(verLessThan('matlab', '9.7'))
            H = @() check('MatlabArgumentClass.m');
            testCase.verifyWarningFree(H);
        end

    end
    
end