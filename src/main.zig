const std = @import("std");
const BfEnvironment = @import("environ.zig").BfEnvironment;

const ArgsStruct = struct {
    file_name: []const u8,
    tape_length: ?usize,
};

pub fn parseArgs(allocator: std.mem.Allocator) !ArgsStruct {
    _ = allocator;
    return .{ .file_name = "", .tape_length = null, };
}

pub fn main() !void {
    const gpa = std.heap.smp_allocator;

    const args = try parseArgs(gpa);

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(stdout_buf[0..]);
    const stdout = &stdout_writer.interface;

    var stdin_buf: [4096]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(stdin_buf[0..]);
    const stdin = &stdin_reader.interface;

    var tape = try gpa.alloc(u8, args.tape_length orelse 30_000);
    defer gpa.free(tape);

    var bf: BfEnvironment = .init(stdout, stdin, tape[0..]);
    _ = &bf;
}
