classdef Token < handle
    properties
        type
        text
        line
        col
    end

    methods
        function obj = Token(type, text, line, col)
        %TOKEN an atomic piece of source code
        %   Each token references an atomic piece of source code TEXT at a
        %   specific LINE and COL. Each TOKEN is tagged as a certain TYPE.
        %   returns a new OBJ.

            obj.type = type;
            obj.text = text;
            obj.line = line;
            obj.col = col;
        end

        function yesNo = hasType(obj, type)
        %HASTYPE checks it OBJ has matching TYPE
        %   YESNO is a boolean.

            yesNo = any(strcmp(obj.type, type));
        end

        function yesNo = hasText(obj, text)
        %HASTEXT checks it OBJ has matching TEXT
        %   YESNO is a boolean.

            yesNo = any(strcmp(obj.text, text));
        end

        function yesNo = isEqual(obj, type, text)
        %ISEQUAL checks it OBJ has matching TYPE and TEXT
        %   YESNO is a boolean.

            yesNo = obj.hasType(type) && obj.hasText(text);
        end
    end
end
