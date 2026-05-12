# Tetris in Zig with Raylib
h3bzzz

A fully-featured Tetris clone written in [Zig](https://ziglang.org/), rendered with [raylib](https://www.raylib.com/). This project was my first attempt at getting Zig to know the raylib library and see what Zig could really do with the new version 
releases of 0.17.0-dev.
---

## Features

The implementation covers the core mechanics expected of a competent Tetris variant:

- **Seven tetromino types**: O, L, J, I, T, S, and Z pieces, each with distinct colors and shadow tones.
- **Ghost piece**: A transparent preview of where the active piece will land, computed via collision scanning.
- **Hard and soft drop**: Down arrow accelerates descent; Spacebar performs an instant hard drop with bonus scoring proportional to distance.
- **Lock delay**: A 30-frame grace period after a piece lands, allowing the player to slide or rotate before the piece commits.
- **Line clearing with animation**: Completed lines flash briefly before collapsing the stack above.
- **Progressive difficulty**: Level increases every 10 lines, reducing gravity speed from 30 frames per cell down to a minimum of 5.
- **Scoring system**: 100 / 300 / 500 / 800 points per 1-4 lines, multiplied by current level. Hard drops award 2 points per cell dropped.
- **Game state management**: Title screen, active play, pause, and game over states with full reset capability.
- **Responsive layout**: The playfield and UI scale dynamically to fit the window dimensions while maintaining square cells.

---

## Controls

| Key | Action |
|-----|--------|
| `Enter` | Start / Restart |
| `Left / Right` | Move piece |
| `Up` | Rotate clockwise |
| `Down` | Soft drop |
| `Space` | Hard drop |
| `P` | Pause |
| `Q` | Quit |

---

## Architecture

### Game Logic

The game state is managed through a set of tightly scoped global variables in `src/main.zig`:

- **`grid[12][20]`**: A 2D array of `GridSquare` enum tags (`empty`, `moving`, `full`, `block`, `fading`).
- **`color_grid` / `shadow_grid`**: Parallel arrays storing the RGB values and darkened border tones for locked cells.
- **`piece[4][4]` / `incoming_piece[4][4]`**: Local 4x4 buffers representing the active and next piece matrices.
- **Counters**: Frame-based counters govern lateral movement, rotation, gravity, fast-fall, line fade, and lock delay, all tuned to a 60 FPS target.

The update loop is partitioned into discrete phases:

1. **Input handling** — keyboard events trigger immediate state changes (rotation, hard drop, pause).
2. **Gravity and collision detection** — `checkDetection` scans the grid bottom-up to flag when a moving piece contacts a `full` cell or bottom boundary.
3. **Movement resolution** — `resolveFallingMovement` either advances the piece one row or locks it in place, converting `moving` tags to `full`.
4. **Line completion check** — `checkCompletion` marks full rows as `fading`.
5. **Line deletion** — after a brief fade timer, `deleteCompleteLines` removes completed rows and shifts the stack downward, preserving color data.
6. **Game over detection** — if any `full` cell exists in the top two rows, the game ends.

### Rendering

Drawing is decoupled from updating. `drawGame` selects the appropriate screen based on state, while `drawMainGame` iterates the grid once per frame, switching on `GridSquare` to dispatch filled cells, outlines, moving pieces, blocks, or fading animations. The side panel renders the incoming piece preview and HUD statistics (lines, level, score).

`computeLayout` dynamically calculates cell size, grid origin, and font scaling based on current window dimensions, ensuring the game remains playable at any reasonable resolution.

---

## Using Raylib with Zig

Raylib is a straightforward choice with the hype around it's simplicity. Raylib will give anyone trying to attempt bare-bone game-development coding a really solid foundation. I had a lot of fun just getting shapes to draw and move on the screen and introduce collision functions, this eventually led me to creating a tetris game. Something easy, that everyone has done just to get acquainted more with Zig and Raylib.

## Building and Running

### Prerequisites

- [Zig](https://ziglang.org/download/) (master / 0.17.0-dev or later, as specified in `build.zig.zon`)
- A C compiler toolchain (Zig bundles `clang` and can act as its own linker, but raylib compiles C source during the build)
- Platform dependencies for raylib:
  - **Linux**: `libgl1-mesa-dev`, `libx11-dev`, `libxcursor-dev`, `libxinerama-dev`, `libxrandr-dev`, `libxi-dev`
  - **macOS**: Xcode Command Line Tools
  - **Windows**: No external dependencies required

### Build

```bash
zig build
```

The executable is emitted to `zig-out/bin/tetris`.

### Run

```bash
zig build run
```

### Test

```bash
zig build test
```

---

## Project Structure

```
.
├── build.zig          # Build configuration: executable, dependencies, test runners
├── build.zig.zon      # Package manifest: declares raylib-zig dependency
├── src/
│   ├── main.zig       # Game loop, state management, rendering, and input
│   └── root.zig       # Module root (conventional Zig package entry point)
└── zig-pkg/           # Fetched dependency cache (raylib, raylib-zig bindings, Emscripten)
```

---

## License

This project is released under the MIT License. See `LICENSE` for details.
