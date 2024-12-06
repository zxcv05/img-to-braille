pub const HELP_USAGE_FMT =
    \\Usage: {s} <file_path> [args...]
    \\
    \\  <file_path>     | Path to input image
    \\  --help, -h      | Show this help text
    \\  --output, -o    | Output file path (default: stdout)
    \\  --threshold, -t | Threshold for displaying a pixel
    \\                  |   possible values: 0..255 (default: 127)
    \\  --color, -c     | Enable colored output (--threshold will be ignored)
    \\  --no-color, -g  | Disable colored output (default)
    \\
;

// UTF-16 "Braille Pattern Blank"
pub const BRAILLE_BLANK = 0x2800;
