const std = @import("std");
const environ = @import("environ.zig");
const BfEnvironment = environ.BfEnvironment;

pub const std_options: std.Options = .{
    .log_level = .warn,
};

const BfMode = union(enum) {
    interpret,
    compile, // TODO
    transpile: environ.Language, // TODO
};

const ArgsStruct = struct {
    file_name: []const u8,
    tape_length: ?usize,
    mode: BfMode,
    repl_mode: bool,

    pub fn deinit(self: ArgsStruct, allocator: std.mem.Allocator) void {
        allocator.free(self.file_name);
    }
};

pub fn parseArgs(allocator: std.mem.Allocator) !ArgsStruct {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            std.debug.print(
            \\Usage: bfc -f [filename] -i (extra flags)
            \\
            \\    Flags:
            \\    -f [string], --file=[string]    (REQUIRED) File to process
            \\    -i,          --interpret        (REQUIRED (for now)) Interpret the source file
            \\    -c           --compile          (UNIMPLEMENTED) Compile the source file
            \\    -t [lang]    --transpile=[lang] (UNIMPLEMENTED) Transpile the source file
            \\    -l [usize],  --len=[usize]      Length of the tape
            \\    -h,          --help             Print this message then exit
            \\    --repl                          Start Brainfuck REPL
            \\
            , .{});
            return error.Exit0; // This is to gracefully return from the function, avoiding memory leaks
        }
    }

    var tape_length: ?usize = null;
    var repl_mode = false;
    var mode: ?BfMode = null;
    var file_name: ?[]const u8 = null;
    errdefer if (file_name) |fname| allocator.free(fname);

    {var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--repl")) {
            if (repl_mode) {
                std.log.err("Repeat of already defined flag '{s}'", .{arg});
            }

            repl_mode = true;
            continue;
        }
        if (std.mem.eql(u8, arg, "-i") or std.mem.eql(u8, arg, "--interpret")) {
            if (mode != null) {
                std.log.err("Repeat of already defined flag: '{s}'", .{arg});
                return error.Repeat;
            }

            mode = .interpret;
            continue;
        }
        if (std.mem.eql(u8, arg, "-c") or std.mem.eql(u8, arg, "--compile")) {
            if (mode != null) {
                std.log.err("Repeat of already defined flag: '{s}'", .{arg});
                return error.Repeat;
            }

            mode = .compile;
            continue;
        }
        if (std.mem.eql(u8, arg, "-t")) {
            if (mode != null) {
                std.log.err("Repeat of already defined flag: '{s}'", .{arg});
                return error.Repeat;
            }

            if (i == args.len-1) {
                std.log.err("Missing required parameter for argument -t", .{});
                return error.MissingValue;
            }

            i += 1;
            const str_to_enum = std.meta.stringToEnum(environ.Language, args[i]);

            if (str_to_enum == null) {
                std.log.err(
                    \\Invalid language provided: '{s}'
                    \\
                    \\List of valid languages:
                    \\    zig
                    \\    c
                    \\    cpp
                    \\    rust
                    \\    python
                    \\    js
                    \\    go
                , .{args[i]});
                return error.InvalidLang;
            }

            mode = .{ .transpile = str_to_enum.? };
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--transpile=")) {
            if (mode != null) {
                std.log.err("Repeat of already defined flag: '{s}'", .{arg});
                return error.Repeat;
            }

            const lang = arg[12..];
            if (lang.len == 0) {
                std.log.err("No value provided for argument --transpile=[lang]", .{});
                return error.MissingValue;
            }

            const str_to_enum = std.meta.stringToEnum(environ.Language, lang);

            if (str_to_enum == null) {
                std.log.err(
                    \\Invalid language provided: '{s}'
                    \\
                    \\List of valid languages:
                    \\    zig
                    \\    c
                    \\    cpp
                    \\    rust
                    \\    python
                    \\    js
                    \\    go
                , .{lang});
                return error.InvalidLang;
            }

            mode = .{ .transpile = str_to_enum.? };
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

            i += 1;
            file_name = try allocator.dupe(u8, args[i]);
            continue;
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
            continue;
        }
        std.log.err("Unknown flag or parameter: '{s}'", .{arg});
        return error.Unknown;
    }}

    if (mode == null and !repl_mode) {
        std.log.err("Missing flag -i, -c, or -t", .{});
        return error.MissingFlag;
    }
    if (file_name == null and !repl_mode) {
        std.log.err("Missing input file (hint use -f)", .{});
        return error.MissingFlag;
    }

    return .{
        .file_name = file_name orelse "",
        .tape_length = tape_length,
        .mode = mode orelse .interpret,
        .repl_mode = repl_mode,
    };
}

pub fn REPL(allocator: std.mem.Allocator, tape: []u8) !void {
    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(stdout_buf[0..]);
    const stdout = &stdout_writer.interface;

    var stdin_buf: [4096]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(stdin_buf[0..]);
    const stdin = &stdin_reader.interface;

    var bf: BfEnvironment = .init(stdout, stdin, tape[0..]);

    try stdout.print("info: Write 'END' to quit the REPL gracefully\n", .{});
    var eval_input: std.Io.Writer.Allocating = .init(allocator);
    defer eval_input.deinit();

    while (true) {
        try stdout.print(">>> ", .{});
        try stdout.flush();

        var do_toss = true;
        _ = stdin.streamDelimiter(&eval_input.writer, '\n') catch |e| {
            if (e != error.EndOfStream) {
                return e;
            }
            do_toss = false;
        };
        if (do_toss) stdin.toss(1);

        var input = eval_input.written();
        if (input[input.len-1] == '\r') {
            input.len -= 1;
        }
        if (std.mem.eql(u8, input, "END")) {
            break;
        }

        try bf.exec(allocator, input);
        stdin.tossBuffered();

        var end_idx: usize = undefined;
        {var i = tape.len-1;
        while (i > 0 and tape[i] == 0) {
            i -= 1;
        }end_idx = i+1;}

        try stdout.writeAll("\n{");
        for (tape[0..end_idx], 0..) |cell, idx| {
            try stdout.print("{}", .{cell});
            if (idx != end_idx-1) {
                try stdout.writeAll(", ");
            }
        }
        try stdout.writeAll("}\n");

        eval_input.clearRetainingCapacity();
    }
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

    if (args.repl_mode) {
        const tape = try gpa.alloc(u8, args.tape_length orelse 30_000);
        defer gpa.free(tape);
        @memset(tape, 0);

        try REPL(gpa, tape);
        return;
    }

    if (args.mode != .interpret) {
        std.log.err("Use of unimplemented mode: '{s}'", .{@tagName(args.mode)});
        return error.WrongMode;
    }

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

    const tape = try gpa.alloc(u8, args.tape_length orelse 30_000);
    defer gpa.free(tape);

    @memset(tape, 0);

    var bf: BfEnvironment = .init(stdout, stdin, tape[0..]);

    try bf.exec(gpa, content);
}
