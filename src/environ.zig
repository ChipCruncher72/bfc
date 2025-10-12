const std = @import("std");

pub const Language = enum {
    // Planned languages for trans-compliation
    zig,
    c,
    cpp,
    rust,
    python,
    js,
    go,
};

pub const BfEnvironment = struct {
    writer: *std.Io.Writer,
    reader: *std.Io.Reader,
    tape: []u8,
    pointer: usize = 0,

    pub fn init(w: *std.Io.Writer, r: *std.Io.Reader, tape: []u8) BfEnvironment {
        return .{
            .writer = w,
            .reader = r,
            .tape = tape,
        };
    }

    pub fn exec(environ: *BfEnvironment, allocator: std.mem.Allocator, program: []const u8) !void {
        var loop_idxs: std.ArrayList(usize) = .empty;
        defer loop_idxs.deinit(allocator);

        var lc_cache: std.ArrayList(packed struct { line: usize, column: usize }) = .empty;
        defer lc_cache.deinit(allocator);

        var line: usize = 1;
        var column: usize = 1;

        var idx: usize = 0;
        while (idx < program.len) : ({idx += 1; column += 1;}) {
            const instruction = program[idx];
            switch (instruction) {
                '+' => environ.tape[environ.pointer] +%= 1,
                '-' => environ.tape[environ.pointer] -%= 1,
                '>' => {
                    if (environ.pointer == environ.tape.len-1) environ.pointer = 0
                    else environ.pointer += 1;
                },
                '<' => {
                    if (environ.pointer == 0) environ.pointer = environ.tape.len-1
                    else environ.pointer -= 1;
                },
                '[' => {
                    var loop_counter: usize = 1;
                    var idx2 = idx+1;
                    var tmp_line = line;
                    var tmp_column = column;
                    while (idx2 < program.len) : ({idx2 += 1; tmp_column += 1;}) {
                        if (program[idx2] == '[')
                            loop_counter += 1;

                        if (program[idx2] == ']') {
                            loop_counter -= 1;
                            if (loop_counter == 0) break;
                        }

                        if (program[idx] == '\n') {
                            tmp_line += 1;
                            tmp_column = 0;
                        }
                    }
                    if (idx2 == program.len) {
                        std.log.err("@ {}:{} Found '[' without matching ']'", .{line, column});
                        return error.MissingSquareBracket;
                    }

                    if (environ.tape[environ.pointer] == 0) {
                        line = tmp_line;
                        column = tmp_column;
                        idx = idx2;
                    } else {
                        try lc_cache.append(allocator, .{
                            .line = line,
                            .column = column,
                        });
                        try loop_idxs.append(allocator, idx);
                    }
                },
                ']' => {
                    if (loop_idxs.items.len == 0) {
                        std.log.err("@ {}:{} Rogue ']' in program", .{line, column});
                        return error.RogueSquareBracket;
                    }

                    if (environ.tape[environ.pointer] != 0) {
                        const cache = lc_cache.items[lc_cache.items.len-1];
                        line = cache.line;
                        column = cache.column;
                        idx = loop_idxs.items[loop_idxs.items.len-1];
                    } else {
                        _ = lc_cache.orderedRemove(lc_cache.items.len-1);
                        _ = loop_idxs.orderedRemove(loop_idxs.items.len-1);
                    }
                },
                '.' => {
                    try environ.writer.writeByte(environ.tape[environ.pointer]);
                    try environ.writer.flush();
                },
                ',' => environ.tape[environ.pointer] = environ.reader.takeByte() catch |e| blk: {
                    if (e == error.EndOfStream) break :blk environ.tape[environ.pointer]
                    else return e;
                },
                '\n' => {
                    line += 1;
                    column = 0;
                },
                else => {},
            }
        }
    }

    // TODO
    //pub fn transpile(environ: BfEnvironment, program: []const u8, lang: Language) !void {}
};
