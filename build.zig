const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule("wslsel", .{
        .root_source_file = b.path("src/wslsel.zig"),
    });

    const bashsel = b.addExecutable(.{
        .name = "bashsel",
        .root_source_file = b.path("src/bashsel.zig"),
        .target = target,
        .optimize = optimize,
    });
    bashsel.root_module.addImport("wslsel", module);
    b.installArtifact(bashsel);

    const module_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/wslsel.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_module_unit_tests = b.addRunArtifact(module_unit_tests);

    const bashsel_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/bashsel.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_bashsel_unit_tests = b.addRunArtifact(bashsel_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_module_unit_tests.step);
    test_step.dependOn(&run_bashsel_unit_tests.step);
}
