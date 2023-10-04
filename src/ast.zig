const std = @import("std");

pub const Token = struct {
    token_type: TokenType,
    lexeme: []u8,
    literal: TokenLiteral,
    line: usize,
    pub fn init(token_type: TokenType, lexeme: []u8, literal: TokenLiteral, line: usize) Token {
        return Token{
            .token_type = token_type,
            .lexeme = lexeme,
            .literal = literal,
            .line = line,
        };
    }

    pub fn string(self: @This()) []u8 {
        if (self.literal != TokenLiteralType.Empty or self.literal != TokenLiteralType.NIL) {
            return std.fmt.allocPrint(std.heap.c_allocator, "{any} {s} {s}", .{ self.token_type, self.lexeme, self.literal.string() }) catch {
                return &[_]u8{};
            };
        } else {
            return std.fmt.allocPrint(std.heap.c_allocator, "{any} {s}", .{ self.token_type, self.lexeme }) catch {
                return &[_]u8{};
            };
        }
    }
};

pub const TokenLiteralType = enum {
    String,
    Bool,
    Integer,
    Float,
    NIL,
    Empty,
};

pub const TokenLiteral = union(TokenLiteralType) {
    String: []u8,
    Bool: bool,
    Integer: isize,
    Float: f32,
    NIL: void,
    Empty: void,

    pub fn string(self: @This()) []u8 {
        switch (self) {
            .String => |s| {
                return s;
            },
            .Bool => |s| {
                if (s) {
                    return @constCast("true");
                }
                return @constCast("false");
            },
            .Integer => |i| {
                var buf = std.ArrayList(u8).init(std.heap.c_allocator); // Specify an appropriate buffer size for your needs
                std.fmt.formatInt(i, 10, .upper, .{}, buf.writer()) catch {};
                return buf.items;
            },
            .Float => |f| {
                var buf = std.ArrayList(u8).init(std.heap.c_allocator); // Specify an appropriate buffer size for your needs
                std.fmt.formatFloatDecimal(f, .{ .precision = 3 }, buf.writer()) catch {};

                return buf.items;
            },
            .NIL => {
                return @constCast(&[0]u8{});
            },
            .Empty => {
                return @constCast(&[0]u8{});
            },
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
