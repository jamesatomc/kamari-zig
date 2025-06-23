const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{}); // Create the kamari library module
    const kamari_module = b.addModule("kamari", .{
        .root_source_file = b.path("src/kamari.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Create example executable
    const example_exe = b.addExecutable(.{
        .name = "kamari-zig-example",
        .root_source_file = b.path("examples/basic_server.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_exe.root_module.addImport("kamari", kamari_module);
    b.installArtifact(example_exe);

    // Create run step for example
    const run_cmd = b.addRunArtifact(example_exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the kamari-zig example server");
    run_step.dependOn(&run_cmd.step);

    // Create test step
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/kamari.zig"),
        .target = target,
        .optimize = optimize,
    });
    unit_tests.root_module.addImport("kamari", kamari_module);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
