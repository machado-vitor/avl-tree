const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    // The "avl_tree" module — the library this package exposes.
    // root.zig is the entry point; only its public declarations are visible to consumers.
    const mod = b.addModule("avl_tree", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    // Test executable built from the library module. `zig build test` runs it.
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
