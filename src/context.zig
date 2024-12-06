pub const OutputMode = enum {
    Stdout,
    Clipboard,
};

in_file_path: ?[]const u8 = null,
out_file_path: ?[]const u8 = null,
colored_output: bool = false,
pixel_threshold: u8 = 127,
