classdef Token < handle
    properties
        type
        text
        line
        char
    end

    methods
        function obj = Token(type, text, line, char)
            obj.type = type;
            obj.text = text;
            obj.line = line;
            obj.char = char;
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
