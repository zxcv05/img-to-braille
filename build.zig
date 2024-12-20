const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dep_args = .{ .target = target, .optimize = optimize };
    const jdz_dep = b.dependency("jdz", dep_args);
    const zimg_dep = b.dependency("zimg", dep_args);

    const exe = b.addExecutable(.{
        .root_source_file = b.path("src/main.zig"),
        .name = "convert",

        .optimize = optimize,
        .target = target,

        .strip = optimize != .Debug,
    });

    exe.link_gc_sections = true;

    exe.root_module.addImport("jdz", jdz_dep.module("jdz_allocator"));
    exe.root_module.addImport("zimg", zimg_dep.module("zigimg"));

    const run = b.addRunArtifact(exe);
    const step = b.step("run", "Run program");

    if (b.args) |args| run.addArgs(args);

    step.dependOn(&run.step);

    b.installArtifact(exe);
}
