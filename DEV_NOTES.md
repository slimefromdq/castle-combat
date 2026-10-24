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

**M1 — combat loop**
- [x] One attack contract for heroes, minions and structures (`CombatSystem`): stand still,
      wind up, fire; moving/death/target loss cancels; a fired attack lands instantly on its
      locked target (projectiles are cosmetic)
- [x] Hero targeting: tapped target > enemy hero > last-hittable minion > nearest minion >
      exposed structure, all with range + line of sight (`Targeting`). Tap/click override
      lasts until the target dies or is out of reach for 2 s
- [x] Waves every 12 s from 0:03 (2 melee + 1 ranged), mirrored; minions fight minions,
      then heroes, then structures; towers and Core prefer minions, then heroes
- [x] Structures take damage only once exposed; Core death ends the match; KO + 7 s respawn
- [x] Utility bot: heal at base when low, never tank a tower, defend, trade, siege with
      minions, otherwise hold behind its lead minion, tap last hits
- [x] Visuals: HP bars, range ring while still, closing windup ring, windup lines,
      tracers + white hit burst, target bracket (yellow = tapped), tower rubble, minion shapes
- [x] Result screen with Play again; respawn countdown
- [x] 39 tests, incl. Codex acceptance 1, 2 and 7 (bot beats an idle side; bot vs bot soak)

**M2 — the Relay and hero-hit aggro**
- [x] `RelayController` state machine DORMANT → SPAWNED → CARRIED ⇄ DROPPED, ending in
      delivered or expired. First Relay 1:00 with a 10 s warning, then 70 s after each
      delivery/expiry, alternating pockets; delivery pocket is always the other one
- [x] Pickup 0.5 s in the 1.3 m ring; carrier at 90% speed; two enemy-hero hits within 3 s
      knock it loose (minion and tower hits never count); KO or F drops it; 0.75 s lockout;
      returns home after 8 s; 0.8 s in the delivery pocket delivers unless the enemy hero
      stands in that pocket; untouched Relay fades after 25 s
- [x] Reward: one siege minion (750 HP, 3x structure damage) in the next wave
- [x] Hero-hit aggro (Lucy's rule, replaces the GDD's fixed minion/tower priorities, see below)
- [x] Bot: carries and delivers, intercepts an enemy carrier, contests a Relay it can reach
      first, routes around pocket pillars, and only trades with the hero when that won't
      pull more than one enemy minion or a tower; otherwise taps a minion (ranged first)
- [x] Visuals: gold gem (overhead while carried), pickup ring + progress fill, drop beacon,
      warning pulse, pocket outlines, delivery fill, off-screen arrow, "!" over called
      units, Relay status line + callouts, Drop button
- [x] 62 tests (aggro 8, Relay 15 added)

**M3 — gold and the six-item deck**
- [x] Gold: 2/s passive; minion bounty 20 melee / 30 ranged / 60 siege to the enemy hero
      if it is within 6 m of the minion when it dies (Lucy's accessibility rule, shown as a
      faint gold circle, "+20" pops up), or if it landed the killing blow from farther out;
      50 to the other hero on every knockout
- [x] Eight items from GDD 8 as `data/items/*.tres`; pick exactly six in the menu (default
      deck pre-selected); one-tap buy (cards or keys 1–6), max three, no duplicates,
      permanent for the match, kept through knockouts
- [x] Effects: move speed, max HP (also heals the added amount), damage, attack speed,
      range, Siege Banner aura (+12% within 7 m), Recovery Sigil (2%/s after 7 s free of
      hero damage). Anchor Charm does nothing yet: nothing knocks back until abilities land
- [x] HUD: gold, six cards (price / OWNED / full), your and the opponent's three items;
      Tab collapses the cards
- [x] Bot buys from a per-hero wishlist and saves up for the next item on it
- [x] 75 tests (13 economy added), incl. Codex criterion 6 rules and "2+ items by 6 min"

**Next: M4 — proof of strategy (metrics runner, tuning).**

## Assumptions (change by editing data)

- Map: 10 m wide lane, 84 m long; pockets 5 × 12 m at the centre; pillars split each
  pocket mouth into two 4.5 m entrances. Structures at y = -16, -27, -37 (blue): 11 m from
  Outer to Inner, 10 m from Inner to Core, 32 m between the two Outer Towers.
- Hero speeds 4.2–5.4 m/s, radius 0.5 m. Combat numbers in `data/heroes/*.tres` are seeds for M1.
- Walls block movement and sight; units block neither sight nor each other (yet).
- The local human is always shown as blue at the bottom; F2 tests the other seat.
- No Godot physics or navigation server: circles and rectangles on a plane.
- Heroes walk through minions; minions push apart from each other only.
- **Base healing (not in the GDD):** heroes within 7 m of their own Core heal 12% max HP/s.
  Without it damage is permanent until death, since the GDD has no regen outside an item.
- The Core shoots like a tower.
- **Hero-hit aggro replaces GDD 5's fixed priorities.** GDD: minions hit minions > heroes >
  structures; towers hit minions > heroes. Now, when a hero's attack lands on the enemy
  hero, the victim's minions within 6.5 m of the attacker switch to the attacker for 3 s
  (refreshed by each hit, dropped if the attacker gets 9 m away), and every victim tower
  that has the attacker in range switches for 4 s and deals 1.5x damage to them. Outside
  that, the GDD priorities still apply. All numbers are in `match_config.tres` ("Hero-hit aggro").
- Relay details the GDD leaves open: pickup progress counts while you are inside the ring
  (moving is fine) and resets if you leave; if both heroes are inside, neither progresses.
  Delivery progress pauses while contested and resets if the carrier leaves the pocket.
  A dropped Relay that returns home gets a fresh 12 s expiry so it never vanishes suddenly.
- The pockets sit opposite each other at mid-lane, so a clean delivery is a ~3 s walk.
  Lucy's playtest (2026-10-24): fine for now; the enemy did contest and steal it.
- Economy: knockout gold goes to the opposing hero whoever finished the knockout (a tower
  kill still pays). Structures pay no gold (the GDD lists none). The opponent's deck stays
  hidden; only their bought items show. Wave acceleration at 5:00 (optional in the GDD)
  is not in yet. Gold pacing: bots own 2–3 items by 6 min, the GDD's target.
- Pacing: bot vs an idle opponent took ~14 min to win in M1 (~10.5 min with Relay sieges), mostly the Core. Minions deal 1.5x
  to structures and towers deal 70. Real tuning waits for the M4 metrics runner.
- Hero abilities (Q/E) are not in M1; the buttons stay disabled.

## Known gaps

- Safe-area handling only offsets the top band on phones; full notch/home-bar pass in M5.
- Browser builds in a landscape window scale the portrait UI down; play in a narrow
  window or on a phone for the intended layout.
- FPS in CI/sandbox screenshots is software rendering, not a real measurement.
