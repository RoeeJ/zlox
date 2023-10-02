const std = @import("std");
const Scanner = @import("scanner.zig").Scanner;
pub const allocator = std.heap.c_allocator;

pub fn dbg(comptime str: []const u8, args: anytype) void {
    std.debug.print(str ++ "\n", args);
}

pub fn run_file(filepath: []u8) !void {
    return run(try read_file(filepath));
}

pub fn read_file(filepath: []u8) ![]u8 {
    var file = try std.fs.cwd().openFile(filepath, .{});
    defer file.close();
    var stat = try file.stat();
    var buf = try allocator.alloc(u8, stat.size);
    var bread = try file.readAll(buf);
    return buf[0..bread];
}

pub fn run(buf: []u8) !void {
    var scanner = Scanner.init(buf);
    try scanner.scan_tokens();
    if (scanner.had_error) {
        std.os.exit(65);
    }
    for (scanner.tokens.items) |token| {
        std.debug.print("{s}\n", .{token.string()});
    }
}

pub fn run_prompt() !void {
    var inp = std.io.getStdIn().reader();
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    var bw = buf.writer();
    while (true) {
        try inp.streamUntilDelimiter(bw, '\n', null);
        if (buf.items.len == 0) {
            break;
        }
        dbg("> {s}", .{buf.items});
        try run(buf.items);
        buf.clearAndFree();
    }
}
