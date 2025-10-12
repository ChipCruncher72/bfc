const std = @import("std");
const BfEnvironment = @import("environ.zig").BfEnvironment;

pub const std_options: std.Options = .{
    .log_level = .warn,
};

const BfMode = enum {
    interpret,
    compile, // TODO
    transpile, // TODO
};

const ArgsStruct = struct {
    file_name: []const u8,
    tape_length: ?usize,
    mode: BfMode,

    pub fn deinit(self: ArgsStruct, allocator: std.mem.Allocator) void {
        allocator.free(self.file_name);
    }
};

pub fn parseArgs(allocator: std.mem.Allocator) !ArgsStruct {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            std.debug.print(
            \\Usage: bfc -f [filename] -i (extra flags)
            \\
            \\    Flags:
            \\    -f [string], --file=[string] (REQUIRED) File to process
            \\    -i,          --interpret     (REQUIRED (for now)) Interpret the source files
            \\    -l [usize],  --len=[usize]   Length of the tape
            \\    -h,          --help          Print this message then exit
            \\
            , .{});
            return error.Exit0; // This is to gracefully return from the function, avoiding memory leaks
        }
    }

    var tape_length: ?usize = null;
    var mode: ?BfMode = null;
    var file_name: ?[]const u8 = null;

    {var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-i") or std.mem.eql(u8, arg, "--interpret")) {
            if (mode != null) {
                std.log.err("Repeat of already defined flag: '{s}'", .{arg});
                return error.Repeat;
            }

            mode = .interpret;
            continue;
        }
        if (std.mem.eql(u8, arg, "-l")) {
            if (tape_length != null) {
                std.log.err("Repeat of already defined flag: '{s}'", .{arg});
                return error.Repeat;
            }

            if (i == args.len-1) {
                std.log.err("Missing required parameter for argument -l", .{});
                return error.MissingValue;
            }

            i += 1;
            const num = args[i];

            tape_length = std.fmt.parseUnsigned(usize, num, 0) catch |e| {
                switch (e) {
                    error.Overflow => std.log.err("Integer '{s}' too large to be stored in a {}-bit unsigned integer", .{
                        num,
                        @bitSizeOf(usize),
                    }),
                    error.InvalidCharacter => std.log.err("String '{s}' is not a valid unsigned integer", .{num}),
                }
                return e;
            };
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--len=")) {
            if (tape_length != null) {
                std.log.err("Repeat of already defined flag: '{s}'", .{arg});
                return error.Repeat;
            }

            const num = arg[6..];
            if (num.len == 0) {
                std.log.err("No value provided for argument --len=[usize]", .{});
                return error.MissingValue;
            }

            tape_length = std.fmt.parseUnsigned(usize, num, 0) catch |e| {
                switch (e) {
                    error.Overflow => std.log.err("Integer '{s}' too large to be stored in a {}-bit unsigned integer", .{
                        num,
                        @bitSizeOf(usize),
                    }),
                    error.InvalidCharacter => std.log.err("String '{s}' is not a valid unsigned integer", .{num}),
                }
                return e;
            };
            continue;
        }
        if (std.mem.eql(u8, arg, "-f")) {
            if (file_name != null) {
                std.log.err("Repeat of already defined flag: '{s}'", .{arg});
                return error.Repeat;
            }

            if (i == args.len-1) {
                std.log.err("Missing required parameter for argument -f", .{});
                return error.MissingValue;
            }

            file_name = try allocator.dupe(u8, args[i+1]);
        }
        if (std.mem.startsWith(u8, arg, "--file=")) {
            if (file_name != null) {
                std.log.err("Repeat of already defined flag: '{s}'", .{arg});
                return error.Repeat;
            }

            const file = arg[7..];
            if (file.len == 0) {
                std.log.err("No value provided for argument --file=[string]", .{});
                return error.MissingValue;
            }

            file_name = try allocator.dupe(u8, file);
        }
    }}

    if (mode == null) {
        std.log.err("Missing flag -i, -c, or -t", .{});
        return error.MissingFlag;
    }
    if (file_name == null) {
        std.log.err("Missing input file (hint use -f)", .{});
        return error.MissingFlag;
    }

    return .{ .file_name = file_name.?, .tape_length = tape_length, .mode = mode.? };
}

pub fn main() !void {
    const gpa = std.heap.smp_allocator;

    const args = parseArgs(gpa) catch |e| {
        switch (e) {
            error.Exit0 => std.process.exit(0),
            else => return e,
        }
    };
    defer args.deinit(gpa);

    const file_extention = args.file_name[(std.mem.lastIndexOfScalar(u8, args.file_name, '.') orelse args.file_name.len)..];
    if (!std.mem.eql(u8, file_extention, ".bf") and !std.mem.eql(u8, file_extention, ".b")) {
        if (file_extention.len == 0) {
            std.log.warn("No file extention in source file name (NOTE: This may become a compile error in future versions)", .{});
        } else {
            std.log.warn("File extention '{s}' is not a standard brainfuck extention (NOTE: This may become a compile error in future versions)", .{file_extention[1..]});
        }
    }

    var bf_source = std.fs.cwd().openFile(args.file_name, .{}) catch |e| {
        std.log.err("Failure trying to open source file '{s}': {}", .{args.file_name, e});
        return e;
    };
    defer bf_source.close();

    const content = try gpa.alloc(u8, try bf_source.getEndPos());
    defer gpa.free(content);

    _ = bf_source.readAll(content) catch |e| {
        std.log.err("Failure trying to read source file '{s}': {}", .{args.file_name, e});
        return e;
    };

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(stdout_buf[0..]);
    const stdout = &stdout_writer.interface;

    var stdin_buf: [4096]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(stdin_buf[0..]);
    const stdin = &stdin_reader.interface;

    var tape = try gpa.alloc(u8, args.tape_length orelse 30_000);
    defer gpa.free(tape);

    @memset(tape, 0);

    var bf: BfEnvironment = .init(stdout, stdin, tape[0..]);

    try bf.exec(gpa, content);
}
