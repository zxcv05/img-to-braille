const std = @import("std");

const constants = @import("constants.zig");

const Context = @import("context.zig");

pub inline fn show_help_usage(arg0: []const u8) void {
    const stderr = std.io.getStdErr();
    stderr.writer().print(constants.HELP_USAGE_FMT, .{arg0}) catch {};
}

/// Returns whether main process can continue
/// Only returns false if show_help_usage called
pub fn parse_cli(alloc: std.mem.Allocator, ctx: *Context) !bool {
    var args = try std.process.ArgIterator.initWithAllocator(alloc);
    defer args.deinit();

    const arg0 = args.next().?;
    ctx.in_file_path = args.next() orelse return error.NoPathGiven;

    // check arg1 for --help -h
    if (std.mem.eql(u8, ctx.in_file_path.?, "--help") or std.mem.eql(u8, ctx.in_file_path.?, "-h")) {
        show_help_usage(arg0);
        return false;
    }

    while (args.next()) |arg| {
        // --help -h
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            show_help_usage(arg0);
            return false;
        }
        // --output -o
        else if (std.mem.eql(u8, arg, "--output") or std.mem.eql(u8, arg, "-o")) {
            ctx.out_file_path = args.next() orelse return error.NoOutputPathGiven;
        }
        // --threshold -t
        else if (std.mem.eql(u8, arg, "--threshold") or std.mem.eql(u8, arg, "-t")) {
            const next_arg = args.next() orelse return error.NoThresholdValueGiven;
            ctx.pixel_threshold = try std.fmt.parseInt(u8, next_arg, 10);
        }
        // --color -c
        else if (std.mem.eql(u8, arg, "--color") or std.mem.eql(u8, arg, "-c")) {
            ctx.colored_output = true;
        }
        // --no-color -g
        else if (std.mem.eql(u8, arg, "--no-color") or std.mem.eql(u8, arg, "-g")) {
            ctx.colored_output = false;
        }
        // Not recognized
        else {
            return error.ArgumentNotRecognized;
        }
    }

    return true;
}
