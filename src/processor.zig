const std = @import("std");
const zimg = @import("zimg");

const constants = @import("constants.zig");

const Context = @import("context.zig");

pub const GenericBrailleImage = union(enum) {
    default: BrailleImage,
    colored: ColoredBrailleImage,
};

pub const ColoredBrailleImage = struct {
    pub const Color = struct {
        r: u8,
        g: u8,
        b: u8,
    };

    width: usize,
    height: usize,
    data: []Color,

    pub fn to_utf8(this: ColoredBrailleImage, alloc: std.mem.Allocator) ![]u8 {
        const max_possible_size = this.width * this.height * 24;
        var buffer = try alloc.alloc(u8, max_possible_size);

        var head: usize = 0;

        for (0..this.height) |y| {
            const offset = y * this.width;
            const colors = this.data[offset..][0..this.width];

            for (colors) |color| {
                const slice = try std.fmt.bufPrint(buffer[head..], "\x1b[38;2;{d};{d};{d}m", .{ color.r, color.g, color.b });
                head += slice.len;

                // Not taking into account which pixels actually exist will mean
                // images that dont have a ratio of 2:8 will have extra "pixels"
                // added to the bottom and right sides to pad to 2:8
                head += try std.unicode.utf16LeToUtf8(buffer[head..], &.{0x28ff});
            }

            buffer[head] = '\n';
            head += 1;
        }

        return try alloc.realloc(buffer, head);
    }
};

pub const BrailleImage = struct {
    width: usize,
    height: usize,
    data: []u16,

    pub fn to_utf8(this: BrailleImage, alloc: std.mem.Allocator) ![]u8 {
        const max_possible_size = this.width * this.height * 4;
        var buffer = try alloc.alloc(u8, max_possible_size);

        var head: usize = 0;

        for (0..this.height) |y| {
            const offset = y * this.width;
            var utf16 = std.unicode.Utf16LeIterator.init(this.data[offset..][0..this.width]);

            while (try utf16.nextCodepoint()) |codepoint| {
                head += try std.unicode.utf8Encode(codepoint, buffer[head..]);
            }

            buffer[head] = '\n';
            head += 1;
        }

        return try alloc.realloc(buffer, head);
    }
};

inline fn get_pixel_bit(ctx: Context, image: *zimg.ImageUnmanaged, y: usize, x: usize) u8 {
    if (x >= image.width) return 0;
    if (y >= image.height) return 0;
    return @intFromBool(image.pixels.grayscale8[y * image.width + x].value > ctx.pixel_threshold);
}

inline fn get_pixel_color(_: Context, image: *zimg.ImageUnmanaged, y: usize, x: usize) u48 {
    if (x >= image.width) return 0;
    if (y >= image.height) return 0;
    const pixel = image.pixels.rgb24[y * image.width + x];
    return (@as(u48, pixel.r) << 32) | (@as(u48, pixel.g) << 16) | @as(u48, pixel.b);
}

pub fn process(alloc: std.mem.Allocator, ctx: Context, image: *zimg.ImageUnmanaged) !GenericBrailleImage {
    if (ctx.colored_output)
        try image.convert(alloc, .rgb24)
    else
        try image.convert(alloc, .grayscale8);

    const output_width = @divFloor(image.width + 1, 2);
    const output_height = @divFloor(image.height + 3, 4);
    const output_size = output_width * output_height;

    var output = try alloc.alloc(u16, if (ctx.colored_output) 0 else output_size);
    var colors = try alloc.alloc(ColoredBrailleImage.Color, if (ctx.colored_output) output_size else 0);

    for (0..output_height) |y| {
        for (0..output_width) |x| {
            const offset_x = x * 2;
            const offset_y = y * 4;

            if (ctx.colored_output) {
                var packed_rgb: u48 = 0;
                packed_rgb += get_pixel_color(ctx, image, offset_y + 0, offset_x + 0);
                packed_rgb += get_pixel_color(ctx, image, offset_y + 1, offset_x + 0);
                packed_rgb += get_pixel_color(ctx, image, offset_y + 2, offset_x + 0);
                packed_rgb += get_pixel_color(ctx, image, offset_y + 3, offset_x + 0);
                packed_rgb += get_pixel_color(ctx, image, offset_y + 0, offset_x + 1);
                packed_rgb += get_pixel_color(ctx, image, offset_y + 1, offset_x + 1);
                packed_rgb += get_pixel_color(ctx, image, offset_y + 2, offset_x + 1);
                packed_rgb += get_pixel_color(ctx, image, offset_y + 3, offset_x + 1);

                const r: u16 = @intCast((packed_rgb & 0xffff00000000) >> 32);
                const g: u16 = @intCast((packed_rgb & 0x0000ffff0000) >> 16);
                const b: u16 = @intCast((packed_rgb & 0x00000000ffff) >> 0);

                colors[y * output_width + x] = .{
                    .r = @intCast(@divFloor(r, 8)),
                    .g = @intCast(@divFloor(g, 8)),
                    .b = @intCast(@divFloor(b, 8)),
                };
            } else {
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
    }

    if (ctx.colored_output) {
        return GenericBrailleImage{ .colored = .{
            .width = output_width,
            .height = output_height,
            .data = colors,
        } };
    } else {
        return GenericBrailleImage{ .default = .{
            .width = output_width,
            .height = output_height,
            .data = output,
        } };
    }
}
