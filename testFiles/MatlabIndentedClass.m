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
    end
end
