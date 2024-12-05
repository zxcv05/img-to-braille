pub const OutputMode = enum {
    Stdout,
    Clipboard,
};

output_mode: OutputMode = .Stdout,
in_file_path: ?[]const u8 = null,
pixel_threshold: u8 = 127,
