const std = @import("std");
const SemVer = std.SemanticVersion;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "bfc",
        .root_module = exe_mod,
        .version = SemVer.parse("0.1.0-dev") catch unreachable,
    });

    b.installArtifact(exe);

    const test_step = b.step("test", "Perform unit tests");

    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/test.zig"),
        .optimize = optimize,
        .target = target,
    });
    const unit_test = b.addTest(.{
        .root_module = test_mod,
    });

    const run_test = b.addRunArtifact(unit_test);

    if (b.args) |args| {
        run_test.addArgs(args);
    }

    test_step.dependOn(&run_test.step);
}
