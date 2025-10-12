const std = @import("std");

const environ = @import("environ.zig");
const main = @import("main.zig");

test {
    std.testing.refAllDecls(environ);
    std.testing.refAllDecls(main);
}
