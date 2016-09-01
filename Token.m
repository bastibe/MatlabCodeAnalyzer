classdef Token < handle
    properties
        type
        text
        line
        col
    end

    methods
        function obj = Token(type, text, line, col)
            obj.type = type;
            obj.text = text;
            obj.line = line;
            obj.col = col;
        end

        function yesNo = hasType(obj, type)
            yesNo = any(strcmp(obj.type, type));
        end

        function yesNo = hasText(obj, text)
            yesNo = any(strcmp(obj.text, text));
        end

        function yesNo = isEqual(obj, type, text)
            yesNo = obj.hasType(type) && obj.hasText(text);
        end
    end
end
