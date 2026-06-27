const std = @import("std");
const posix = std.posix;
const ESC = 27;

const initial_velocity_min: f32 = -0.5;
const initial_velocity_max: f32 = 0.5;
const max_speed: f32 = 0.5;
const alignment_radius: f32 = 15.0;
const alignment_strength: f32 = 0.1;

// ↑  U+2191  Up
// ↗  U+2197  Up Right
// →  U+2192  Right
// ↘  U+2198  Down Right
// ↓  U+2193  Down
// ↙  U+2199  Down Left
// ←  U+2190  Left
// ↖  U+2196  Up Left

const Vector = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,

    pub fn add(self: *Vector, other: Vector) void {
        self.x += other.x;
        self.y += other.y;
    }

    pub fn sub(self: *Vector, other: Vector) void {
        self.x -= other.x;
        self.y -= other.y;
    }

    pub fn mul(self: *Vector, other: Vector) void {
        self.x *= other.x;
        self.y *= other.y;
    }

    pub fn scale(self: *Vector, scalar: f32) void {
        self.x *= scalar;
        self.y *= scalar;
    }

    pub fn div(self: *Vector, scalar: f32) void {
        self.x /= scalar;
        self.y /= scalar;
    }

    pub fn dist(self: Vector, other: Vector) f32 {
        const dx = other.x - self.x;
        const dy = other.y - self.y;
        return @sqrt(dx * dx + dy * dy);
    }

    pub fn mag(self: Vector) f32 {
        return @sqrt(self.x * self.x + self.y * self.y);
    }

    pub fn setMag(self: *Vector, magnitude: f32) void {
        const current = self.mag();
        if (current == 0.0) return;

        self.scale(magnitude / current);
    }

    pub fn randomVector(random: std.Random, min: f32, max: f32) Vector {
        return Vector{
            .x = min + random.float(f32) * (max - min),
            .y = min + random.float(f32) * (max - min),
        };
    }

    pub fn randomPosition(random: std.Random, max_row: u32, max_col: u32) Vector {
        const max_row_f: f32 = @floatFromInt(max_row);
        const max_col_f: f32 = @floatFromInt(max_col);

        return .{
            .x = 1.0 + random.float(f32) * (max_row_f - 1.0),
            .y = 1.0 + random.float(f32) * (max_col_f - 1.0),
        };
    }
};

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

    pub fn randomBoid(random: std.Random, max_row: u32, max_col: u32) Boid {
        return .{
            .position = Vector.randomPosition(random, max_row, max_col),
            .velocity = Vector.randomVector(random, initial_velocity_min, initial_velocity_max),
        };
    }

    pub fn update(self: *Boid) void {
        self.velocity.add(self.acceleration);
        self.velocity.setMag(max_speed);
        self.position.add(self.velocity);
        self.acceleration = .{};
    }

    pub fn alignmentForce(self: *Boid, flock: []const Boid) Vector {
        var steering = Vector{};
        var num_boids: f32 = 0;

        for (flock) |boid| {
            const d = self.position.dist(boid.position);
            if (d > 0.0 and d < alignment_radius) {
                steering.add(boid.velocity);
                num_boids += 1;
            }
        }

        if (num_boids > 0) {
            steering.div(num_boids);
            steering.sub(self.velocity);
            steering.scale(alignment_strength);
        }

        return steering;
    }

    pub fn cohesionForce(self: *Boid, flock: []const Boid) Vector {
        var steering = Vector{};
        var num_boids: f32 = 0;

        for (flock) |boid| {
            const d = self.position.dist(boid.position);
            if (d > 0.0 and d < alignment_radius) {
                steering.add(boid.position);
                num_boids += 1;
            }
        }

        if (num_boids > 0) {
            steering.div(num_boids);
            steering.sub(self.position);
            steering.sub(self.velocity);
            steering.scale(alignment_strength);
        }

        return steering;
    }

    pub fn wrapAround(self: *Boid, rows: u32, cols: u32) void {
        const max_row: f32 = @floatFromInt(rows);
        const max_col: f32 = @floatFromInt(cols);

        if (self.position.x < 1.0) self.position.x = max_row;
        if (self.position.x > max_row) self.position.x = 1.0;

        if (self.position.y < 1.0) self.position.y = max_col;
        if (self.position.y > max_col) self.position.y = 1.0;
    }

    pub fn steerBoids(self: *Boid, flock: []const Boid) void {
        const alignment = self.alignmentForce(flock);
        const cohesion = self.cohesionForce(flock);
        self.acceleration.add(cohesion);
        self.acceleration.add(alignment);
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

    const window_rows: u32 = @intCast(window_size.row);
    const window_cols: u32 = @intCast(window_size.col);
    // const window_rows_f: f32 = @floatFromInt(window_rows);
    // const window_cols_f: f32 = @floatFromInt(window_cols);

    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    const stdout_writer = &stdout.interface;

    try stdout_writer.print("\x1b[?1049h\x1b[?25l", .{}); // alternate screen, hide cursor
    defer stdout_writer.print("\x1b[?25h\x1b[?1049l", .{}) catch {};

    var seed: u64 = undefined;
    init.io.random(std.mem.asBytes(&seed));

    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();

    var flock: [100]Boid = undefined;

    for (&flock) |*boid| {
        boid.* = Boid.randomBoid(random, window_rows, window_cols);
    }

    const stdin_file = std.Io.File.stdin();
    var stdin = stdin_file.reader(init.io, &.{});
    const stdin_reader = &stdin.interface;

    const old_termios = try posix.tcgetattr(stdin_file.handle);
    var new_termios = old_termios;

    new_termios.lflag.ICANON = false;
    new_termios.lflag.ECHO = false;
    new_termios.cc[@intFromEnum(posix.V.MIN)] = 0;
    new_termios.cc[@intFromEnum(posix.V.TIME)] = 0;

    try posix.tcsetattr(stdin_file.handle, .FLUSH, new_termios);
    defer posix.tcsetattr(stdin_file.handle, .FLUSH, old_termios) catch {};

    var key_buf: [8]u8 = undefined;
    var key_vec = [_][]u8{&key_buf};

    while (true) {
        try stdout_writer.print("\x1b[2J\x1b[H", .{}); // clear screen, move cursor home

        for (&flock) |*boid| {
            boid.steerBoids(&flock);
            boid.update();
            boid.wrapAround(window_rows, window_cols);

            const row: u16 = @intFromFloat(boid.position.x);
            const col: u16 = @intFromFloat(boid.position.y);

            try stdout_writer.print("\x1b[{};{}H#", .{ row, col });
        }
        try stdout_writer.flush();

        const n = stdin_reader.readVec(&key_vec) catch |err| switch (err) {
            error.EndOfStream => 0,
            else => return err,
        };

        if (n > 0) {
            const key = key_buf[0];
            if (key == 'q' or key == ESC) break;
        }

        try init.io.sleep(.fromMilliseconds(16), .awake);
    }
}
