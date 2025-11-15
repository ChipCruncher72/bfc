const std = @import("std");
const clap = @import("clap");
const environ = @import("environ.zig");
const BfEnvironment = environ.BfEnvironment;

const DEFAULT_TAPE_LENGTH = 30_000;

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
    input_file: ?[]const u8,
    output_file: ?[]const u8,
    tape_length: usize,
    mode: BfMode,
    repl_mode: bool,

    pub fn deinit(self: ArgsStruct, allocator: std.mem.Allocator) void {
        allocator.free(self.file_name);
        if (self.output_file) |output|
            allocator.free(output);
        if (self.input_file) |input|
            allocator.free(input);
    }
};

pub fn parseArgs(allocator: std.mem.Allocator) !ArgsStruct {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help              Print this help message then exit
        \\-f, --file <FILE>       (REQUIRED) Input file to parse
        \\    --input <FILE>      Input file to read from using `,` instruction (INTERPRET ONLY)
        \\    --output <FILE>     Output file to write to using `.` instruction (INTERPRET ONLY)
        \\-i, --interpret         Interpret the input files
        \\-c, --compile           (UNIMPLEMENTED) Compile the input files
        \\-t, --transpile <LANG>  Transpile the input files
        \\-l, --length <usize>    Length of the tape
        \\    --repl              Start the Brainfuck REPL
    );
    const parsers = comptime .{
        .FILE = clap.parsers.string,
        .LANG = clap.parsers.enumeration(environ.Language),
        .usize = clap.parsers.int(usize, 0),
    };

    var diag: clap.Diagnostic = .{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        switch (err) {
            // Transpile flag failed to parse
            error.NameNotPartOfEnum => {
                std.log.err(
                    \\Invalid language provided to transpile flag
                    \\
                    \\List of valid languages:
                    \\    zig
                    \\    c
                    \\    cpp
                    \\    rust
                    \\    python
                    \\    js
                    \\    go
                , .{});
                return error.InvalidLang;
            },
            // Length flag failed to parse
            error.Overflow => {
                std.log.err("Integer too big to fit into a {}-bit unsigned integer (flag --length)", .{@bitSizeOf(usize)});
                return err;
            },
            error.InvalidCharacter => {
                std.log.err("Provided value is not a valid unsigned integer (flag --length)", .{});
                return err;
            },

            else => {},
        }

        try diag.reportToFile(.stderr(), err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        std.debug.print("Usage: bfc ", .{});
        try clap.usageToFile(.stderr(), clap.Help, &params);
        std.debug.print("\n", .{});
        try clap.helpToFile(.stderr(), clap.Help, &params, .{});
        std.debug.print("\n", .{});
        return error.Exit0; // This is to exit gracefully, ensuring we don't leak memory
    }
    if (res.args.repl != 0) {
        return .{
            .file_name = &.{},
            .mode = undefined,
            .input_file = null,
            .output_file = null,
            .tape_length = res.args.length orelse DEFAULT_TAPE_LENGTH,
            .repl_mode = true,
        };
    }
    if (res.args.file == null) {
        std.log.err("Missing input file (Hint: use -f)", .{});
        return error.MissingFlag;
    }

    var mode: ?BfMode = null;

    if (res.args.interpret != 0) {
        mode = .interpret;
    } else if (res.args.compile != 0) {
        mode = .compile;
    } else if (res.args.transpile) |t| {
        mode = .{ .transpile = t };
    }

    if (mode == null) {
        std.log.err("Missing flag -i, -c, or -t", .{});
        return error.MissingFlag;
    }

    var allocated_input: ?[]const u8 = null;
    errdefer if (allocated_input) |input| allocator.free(input);
    var allocated_output: ?[]const u8 = null;
    errdefer if (allocated_output) |output| allocator.free(output);
    if (res.args.input) |input|
        allocated_input = try allocator.dupe(u8, input);
    if (res.args.output) |output|
        allocated_output = try allocator.dupe(u8, output);

    return .{
        .mode = mode.?,
        .tape_length = res.args.length orelse DEFAULT_TAPE_LENGTH,
        .file_name = try allocator.dupe(u8, res.args.file.?),
        .input_file = allocated_input,
        .output_file = allocated_output,
        .repl_mode = false,
    };
}

pub fn REPL(allocator: std.mem.Allocator, tape: []u8, stdout: *std.Io.Writer, stdin: *std.Io.Reader) !void {
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

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    var stdout = &stdout_writer.interface;
    const og_stdout = &stdout_writer.interface;
    defer if (og_stdout != stdout) stdout_writer.file.close();

    if (args.output_file) |output| if (args.mode == .interpret) {
        stdout_writer = (std.fs.cwd().createFile(output, .{}) catch |e| {
            std.log.err("Failure trying to create output file '{s}': {}", .{output, e});
            return e;
        }).writer(&stdout_buf);
        stdout = &stdout_writer.interface;
    };

    var stdin_buf: [4096]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buf);
    var stdin = &stdin_reader.interface;
    const og_stdin = &stdin_reader.interface;
    defer if (og_stdin != stdin) stdin_reader.file.close();

    if (args.input_file) |input| if (args.mode == .interpret) {
        stdin_reader = (std.fs.cwd().openFile(input, .{}) catch |e| {
            std.log.err("Failure trying to open input file '{s}': {}", .{input, e});
            return e;
        }).reader(&stdin_buf);
        stdin = &stdin_reader.interface;
    };

    if (args.repl_mode) {
        const tape = try gpa.alloc(u8, args.tape_length);
        defer gpa.free(tape);
        @memset(tape, 0);

        try REPL(gpa, tape, stdout, stdin);
        return;
    }

    if (args.mode == .compile) {
        std.log.err("Use of unimplemented mode: 'compile'", .{});
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

    const tape = try gpa.alloc(u8, args.tape_length);
    defer gpa.free(tape);

    @memset(tape, 0);

    switch (args.mode) {
        .interpret => {
            var bf: BfEnvironment = .init(stdout, stdin, tape);
            try bf.exec(gpa, content);
        },
        .transpile => |lang| switch (lang) {
            .c, .cpp => {
                const out_file_name = try std.fmt.allocPrint(gpa, "{s}.{s}", .{args.file_name, @tagName(lang)});
                defer gpa.free(out_file_name);

                var file_buf: [4096]u8 = undefined;
                var file_writer = (std.fs.cwd().createFile(out_file_name, .{}) catch |e| {
                    std.log.err("Failure trying to create transpiled source: {}", .{e});
                    return e;
                }).writer(file_buf[0..]);
                defer file_writer.file.close();

                var reader = std.Io.Reader.failing;

                const bf: BfEnvironment = .init(&file_writer.interface, &reader, tape);
                try bf.transpileCCPP(content);
            },
            else => {
                std.log.err("Language '{s}' unimplemented", .{@tagName(lang)});
                return error.WrongLang;
            },
        },
        else => unreachable,
    }
}
