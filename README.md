# ttyboids

https://github.com/user-attachments/assets/4095dadb-df68-42a0-ab0d-72f78fff3841

A tiny terminal boids simulation written in Zig. `ttyboids` fills your terminal
with a flock of arrow characters that steer around each other using simple local
rules. There is no graphics library or game engine here: the program talks
directly to the terminal, reads its current size, draws each boid with ANSI
escape sequences, and updates the flock in a loop.

It is meant to be small enough to read in one sitting, while still showing a few
useful systems-programming ideas: terminal control, raw keyboard input, vector
math, randomness, and emergent behavior from simple rules.

## How it Works

A boid is a small simulated flocking agent. Each boid has a position, velocity,
and acceleration. On every frame, each boid looks at nearby boids and combines
three steering forces:

1. `alignment`: steer toward the average heading of neighbors
2. `cohesion`: steer toward the center of nearby neighbors
3. `separation`: steer away from boids that are too close

Those three rules are the classic boids model introduced by Craig Reynolds.
None of the boids knows about the whole flock. Each one only reacts to nearby
boids, but the group still starts to look coordinated.

After steering, each boid updates its velocity, moves forward, and wraps around
the terminal edges. If a boid leaves the right side of the screen, it comes back
on the left; if it leaves the bottom, it comes back at the top.

The display is also terminal-native. The program switches into the terminal's
alternate screen, hides the cursor, clears the screen each frame, moves the
cursor to each boid's position, and prints an arrow that points in the boid's
current direction.

## Installing Zig

Install Zig 0.16.0 or newer before running the project.

On macOS with Homebrew:

```sh
brew install zig
```

For other platforms, download Zig from the official downloads page:

https://ziglang.org/download/

After installing, check that `zig` is available:

```sh
zig version
```

## Running the Simulation

Run it in a real terminal:

```sh
zig run boids.zig
```

Press `q` or `Esc` to quit.

## Requirements

- Zig 0.16.0 or newer
- A POSIX-style terminal

The program reads the current terminal size, switches to the alternate screen,
hides the cursor while it runs, and restores the terminal on exit.

## Tuning

Most behavior lives in constants near the top of `boids.zig`:

```zig
const max_speed: f32 = 0.4;

const alignment_radius: f32 = 10.0;
const alignment_strength: f32 = 0.04;

const cohesion_radius: f32 = 10.0;
const cohesion_strength: f32 = 0.03;

const separation_radius: f32 = 5.0;
const separation_strength: f32 = 0.3;

const num_boids = 100;
```

Try increasing `num_boids` for denser flocking, raising `separation_strength`
for more personal space, or tweaking the radii to change how locally the flock
reacts.

## License

MIT License. See `LICENSE` for details.
