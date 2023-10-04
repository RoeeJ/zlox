const std = @import("std");
const ast = @import("ast.zig");
const lox = @import("lox.zig");
const allocator = std.heap.c_allocator;

const Token = ast.Token;
const TokenLiteral = ast.TokenLiteral;
const TokenLiteralType = ast.TokenLiteralType;
const TokenType = ast.TokenType;

const ScannerError = error{UnexpectedCharacter};
const KV = struct { []const u8, TokenType };
const ident_map = std.ComptimeStringMap(TokenType, &[_]KV{
    .{ "and", .AND },
    .{ "class", .CLASS },
    .{ "else", .ELSE },
    .{ "false", .FALSE },
    .{ "for", .FOR },
    .{ "fun", .FUN },
    .{ "if", .IF },
    .{ "nil", .NIL },
    .{ "or", .OR },
    .{ "print", .PRINT },
    .{ "return", .PRINT },
    .{ "super", .SUPER },
    .{ "this", .THIS },
    .{ "true", .TRUE },
    .{ "var", .VAR },
    .{ "while", .WHILE },
});

pub const Scanner = struct {
    const Self = @This();
    source: []u8,
    tokens: std.ArrayList(Token),

    start: usize,
    current: usize,
    where: []u8,
    line: usize,

    had_error: bool,
    pub fn init_with_file(path: []const u8) !Scanner {
        var file_data = try lox.read_file(path);
        return Scanner.init(file_data);
    }

    pub fn init(source: []u8) Scanner {
        return Scanner{
            .source = source,
            .tokens = std.ArrayList(Token).init(
                std.heap.c_allocator,
            ),
            .start = 0,
            .current = 0,
            .line = 1,
            .where = @as([]u8, &[_]u8{}),
            .had_error = false,
        };
    }

    pub fn err(self: *@This(), line: usize, message: []const u8) void {
        self.report(line, "", message);
        self.had_error = true;
    }

    pub fn report(self: *@This(), line: usize, where: []u8, message: []const u8) void {
        _ = self;
        std.debug.print("[line {}] Error {s}: {s}\n", .{ line, where, message });
    }

    pub fn scan_tokens(self: *@This()) !void {
        while (!self.is_at_end()) {
            self.start = self.current;
            try self.scan_token();
        }
    }

    pub fn scan_token(self: *@This()) !void {
        var c = self.next();
        switch (c) {
            '(' => self.add_token(TokenType.LEFT_PAREN),
            ')' => self.add_token(TokenType.RIGHT_PAREN),
            '{' => self.add_token(TokenType.LEFT_BRACE),
            '}' => self.add_token(TokenType.RIGHT_BRACE),
            ',' => self.add_token(TokenType.COMMA),
            '.' => self.add_token(TokenType.DOT),
            '-' => self.add_token(TokenType.MINUS),
            '+' => self.add_token(TokenType.PLUS),
            ';' => self.add_token(TokenType.SEMICOLON),
            '*' => self.add_token(TokenType.STAR),
            '!' => self.add_token(if (self.match('=')) TokenType.BANG_EQUAL else TokenType.BANG),
            '=' => self.add_token(if (self.match('=')) TokenType.EQUAL_EQUAL else TokenType.EQUAL),
            '<' => self.add_token(if (self.match('=')) TokenType.LESS_EQUAL else TokenType.LESS),
            '>' => self.add_token(if (self.match('=')) TokenType.GREATER_EQUAL else TokenType.GREATER),
            '/' => {
                if (self.match('/')) {
                    self.comment();
                } else if (self.match('*')) {
                    self.block_comment();
                } else {
                    self.add_token(TokenType.SLASH);
                }
            },
            ' ', '\r', '\t' => {},
            '"' => self.string(),
            '\n' => {
                self.line += 1;
            },
            'o' => {
                if (self.match('r')) {
                    self.add_token(.OR);
                }
            },
            inline else => {
                if (is_digit(c)) {
                    try self.number();
                } else if (is_alpha(c)) {
                    self.identifier();
                } else {
                    self.err(self.line, "Unexpected character: " ++ .{c});
                    return ScannerError.UnexpectedCharacter;
                }
            },
        }
    }

    pub fn is_digit(c: u8) bool {
        return c >= '0' and c <= '9';
    }

    pub fn is_alpha(c: u8) bool {
        return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
    }

    pub fn is_alphanumeric(c: u8) bool {
        return is_alpha(c) or is_digit(c);
    }

    pub fn identifier(self: *@This()) void {
        while (is_alphanumeric(self.peek())) {
            _ = self.next();
        }
        var ident = self.source[self.start..self.current];
        self.add_token(ident_map.get(ident) orelse .IDENTIFIER);
    }

    pub fn number(self: *@This()) !void {
        var is_float = false;

        while (is_digit(self.peek())) {
            _ = self.next();
        }

        if (self.peek() == '.' and is_digit(self.peek_next())) {
            is_float = true;
            _ = self.next();
        }

        while (is_digit(self.peek())) {
            _ = self.next();
        }

        if (is_float) {
            var num = try std.fmt.parseFloat(f32, self.source[self.start..self.current]);
            self.add_token_with_literal(
                .NUMBER,
                TokenLiteral{ .Float = num },
            );
        } else {
            var num = try std.fmt.parseInt(isize, self.source[self.start..self.current], 10);
            self.add_token_with_literal(
                .NUMBER,
                TokenLiteral{ .Integer = num },
            );
        }
    }

    pub fn comment(self: *@This()) void {
        while (self.peek() != '\n' and !self.is_at_end()) {
            _ = self.next();
        }
        self.add_token_with_literal(
            .COMMENT,
            TokenLiteral{ .String = self.source[self.start + 2 .. self.current] },
        );
    }

    pub fn block_comment(self: *@This()) void {
        while (self.peek() != '*' and self.peek_next() != '/' and !self.is_at_end()) {
            _ = self.next();
        }
        if (self.is_at_end()) {
            self.err(self.line, "Unterminated block comment");
            return;
        }
        self.current += 2;
        self.add_token_with_literal(
            .BLOCK_COMMENT,
            TokenLiteral{ .String = self.source[self.start + 2 .. self.current - 2] },
        );
    }

    pub fn string(self: *@This()) void {
        while (self.peek() != '"' and !self.is_at_end()) {
            if (self.peek() == '\n') {
                self.line += 1;
            }
            _ = self.next();
        }
        if (self.is_at_end()) {
            self.err(self.line, "Unterminated string.");
            return;
        }
        _ = self.next();

        var str = self.source[self.start + 1 .. self.current - 1];
        self.add_token_with_literal(
            .STRING,
            TokenLiteral{ .String = str },
        );
    }

    pub fn peek_next(self: @This()) u8 {
        if (self.current + 1 >= self.source.len) return 0x00;
        return self.source[self.current + 1];
    }
    pub fn peek(self: *@This()) u8 {
        if (self.is_at_end()) return 0x00;
        return self.source[self.current];
    }

    pub fn match(self: *@This(), c: u8) bool {
        if (self.is_at_end()) return false;
        if (self.source[self.current] != c) return false;
        self.current += 1;
        return true;
    }

    pub fn add_token(self: *@This(), token_type: TokenType) void {
        self.add_token_with_literal(token_type, .Empty);
    }

    pub fn add_token_with_literal(self: *@This(), token_type: TokenType, literal: TokenLiteral) void {
        var text = self.source[self.start..self.current];
        self.tokens.append(Token{
            .token_type = token_type,
            .lexeme = text,
            .literal = literal,
            .line = self.line,
        }) catch |e| {
            std.debug.print("{any}\n", .{e});
            std.os.exit(1);
        };
    }

    pub fn next(self: *@This()) u8 {
        self.current += 1;
        return self.source[self.current - 1];
    }

    pub fn is_at_end(self: *@This()) bool {
        return self.current >= (self.source.len);
    }
};
