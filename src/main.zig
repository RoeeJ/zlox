const std = @import("std");
const allocator = std.heap.c_allocator;
const lox = @import("lox.zig");

const dbg = lox.dbg;
const version = "0.0.1";

pub fn main() !void {
    var args = try std.process.argsAlloc(allocator);
    if (args.len != 2) {
        dbg("Usage: {s} <file.lox>", .{args[0]});
        std.os.exit(64);
        unreachable;
    }
    var filename = args[1];
    if (filename.len == 1 and filename[0] == '-') {
        std.debug.print("ZLox REPL started:\n", .{});
        try lox.run_prompt();
    } else {
        try lox.run_file(filename);
    }
}

test "simple test" {}
