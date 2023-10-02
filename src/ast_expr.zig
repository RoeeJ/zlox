const std = @import("std");
const Token = @import("ast.zig").Token;
const TokenType = @import("ast.zig").TokenType;

pub const ExprType = enum {
    Expr,
    Binary,
    Grouping,
    Literal,
    Unary,
};

pub const Expression = union(ExprType) {
    Expr: struct {
        left: Expression.Expr,
        operator: Token,
        right: Expression.Expr,
    },
    Binary: struct {
        left: Expression.Expr,
        operator: Token,
        right: Expression.Expr,
    },
    Grouping: struct {
        expression: Expression.Expr,
    },
    Unary: struct {
        operator: Token,
        right: Expression.Expr,
    },
    Literal: struct {
        literal: []u8,
    },
};

pub fn ExprVisitor(exp: Expression) []u8 {
    switch (exp) {
        .Expr => |expr| {
            std.debug.print("{}\n", .{expr});
        },
        .Binary => |expr| {
            std.debug.print("{}\n", .{expr});
        },
        .Grouping => |expr| {
            std.debug.print("{}\n", .{expr});
        },
        .Literal => |expr| {
            std.debug.print("{}\n", .{expr});
        },
        .Unary => |expr| {
            std.debug.print("{}\n", .{expr});
        },
    }
}

fn parenthesize(name: []u8, exprs: []Expression) []u8 {
    var out = std.ArrayList(u8).init(std.heap.c_allocator);
    try out.append('(');
    try out.appendSlice(name);

    for (exprs) |expr| {
        try out.append(' ');
        try out.appendSlice(ExprVisitor(expr));
    }
    try out.append(')');

    return out.items;
}

test "expressions" {
    const testing = std.testing;
    _ = testing;
    var unary_expr = Expression{ .Binary = Expression{ .Unary = Expression{ .operator = Token{
        .token_type = TokenType.MINUS,
        .line = 1,
        .lexeme = "-",
    } } } };

    _ = unary_expr;
}
