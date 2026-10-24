# Dev notes

Plan: [Castle Combat — Godot build plan](https://claude.ai/artifact/E2m6x1o14pcsbGN1iRJfBS).
Spec: [docs/GDD_v0.1.md](docs/GDD_v0.1.md). Engine: Godot 4.7.2, GDScript, Compatibility renderer.

## Architecture

The one rule: **the simulation decides everything and knows nothing about 3D or input.**

```
input/ + bot/  --PlayerCommand per tick-->  sim/ (MatchSim, 30 Hz)  --state + events-->  view/ (3D), ui/ (HUD), tests/
                                                ^
                                          data/*.tres (all tunable numbers)
```

- `src/sim/` — plain `RefCounted` classes on a 2D plane. x = across the lane, y = along it,
  blue's Core at negative y. Red's layout is blue's rotated 180° (`p -> -p`).
  `MatchSim.step(commands)` advances one fixed tick; tests call it directly.
- `src/input/` — `CommandSource` subclasses build one `PlayerCommand` per tick.
  `LocalPlayerSource` merges keyboard and the touch joystick and rotates input for the red seat.
- `src/bot/` — `BotSource` is the same interface. M0's bot only patrols.
- `src/view/` — `MatchView` draws sim state with primitive meshes and interpolates
  between ticks. Sim (x, y) maps to world (x, 0, -y). `CameraRig` is orthographic,
  pitched 52°, follows the local hero and turns 180° for the red seat.
- `src/ui/` — `Hud` (top band = them, bottom band = you + item tray, thumbs in between),
  `ThumbStick` (floating joystick; `use_mouse` = mouse-as-touch on desktop).
- `src/match_controller.gd` — owns one match: fixed-tick loop, wiring, debug toggles.
- `src/main.gd` — hero select and dev command-line flags.
- Input actions are registered in code by the `InputSetup` autoload (`src/input/input_setup.gd`).

Visual language: you are always blue with a circle under your units; the opponent is
orange with a diamond. Silhouettes: Vanguard = block + shield, Scout = flat cone,
Gunner = drum + barrel, towers = hex pillars (inner taller), Core = gem. Locked
structures wear a translucent dome.

## Status

**M0 — done in this branch**
- [x] Portrait 3D arena from data: lane, two side pockets with two entrances each, low walls
- [x] Outer Tower, Inner Tower, Core per side; lock domes follow the unlock order
- [x] Hero movement with wall sliding and structure collision, fixed 30 Hz tick, dead zone
- [x] Three hero silhouettes from data; hero select screen
- [x] Follow camera (orthographic), seat swap (F2), landscape-safe framing for browsers
- [x] HUD shell: both heroes, all six structures, gold, Relay countdown, item tray, ability buttons
- [x] Touch joystick, testable on desktop with the mouse (F3)
- [x] 18 rule tests, headless smoke run, Windows + web exports in CI

**Next: M1 — combat loop.** Stop-to-attack windup, guaranteed hits, target priority and
tap/click override, minion waves, tower AI, KO/respawn, structure damage, victory, a bot
that fights.

## Assumptions (change by editing data)

- Map: 10 m wide lane, 84 m long; pockets 5 × 12 m at the centre; pillars split each
  pocket mouth into two 4.5 m entrances. Structures at y = -16, -27, -37 (blue): 11 m from
  Outer to Inner, 10 m from Inner to Core, 32 m between the two Outer Towers.
- Hero speeds 4.2–5.4 m/s, radius 0.5 m. Combat numbers in `data/heroes/*.tres` are seeds for M1.
- Walls block movement and sight; units block neither sight nor each other (yet).
- The local human is always shown as blue at the bottom; F2 tests the other seat.
- No Godot physics or navigation server: circles and rectangles on a plane.

## Known gaps

- Safe-area handling only offsets the top band on phones; full notch/home-bar pass in M5.
- Browser builds in a landscape window scale the portrait UI down; play in a narrow
  window or on a phone for the intended layout.
- FPS in CI/sandbox screenshots is software rendering, not a real measurement.
