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
- [x] Denies (Lucy's pick): tap your own minion at or below 50% HP and stand still to hit
      it; if you land the kill the enemy collects only half its gold. Auto-targeting never
      picks your own minions; deniable ones get a white bar frame. The bot denies only when
      the enemy hero is close enough to collect
- [x] Eight items (seven since M4) from GDD 8 as `data/items/*.tres`; pick exactly six in the menu (default
      deck pre-selected); one-tap buy (cards or keys 1–6), max three, no duplicates,
      permanent for the match, kept through knockouts
- [x] Effects: move speed, max HP (also heals the added amount), damage, attack speed,
      range, Siege Banner aura (+12% within 7 m), Recovery Sigil (2%/s after 7 s free of
      hero damage). (Anchor Charm was removed in M4 at Lucy's request)
- [x] HUD: gold, six cards (price / OWNED / full), your and the opponent's three items;
      Tab collapses the cards
- [x] Bot buys from a per-hero wishlist and saves up for the next item on it
- [x] 75 tests (13 economy added), incl. Codex criterion 6 rules and "2+ items by 6 min"

**M4 — levels and abilities (Lucy's request; replaces the GDD's "no levels/XP" rule):**

- [x] Six levels. XP: 1/s passive for both heroes; enemy minions pay XP by the same rule
      as gold (melee/ranged 15, siege 40, half if denied); a knockout pays 90 + 25 per level
      the victim is above the killer. Thresholds 0 / 120 / 300 / 550 / 850 / 1200
- [x] Catch-up: +25% XP per level you are behind the enemy hero
- [x] Lv 1 first ability, Lv 2 small perk, Lv 3 second ability, Lv 4 larger perk,
      Lv 5 ultimate, Lv 6 capstone perk (`AbilityData`, `PerkData`, listed on each `HeroData`)
- [x] Kits:
      Vanguard: Shield Bash (dash + knockback) · Bulwark (shield) · Earthshaker (ult, AoE stun);
      perks Thick Hide (+10% HP), Battering Ram (Bash −3 s, more knockback), Bastion (−30% damage while Bulwark is up).
      Scout: Dash · Flurry (+attack speed) · Blade Rush (ult, gap-close strike);
      perks Light Feet (+6% speed), Second Wind (Dash −2 s), Finisher (+30% damage to heroes under 35% HP).
      Gunner: Power Shot (long shot) · Recoil (hop back + slow) · Barrage (ult, channelled 4-pulse zone);
      perks Long Barrel (+6% range), Hair Trigger (Power Shot −3 s), Siege Battery (Barrage +2 m reach, hits structures)
- [x] Abilities aim themselves (nearest enemy hero, else the nearest enemy); movement
      abilities go where you are steering. A Relay carrier cannot use movement abilities.
      Barrage pulses count as one hit for Relay interception; moving or a stun cancels it
- [x] Ability hits on the enemy hero trigger hero-hit aggro like basic attacks
- [x] HUD: level and XP bar per hero, Q/E/R buttons with cooldowns and unlock levels,
      level-up callouts; shield, stun, slow and zone visuals
- [x] Bot uses its kit (fights only when not under enemy tower and not outnumbered)
- [x] 96 tests (18 abilities/levels added)
- Bot-vs-bot level timings: Lv 2 ~45 s, Lv 3 ~105 s, Lv 4 ~175 s, Lv 5 ~240 s, Lv 6 ~330 s.
- **Snowball risk:** a knockout now pays gold, XP and lane tempo. Catch-up XP and small,
  mostly utility perks soften it; watch for one early kill deciding the match.

**Item overhaul (Lucy's request, after M4):**

- [x] 13 items in three tiers, drawing on Deadlock, Dota and League
      (proposal: https://claude.ai/artifact/QaPSG2DUMJLYXchu4oDRZb).
      Early: Trooper Cleaver, Mending Charm, Fleet Sandals, Spark Band.
      Mid: Bloodthirst Blade, Thorncut (anti-heal), Warding Cloak (ability resist),
      Overcharge Gem (% max HP vs tanks), Siege Banner.
      Late: Stormcrown (ult storm), Reaper's Rhythm (lifesteal frenzy + shred), Aegis Mirror
      (blocks one big ability), Titan Core (ability damage)
- [x] Damage kinds: `basic`, `ability`, `item` (`MatchSim.apply_damage(..., kind)`); item
      effects live in `src/sim/items.gd` (outgoing bonuses, incoming defences, on-hit, on-cast, tick)
- [x] All healing goes through `MatchSim.heal`, so Wounds cut base healing, regen and lifesteal
- [x] Decks hold 8 (Lucy's pick); still 3 slots; sell any owned item for 50% (Lucy's pick)
      by pressing its card or number twice
- [x] Bot: a deck and wishlist per hero, a counter item per enemy hero, sells its cheapest
      lower-tier item when that pays for the next one, never rebuys what it sold
- [x] 109 tests (13 item tests added)
- Bot-vs-bot timings: first early item ~1:00, first mid ~4:30, first late ~9:00–12:00.

**Pacing overhaul (Lucy's request, after the items):** all logic in `src/sim/pacing.gd`,
all numbers in `match_config.tres` ("Pacing: ..." groups) and `data/structures/*.tres`.

- [x] Gold ramp: all gold +8% per minute after 2:30 (x1.6 at 10:00)
- [x] Relay rewards grow: delivery gold 60 + 60 per earlier Relay; one more siege minion
      every second activation (max 3)
- [x] Structure resist: Outer Towers +20%, Guardians and Core +10%, all falling to -30%
      between 2:00 and 12:00. Heroes earn 0.3 gold per point of their damage the resist soaks
      ("or shields" in Lucy's note read as the same thing: there are no structure shields).
      Outer Tower 250 gold, Guardian 400 gold to the enemy hero
- [x] Guardians replace the Inner Towers: 3,200 HP, 8 m range, a beam (14 per 0.3 s) that
      gains +80% per second on one target up to x5 and resets on a new target. Hitting a
      Guardian from inside its range calls the beam onto you (like hitting its hero).
      Slam: an enemy hero within 4.2 m starts a 0.9 s telegraph; anyone still inside takes
      200, is knocked back 5 m and stunned 1.6 s; then the Guardian can't attack for 3.5 s
      (12 s cooldown). Walking out of the ring dodges it
- [x] Guardian kill: power minions for the killer's team, for good (x1.6 HP, x1.3 damage,
      x1.15 speed, live minions too); if the Guardian's own hero is down, their respawn
      time left is cut to 40%
- [x] Minions spawned after 2:00 get +2.5% HP and +2% damage per minute
- [x] Respawn: 4 s + 0.6 s per minute + 1 s per earlier knockout, max 30 s
- [x] Overtime at 10:00 (14:00 if a Guardian has already fallen): structures take x1.4 and
      deal x0.5 damage, new minions x1.4 HP, respawns x1.5
- [x] Bot walks out of a Guardian slam
- [x] 122 tests (13 pacing tests added)
- Bot-vs-bot length (6 matches, every pair, both seats): before 4 of 6 hit the 25 min cap
  (others 9:54 and 20:40); after 12:48 to 15:47, with two comebacks.
- Watch: once a Guardian falls the Core usually follows within ~15 s, because overtime
  waves stack up and all turn into power minions at once (snowball by design, but steep).
  Heroes sit on 3,000+ unspendable gold late; a gold sink (consumables?) may be needed.

**Next: metrics runner and tuning, then M5 iOS.**

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
- Item damage (storm strikes, Overcharge) is resisted by Warding Cloak but not boosted by
  ability damage, and never triggers on-hit effects (no chains). Overcharge and storms skip structures.
- Aegis Mirror only blocks hits of 60+ before defences, so single Barrage pulses get through.

## Known gaps

- Safe-area handling only offsets the top band on phones; full notch/home-bar pass in M5.
- Browser builds in a landscape window scale the portrait UI down; play in a narrow
  window or on a phone for the intended layout.
- FPS in CI/sandbox screenshots is software rendering, not a real measurement.
