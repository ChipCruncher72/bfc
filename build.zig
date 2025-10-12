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
        .version = SemVer.parse("0.1.0-dev.1") catch unreachable,
    });

    const install_step = b.getInstallStep();
    const ast_check = b.step("ast",
        \\Perform an AST check on the source code (It's the same as invoking zig build install, used for more zls errors)
    );
    ast_check.dependOn(install_step);

    b.installArtifact(exe);
}
