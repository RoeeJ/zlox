const std = @import("std");
const Token = @import("ast.zig").Token;
const TokenLiteral = @import("ast.zig").TokenLiteral;
const TokenType = @import("ast.zig").TokenType;

pub const ExprType = enum {
    Binary,
    Grouping,
    Literal,
    Unary,
};

pub const BinaryExpression = struct {
    left: *const Expression,
    operator: Token,
    right: *const Expression,
};

pub const GroupingExpression = struct {
    expression: *const Expression,
};

pub const UnaryExpression = struct {
    operator: Token,
    right: *const Expression,
};

pub const LiteralExpression = struct {
    literal: TokenLiteral,
};

pub const Expression = union(ExprType) {
    Binary: BinaryExpression,
    Grouping: GroupingExpression,
    Unary: UnaryExpression,
    Literal: LiteralExpression,
    pub fn visit(self: @This()) []u8 {
        switch (self) {
            .Binary => |expr| {
                var exprs = [2]Expression{
                    expr.left.*, expr.right.*,
                };
                return parenthesize(expr.operator.lexeme, exprs[0..]);
            },
            .Grouping => |expr| {
                var exprs = [1]Expression{expr.expression.*};
                return parenthesize(@constCast("group"), exprs[0..]);
            },
            .Literal => |expr| {
                switch (expr.literal) {
                    .Float => |n| {
                        var buf = std.ArrayList(u8).init(std.heap.c_allocator); // Specify an appropriate buffer size for your needs
                        std.fmt.formatFloatDecimal(n, .{}, buf.writer()) catch {};

                        return buf.items;
                    },
                    .Integer => |n| {
                        var buf = std.ArrayList(u8).init(std.heap.c_allocator); // Specify an appropriate buffer size for your needs
                        std.fmt.formatInt(n, 10, .upper, .{}, buf.writer()) catch {};

                        return buf.items;
                    },
                    .String => |s| {
                        return s;
                    },
                    .Bool => {},
                    .Empty => {},
                    .NIL => {},
                }
            },
            .Unary => |expr| {
                var exprs = [1]Expression{expr.right.*};
                return parenthesize(expr.operator.lexeme, exprs[0..]);
            },
        }
        unreachable;
    }
};

fn parenthesize(name: []u8, exprs: []Expression) []u8 {
    var out = std.ArrayList(u8).init(std.heap.c_allocator);
    out.append('(') catch {};
    out.appendSlice(name) catch {};

    for (exprs) |expr| {
        out.append(' ') catch {};
        var visited = expr.visit();
        out.appendSlice(visited) catch {};
    }
    out.append(')') catch {};

    return out.items;
}
pub const ast_expr = Expression{
    .Binary = BinaryExpression{
        .left = @constCast(&Expression{
            .Unary = UnaryExpression{
                .operator = Token.init(TokenType.MINUS, @constCast("-"), TokenLiteral{ .String = @constCast("-") }, 1),
                .right = @constCast(&Expression{
                    .Literal = LiteralExpression{
                        .literal = TokenLiteral{
                            .Integer = 123,
                        },
                    },
                }),
            },
        }),
        .operator = Token{
            .line = 1,
            .lexeme = @constCast("*"),
            .token_type = .STAR,
            .literal = TokenLiteral{ .String = @constCast("*") },
        },
        .right = @constCast(&Expression{
            .Grouping = GroupingExpression{
                .expression = @constCast(&Expression{
                    .Literal = LiteralExpression{
                        .literal = TokenLiteral{ .Integer = 4567 },
                    },
                }),
            },
        }),
    },
};
test "expressions" {
    const testing = std.testing;
    try testing.expectEqualStrings("(* (- 123) (group 4567))", ast_expr.visit());
    return;
}
