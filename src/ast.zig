const std = @import("std");

pub const Token = struct {
    token_type: TokenType,
    lexeme: []u8,
    literal: []u8,
    line: usize,
    pub fn init(token_type: TokenType, lexeme: []u8, literal: []u8, line: usize) @TypeOf(@This()) {
        return Token{
            .token_type = token_type,
            .lexeme = lexeme,
            .literal = literal,
            .line = line,
        };
    }

    pub fn string(self: @This()) []u8 {
        if (self.literal.len > 0) {
            return std.fmt.allocPrint(std.heap.c_allocator, "{any} {s} {s}", .{ self.token_type, self.lexeme, self.literal }) catch {
                return &[_]u8{};
            };
        } else {
            return std.fmt.allocPrint(std.heap.c_allocator, "{any} {s}", .{ self.token_type, self.lexeme }) catch {
                return &[_]u8{};
            };
        }
    }
};

pub const TokenType = enum {
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE,
    COMMA,
    DOT,
    MINUS,
    PLUS,
    SEMICOLON,
    SLASH,
    STAR,

    // One or two character tokens.
    BANG,
    BANG_EQUAL,
    EQUAL,
    EQUAL_EQUAL,
    GREATER,
    GREATER_EQUAL,
    LESS,
    LESS_EQUAL,

    // Literals.
    IDENTIFIER,
    STRING,
    NUMBER,

    // Keywords.
    AND,
    CLASS,
    ELSE,
    FALSE,
    FUN,
    FOR,
    IF,
    NIL,
    OR,
    PRINT,
    RETURN,
    SUPER,
    THIS,
    TRUE,
    VAR,
    WHILE,

    EOF,

    COMMENT,
    BLOCK_COMMENT,
};
