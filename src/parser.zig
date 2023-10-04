const std = @import("std");
const AST = @import("ast.zig");
const Token = AST.Token;
const TokenLiteral = AST.TokenLiteral;
const TokenType = AST.TokenType;
const AST_EXPR = @import("ast_expr.zig");
const Expression = AST_EXPR.Expression;

pub const ParserError = error{ ParseError, ExpressionExpected, RuntimeError };

pub const Parser = struct {
    const allocator = std.heap.c_allocator;

    tokens: []Token,
    current: usize,
    line: usize,

    pub fn init(tokens: []Token) @This() {
        return Parser{
            .tokens = tokens,
            .current = 0,
            .line = 0,
        };
    }

    pub fn expression(self: *@This()) !Expression {
        return self.equality();
    }
    pub fn equality(self: *@This()) !Expression {
        var expr = try self.comparison();

        const token_types = [_]TokenType{ .BANG_EQUAL, .EQUAL_EQUAL };
        while (self.match(@constCast(&token_types))) {
            var operator = try self.previous();
            var right = try self.comparison();
            expr = Expression{
                .Binary = AST_EXPR.BinaryExpression{
                    .left = &expr,
                    .operator = operator,
                    .right = &right,
                },
            };
        }

        return expr;
    }

    pub fn comparison(self: *@This()) !Expression {
        var expr = try self.term();
        const token_types = [_]TokenType{ .GREATER, .GREATER_EQUAL, .LESS, .LESS_EQUAL };
        while (self.match(@constCast(&token_types))) {
            var operator = try self.previous();
            var right = try self.term();
            expr = Expression{ .Binary = AST_EXPR.BinaryExpression{
                .left = &expr,
                .operator = operator,
                .right = &right,
            } };
        }

        return expr;
    }

    pub fn term(self: *@This()) !Expression {
        var expr = try self.factor();
        const token_types = [_]TokenType{ .MINUS, .PLUS };
        while (self.match(@constCast(&token_types))) {
            var operator = try self.previous();
            var right = try self.factor();
            expr = Expression{ .Binary = AST_EXPR.BinaryExpression{
                .left = &expr,
                .operator = operator,
                .right = &right,
            } };
        }
        return expr;
    }

    pub fn factor(self: *@This()) !Expression {
        var expr = try self.unary();
        const token_types = [_]TokenType{ .SLASH, .STAR };
        while (self.match(@constCast(&token_types))) {
            var operator = try self.previous();
            var right = try self.unary();
            expr = Expression{ .Binary = AST_EXPR.BinaryExpression{
                .left = &expr,
                .operator = operator,
                .right = &right,
            } };
        }
        return expr;
    }

    pub fn unary(self: *@This()) !Expression {
        const token_types = [_]TokenType{ .BANG, .MINUS };
        if (self.match(@constCast(&token_types))) {
            var operator = try self.previous();
            var right = try self.unary();
            return Expression{ .Unary = AST_EXPR.UnaryExpression{
                .operator = operator,
                .right = &right,
            } };
        }
        return self.primary();
    }

    pub fn primary(self: *@This()) ParserError!Expression {
        var false_token_types = [_]TokenType{.FALSE};
        if (self.match(false_token_types[0..])) {
            return self.exp_lit(TokenLiteral{ .Bool = false });
        }

        var true_token_types = [_]TokenType{.TRUE};
        if (self.match(true_token_types[0..])) {
            return self.exp_lit(TokenLiteral{ .Bool = true });
        }

        var nil_token_types = [_]TokenType{.NIL};
        if (self.match(nil_token_types[0..])) {
            return self.exp_lit(.NIL);
        }

        var lit_token_types = [_]TokenType{ .NUMBER, .STRING };
        if (self.match(lit_token_types[0..])) {
            var prev = try self.previous();
            return self.exp_lit(prev.literal);
        }

        var paren_token_types = [_]TokenType{.LEFT_PAREN};
        if (self.match(paren_token_types[0..])) {
            var expr = try self.expression();
            _ = self.consume(.RIGHT_PAREN, "Expected ')' after expression.") catch {};
            return self.exp_group(expr);
        }

        return ParserError.ExpressionExpected;
    }

    pub fn match(self: *@This(), types: []TokenType) bool {
        for (types) |token_type| {
            if (self.check(token_type)) {
                _ = self.next();
                return true;
            }
        }
        return false;
    }

    pub fn check(self: *@This(), token_type: TokenType) bool {
        if (self.is_at_end()) return false;
        return self.peek().token_type == token_type;
    }

    pub fn is_at_end(self: *@This()) bool {
        return self.peek().token_type == TokenType.EOF;
    }

    pub fn next(self: *@This()) Token {
        if (self.is_at_end()) {
            return Token{
                .token_type = TokenType.EOF,
                .lexeme = &.{},
                .literal = .Empty,
                .line = self.line,
            };
        }
        self.current += 1;
        return self.tokens[self.current - 1];
    }

    pub fn previous(self: *@This()) !Token {
        return self.tokens[self.current - 1];
    }

    pub fn peek(self: *@This()) Token {
        if (self.current >= self.tokens.len) {
            return Token{
                .token_type = TokenType.EOF,
                .lexeme = &.{},
                .literal = .Empty,
                .line = self.line,
            };
        }
        return self.tokens[self.current];
    }

    pub fn peek_next(self: *@This()) Token {
        if (self.current + 1 >= self.tokens.len) {
            return Token{
                .token_type = .EOF,
                .lexeme = @constCast(&[_]u8{}),
                .literal = .Empty,
                .line = self.line,
            };
        }
        return self.tokens[self.current + 1];
    }

    pub fn consume(self: *@This(), token_type: TokenType, err_msg: []const u8) ParserError!Token {
        if (self.check(token_type)) {
            return self.next();
        }
        self.err(self.peek(), err_msg);
        return ParserError.ParseError;
    }

    pub fn exp_lit(self: *@This(), literal: TokenLiteral) Expression {
        _ = self;
        return Expression{
            .Literal = AST_EXPR.LiteralExpression{
                .literal = literal,
            },
        };
    }

    pub fn exp_group(self: *@This(), expr: Expression) Expression {
        _ = self;
        return Expression{
            .Grouping = AST_EXPR.GroupingExpression{
                .expression = &expr,
            },
        };
    }

    pub fn err(self: *@This(), token: Token, msg: []const u8) void {
        if (token.token_type == .EOF) {
            self.report(token.line, " at end", msg);
        } else {
            var err_msg = std.ArrayList(u8).init(Parser.allocator);
            err_msg.appendSlice(" at '") catch {};
            err_msg.appendSlice(token.lexeme) catch {};
            err_msg.appendSlice("'") catch {};
            self.report(token.line, err_msg.items, msg);
        }
    }

    pub fn report(self: *@This(), line: usize, where: []const u8, message: []const u8) void {
        _ = self;
        std.debug.print("[line {}] Error {s}: {s}\n", .{ line, where, message });
    }

    pub fn synchronize(self: *@This()) ParserError!void {
        _ = self.next();
        while (!self.is_at_end()) {
            if (self.previous().token_type == .SEMICOLON) {
                return;
            }
            switch (self.peek().token_type) {
                .CLASS, .FUN, .VAR, .FOR, .IF, .WHILE, .PRINT, .RETURN => {
                    return;
                },
            }
            _ = self.next();
        }
    }

    pub fn parse(self: *@This()) ParserError!Expression {
        return self.expression();
    }
};

test "parser" {
    const testing = std.testing;
    const Scanner = @import("scanner.zig").Scanner;
    const scanner = @constCast(&try Scanner.init_with_file("./test_parser.lox"));
    try scanner.scan_tokens();
    var parser = Parser.init(scanner.tokens.items);
    var expr = try parser.parse();

    std.debug.print("{any}\n", .{expr});

    try testing.expect(true);
}
