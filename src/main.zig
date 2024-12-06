const std = @import("std");
const jdz = @import("jdz");
const zimg = @import("zimg");

const cli = @import("cli.zig");
const processor = @import("processor.zig");

const Context = @import("context.zig");

var outer = jdz.JdzAllocator(.{}).init();
var alloc = outer.allocator();

var ctx = Context{};

pub fn main() !void {
    defer _ = outer.deinit();

    const can_continue = try cli.parse_cli(alloc, &ctx);
    if (!can_continue) return;

    var image = try zimg.ImageUnmanaged.fromFilePath(alloc, ctx.in_file_path.?);
    defer image.deinit(alloc);

    if (image.isAnimation()) return error.AnimatedImagesNotSupported;

    const output = try processor.process(alloc, ctx, &image);
    defer switch (output) {
        .default => |d| alloc.free(d.data),
        .colored => |c| alloc.free(c.data),
    };

    const utf8_string = switch (output) {
        .default => |d| try d.to_utf8(alloc),
        .colored => |c| try c.to_utf8(alloc),
    };
    defer alloc.free(utf8_string);

    const out_file = if (ctx.out_file_path) |out_file_path|
        try std.fs.cwd().createFile(out_file_path, .{})
    else
        std.io.getStdOut();

    try out_file.writeAll(utf8_string);
    out_file.close();
}
