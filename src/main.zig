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

    const output = try processor.process(alloc, ctx);
    defer alloc.free(output.data);

    const utf8_string = try output.to_utf8(alloc);
    defer alloc.free(utf8_string);

    switch (ctx.output_mode) {
        .Stdout => {
            const stdout = std.io.getStdOut();
            try stdout.writeAll(utf8_string);
        },
        .Clipboard => {
            std.log.err("TODO: Clipboard output mode", .{});
        },
    }
}
