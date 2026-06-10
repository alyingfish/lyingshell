.pragma library

function parse(text) {
    return JSON.parse(stripComments(text));
}

function stripComments(text) {
    var result = "";
    var inString = false;
    var escaping = false;
    var inLineComment = false;
    var inBlockComment = false;

    for (var index = 0; index < text.length; index++) {
        var character = text[index];
        var nextCharacter = index + 1 < text.length ? text[index + 1] : "";

        if (inLineComment) {
            if (character === "\n" || character === "\r") {
                inLineComment = false;
                result += character;
            } else {
                result += " ";
            }
            continue;
        }

        if (inBlockComment) {
            if (character === "*" && nextCharacter === "/") {
                result += "  ";
                index += 1;
                inBlockComment = false;
            } else if (character === "\n" || character === "\r") {
                result += character;
            } else {
                result += " ";
            }
            continue;
        }

        if (inString) {
            result += character;
            if (escaping) {
                escaping = false;
            } else if (character === "\\") {
                escaping = true;
            } else if (character === "\"") {
                inString = false;
            }
            continue;
        }

        if (character === "\"") {
            inString = true;
            result += character;
            continue;
        }

        if (character === "/" && nextCharacter === "/") {
            result += "  ";
            index += 1;
            inLineComment = true;
            continue;
        }

        if (character === "/" && nextCharacter === "*") {
            result += "  ";
            index += 1;
            inBlockComment = true;
            continue;
        }

        result += character;
    }

    if (inBlockComment) {
        throw new Error("unterminated block comment");
    }

    return result;
}
