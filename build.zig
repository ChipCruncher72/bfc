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

    const clap = b.dependency("clap", .{});
    exe_mod.addImport("clap", clap.module("clap"));

    const exe = b.addExecutable(.{
        .name = "bfc",
        .root_module = exe_mod,
        .version = SemVer.parse("0.2.0-dev") catch unreachable,
    });

    b.installArtifact(exe);

    const test_step = b.step("test", "Perform unit tests");

    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/test.zig"),
        .optimize = optimize,
        .target = target,
    });

    test_mod.addImport("clap", clap.module("clap"));

    const unit_test = b.addTest(.{
        .root_module = test_mod,
    });

    const run_test = b.addRunArtifact(unit_test);

    if (b.args) |args| {
        run_test.addArgs(args);
    }

    test_step.dependOn(&run_test.step);
}
