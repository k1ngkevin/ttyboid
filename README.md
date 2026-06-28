# ttyboids

https://github.com/user-attachments/assets/4095dadb-df68-42a0-ab0d-72f78fff3841

A tiny terminal boids simulation written in Zig. `ttyboids` fills your terminal
with a flock of arrow characters that steer around each other using simple local
rules. There is no graphics library or game engine. The program talks directly to the terminal, reads its current size, draws each boid with ANSI escape sequences, and updates the flock in a loop.

## How it Works

A boid is a small simulated flocking agent. Each boid has a position, velocity,
and acceleration. On every frame, each boid looks at nearby boids and combines
three steering forces:

1. `alignment`: steer toward the average heading of neighbors
2. `cohesion`: steer toward the center of nearby neighbors
3. `separation`: steer away from boids that are too close

These three simple rules introduced by Craig Reynolds in the 1980s allow for complex flock behavior.

After steering, each boid updates its velocity, moves forward, and wraps around
the terminal edges. 

### Running the Simulation
Install Zig 0.16.0 or newer before running the project.

Run it in a POSIX-style terminal:

```sh
zig run boids.zig
```

Press `q` or `Esc` to quit.

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
for more space between boids, or tweaking the radii to change how locally the flock reacts.
