const std = @import("std");
const posix = std.posix;
const ESC = 27;
// ↑  U+2191  Up
// ↗  U+2197  Up Right
// →  U+2192  Right
// ↘  U+2198  Down Right
// ↓  U+2193  Down
// ↙  U+2199  Down Left
// ←  U+2190  Left
// ↖  U+2196  Up Left

// "\x1b[2J"      // clear screen
// "\x1b[H"       // move cursor to top-left
// "\x1b[?25l"    // hide cursor
// "\x1b[?25h"    // show cursor
// "\x1b[row;colH" // move cursor
// try stdout.print("\x1b[10;20H@", .{}); row 10 col 20

const Vector = struct { x: f32 = 0.0, y: f32 = 0.0 };

const Boid = struct {
    position: Vector = .{},
    velocity: Vector = .{},
    acceleration: Vector = .{},
    pub fn init(x: f32, y: f32, vx: f32, vy: f32) Boid {
        return .{
            .position = .{ .x = x, .y = y },
            .velocity = .{ .x = vx, .y = vy },
        };
    }
};

pub fn main(init: std.process.Init) !void {
    var window_size: posix.winsize = undefined;
    const rc = std.c.ioctl(
        posix.STDOUT_FILENO,
        std.c.T.IOCGWINSZ,
        &window_size,
    );

    if (rc == -1) return error.IoctlFailed;

    const window_row: f32 = @floatFromInt(window_size.row);
    const window_col: f32 = @floatFromInt(window_size.col);

    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    const stdout_writer = &stdout.interface;

    try stdout_writer.print("\x1b[?1049h\x1b[?25l", .{}); // alternate screen, hide cursor
    defer stdout_writer.print("\x1b[?25h\x1b[?1049l", .{}) catch {};

    const my_boid = Boid.init(window_row / 2, window_col / 2, 0, 0);

    const stdin_file = std.Io.File.stdin();
    var stdin = stdin_file.reader(init.io, &.{});
    const stdin_reader = &stdin.interface;

    const old_termios = try posix.tcgetattr(stdin_file.handle);
    var new_termios = old_termios;
    new_termios.lflag.ICANON = false;
    new_termios.lflag.ECHO = false;

    try posix.tcsetattr(stdin_file.handle, .FLUSH, new_termios);
    defer posix.tcsetattr(stdin_file.handle, .FLUSH, old_termios) catch {};

    var key_buf: [8]u8 = undefined;
    var key_vec = [_][]u8{&key_buf};

    while (true) {
        const row: u16 = @intFromFloat(my_boid.position.x);
        const col: u16 = @intFromFloat(my_boid.position.y);

        try stdout_writer.print("\x1b[2J\x1b[H", .{}); // clear screen, move cursor home
        try stdout_writer.print("\x1b[{};{}H↑", .{ row, col });
        try stdout_writer.flush();

        const n = try stdin_reader.readVec(&key_vec);
        if (n > 0) {
            const key = key_buf[0];
            if (key == 'q' or key == ESC) break;
        }

        try init.io.sleep(.fromMilliseconds(16), .awake);
    }
}
