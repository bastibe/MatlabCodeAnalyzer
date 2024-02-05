classdef MatlabArgumentClass < matlab.mixin.Heterogeneous
    %MATLABARGUMENTCLASS This is an example class for testing the
    %   argument validation
    %
    %   Some more comments to make the checker happy
    %   Some more comments to make the checker happy
    %   returns a new OBJ.
    
    %
    %
    properties (Access = private)
        property1 (1,1) string = "Hello World"

        property2 (1,:) char = 'Hello World'

        property3 {mustBeTextScalar}
    end
    
    methods (Access = protected)
        
        function obj = foo_function(input1, input2, options)
            %FOO_FUNCTION This is an example function for testing the
            %   indentation check
            %   output1 = foo_function: input1, input2
            %   Some more comments to make the checker happy

            arguments
                input1 (1,1) string
                input2 {mustBeText}
                options.?matlab.mixin.Heterogeneous
            end
            
            try
                input1 = 42;
            catch
                input2 = 42;
            end
            % Some more comments to make the checker happy
            if input1
                obj = 1;
            elseif input2
                obj = 2;
            else
                obj = 0;
            end

            obj.property3 = options;
            
        end
        
        function foobar = second_function(barfoo)
            %SECOND_FUNCTION This is an example function for testing the
            %   indentation check
            %   foobar, barfoo
            foobar = barfoo;
        end
        
        function varargout = variable_length_of_in_and_output(varargin)
            %VARIABLE_LENGTH_OF_IN_AND_OUTPUT is provided with input param
            %    VARARGIN and output parameter VARARGOUT
            varargout = varargin;
        end
        
        function output = test_linebreak_with_continuation_operator(inputarg)
            %TEST_LINEBREAK_WITH_CONTINUATION_OPERATOR is a test to verify
            %    line continuation operator
            %    INPUTARG, OUTPUT
            
            assignment_at_first_line = ...
                inputarg;
            
            assignment_at_second_line = ... some comment
                assignment_at_first_line;
            
            output = .... 4 dots give also comment
                assignment_at_second_line;
        end
        
        function test_switch_case(inputarg)
            %TEST_SWITCH_CASE test indentation of switch case
            %    INPUTARG
            %    Some more comments to make the checker happy

            switch inputarg
                case 1
                    return
                case 2
                    return
                otherwise
                    return
            end
        end
    end
end
