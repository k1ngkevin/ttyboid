const std = @import("std");
const posix = std.posix;
const ESC = 27;

const initial_velocity_min: f32 = -0.5;
const initial_velocity_max: f32 = 0.5;
const max_speed: f32 = 0.4;

const alignment_radius: f32 = 10.0;
const alignment_strength: f32 = 0.04;

const cohesion_radius: f32 = 10.0;
const cohesion_strength: f32 = 0.03;

const separation_radius: f32 = 5.0;
const separation_strength: f32 = 0.3;

const num_boids = 100;

const Direction = enum {
    up,
    up_right,
    right,
    down_right,
    down,
    down_left,
    left,
    up_left,
};

pub fn charFromDirection(direction: Direction) u21 {
    return switch (direction) {
        .up => '↑',
        .up_right => '↗',
        .right => '→',
        .down_right => '↘',
        .down => '↓',
        .down_left => '↙',
        .left => '←',
        .up_left => '↖',
    };
}

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
            .x = 1.0 + random.float(f32) * (max_col_f - 1.0),
            .y = 1.0 + random.float(f32) * (max_row_f - 1.0),
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

    pub fn wrapAround(self: *Boid, rows: u32, cols: u32) void {
        const max_row: f32 = @floatFromInt(rows);
        const max_col: f32 = @floatFromInt(cols);

        if (self.position.x < 1.0) self.position.x = max_col;
        if (self.position.x > max_col) self.position.x = 1.0;

        if (self.position.y < 1.0) self.position.y = max_row;
        if (self.position.y > max_row) self.position.y = 1.0;
    }

    pub fn flockForces(self: *Boid, flock: []const Boid) Vector {
        var alignment = Vector{};
        var cohesion = Vector{};
        var separation = Vector{};

        var alignment_count: f32 = 0;
        var cohesion_count: f32 = 0;
        var separation_count: f32 = 0;

        for (flock) |boid| {
            const d = self.position.dist(boid.position);
            if (d > 0.001 and d < alignment_radius) {
                alignment.add(boid.velocity);
                alignment_count += 1;
            }

            if (d > 0.001 and d < cohesion_radius) {
                cohesion.add(boid.position);
                cohesion_count += 1;
            }

            if (d > 0.001 and d < separation_radius) {
                var diff = self.position;
                diff.sub(boid.position);

                diff.div(d);
                separation.add(diff);
                separation_count += 1;
            }
        }

        var steering = Vector{};

        if (alignment_count > 0) {
            alignment.div(alignment_count);
            alignment.sub(self.velocity);
            alignment.scale(alignment_strength);
            steering.add(alignment);
        }

        if (cohesion_count > 0) {
            cohesion.div(cohesion_count);
            cohesion.sub(self.position);
            cohesion.sub(self.velocity);
            cohesion.scale(cohesion_strength);
            steering.add(cohesion);
        }

        if (separation_count > 0) {
            separation.div(separation_count);
            separation.sub(self.velocity);
            separation.scale(separation_strength);
            steering.add(separation);
        }

        return steering;
    }

    pub fn steerBoids(self: *Boid, flock: []const Boid) void {
        self.acceleration.add(self.flockForces(flock));
    }

    pub fn getBoidChar(self: *Boid) u21 {
        const radians = std.math.atan2(self.velocity.y, self.velocity.x);
        const degrees = radians * 180.0 / std.math.pi;

        if (degrees >= -22.5 and degrees < 22.5) {
            return charFromDirection(.right);
        } else if (degrees >= 22.5 and degrees < 67.5) {
            return charFromDirection(.down_right);
        } else if (degrees >= 67.5 and degrees < 112.5) {
            return charFromDirection(.down);
        } else if (degrees >= 112.5 and degrees < 157.5) {
            return charFromDirection(.down_left);
        } else if (degrees >= 157.5 or degrees < -157.5) {
            return charFromDirection(.left);
        } else if (degrees >= -157.5 and degrees < -112.5) {
            return charFromDirection(.up_left);
        } else if (degrees >= -112.5 and degrees < -67.5) {
            return charFromDirection(.up);
        } else {
            return charFromDirection(.up_right);
        }
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

    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    const stdout_writer = &stdout.interface;

    try stdout_writer.print("\x1b[?1049h\x1b[?25l", .{}); // alternate screen, hide cursor
    defer stdout_writer.print("\x1b[?25h\x1b[?1049l", .{}) catch {};

    var seed: u64 = undefined;
    init.io.random(std.mem.asBytes(&seed));

    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();

    var flock: [num_boids]Boid = undefined;

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

            const row: u16 = @intFromFloat(boid.position.y);
            const col: u16 = @intFromFloat(boid.position.x);

            try stdout_writer.print("\x1b[{};{}H{u}", .{ row, col, boid.getBoidChar() });
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
