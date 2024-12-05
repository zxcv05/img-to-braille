const std = @import("std");
const zimg = @import("zimg");

const constants = @import("constants.zig");

const Context = @import("context.zig");

pub const BrailleImage = struct {
    width: usize,
    height: usize,
    data: []u16,

    pub fn to_utf8(this: BrailleImage, alloc: std.mem.Allocator) ![]u8 {
        const max_possible_size = this.width * this.height * 4;
        var buffer = try alloc.alloc(u8, max_possible_size);

        var fba = std.heap.FixedBufferAllocator.init(buffer[0..]);
        var fba_alloc = fba.allocator();

        for (0..this.height) |y| {
            const offset = y * this.width;
            var utf16 = std.unicode.Utf16LeIterator.init(this.data[offset .. offset + this.width]);

            while (try utf16.nextCodepoint()) |codepoint| {
                var slice = fba_alloc.alloc(u8, 4) catch unreachable;
                const len = try std.unicode.utf8Encode(codepoint, slice[0..4]);

                _ = fba_alloc.realloc(slice, len) catch unreachable;
            }

            const newline = fba_alloc.create(u8) catch unreachable;
            newline.* = '\n';
        }

        return try alloc.realloc(buffer, fba.end_index);
    }
};

inline fn get_pixel_bit(ctx: Context, image: zimg.ImageUnmanaged, y: usize, x: usize) u8 {
    if (x >= image.width) return 0;
    if (y >= image.height) return 0;
    return @intFromBool(image.pixels.grayscale8[y * image.width + x].value > ctx.pixel_threshold);
}

pub fn process(alloc: std.mem.Allocator, ctx: Context) !BrailleImage {
    var image = try zimg.ImageUnmanaged.fromFilePath(alloc, ctx.in_file_path.?);
    defer image.deinit(alloc);

    if (image.isAnimation()) return error.AnimatedImagesNotSupported;
    try image.convert(alloc, .grayscale8);

    const output_width = @divFloor(image.width + 1, 2);
    const output_height = @divFloor(image.height + 3, 4);
    var output = try alloc.alloc(u16, output_width * output_height);

    for (0..output_height) |y| {
        for (0..output_width) |x| {
            const offset_x = x * 2;
            const offset_y = y * 4;

            const braille_char_offset: u16 =
                get_pixel_bit(ctx, image, offset_y + 0, offset_x + 0) << 0 |
                get_pixel_bit(ctx, image, offset_y + 1, offset_x + 0) << 1 |
                get_pixel_bit(ctx, image, offset_y + 2, offset_x + 0) << 2 |
                get_pixel_bit(ctx, image, offset_y + 3, offset_x + 0) << 6 |
                get_pixel_bit(ctx, image, offset_y + 0, offset_x + 1) << 3 |
                get_pixel_bit(ctx, image, offset_y + 1, offset_x + 1) << 4 |
                get_pixel_bit(ctx, image, offset_y + 2, offset_x + 1) << 5 |
                get_pixel_bit(ctx, image, offset_y + 3, offset_x + 1) << 7;

            output[y * output_width + x] = constants.BRAILLE_BLANK + braille_char_offset;
        }
    }

    return .{
        .width = output_width,
        .height = output_height,
        .data = output,
    };
}
