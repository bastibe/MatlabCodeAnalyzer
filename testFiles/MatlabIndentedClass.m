classdef MatlabIndentedClass
    %MATLABINDENTEDCLASS This is an example class for testing the
    %   indentation check
    %
    %   Some more comments to make the checker happy
    %   Some more comments to make the checker happy
    %   returns a new OBJ.
    
    %
    %
    properties(Access = private)
        foobar
    end
    
    methods(Access = protected)
        
        function output1 = foo_function(input1, input2)
            %FOO_FUNCTION This is an example function for testing the
            %   indentation check
            %   output1 = foo_function: input1, input2
            %   Some more comments to make the checker happy
            
            try
                input1 = 42;
            catch
                input2 = 42;
            end
            % Some more comments to make the checker happy
            if input1
                output1 = 1;
            elseif input2
                output1 = 2;
            else
                output1 = 0;
            end
            
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
        
        function output = test_linebreak_with_continuation_operator(input)
            %TEST_LINEBREAK_WITH_CONTINUATION_OPERATOR is a test to verify
            %    line continuation operator
            %    INPUT, OUTPUT
            
            assignment_at_first_line = ...
                input;
            
            assignment_at_second_line = ... some comment
                assignment_at_first_line;
            
            output = .... 4 dots give also comment
                assignment_at_second_line;
        end
    end
end
