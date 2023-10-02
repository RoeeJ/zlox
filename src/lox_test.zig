const std = @import("std");
const Scanner = @import("scanner.zig").Scanner;
const Lox = @import("lox.zig");

test "lex" {
    std.debug.print("\n", .{});
    const testing = std.testing;
    var test_source = try Lox.read_file(@constCast(@ptrCast("./test.lox")));

    var scanner = Scanner.init(test_source);

    try scanner.scan_tokens();

    for (scanner.tokens.items) |token| {
        std.debug.print("{s}\n", .{token.string()});
    }
    try scanner.scan_tokens();
    try testing.expect(true);
}
