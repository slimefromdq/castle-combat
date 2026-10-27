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
- `src/main.gd` — boots the main menu (`src/ui/menu/`) and dev command-line flags.
- Input actions are registered in code by the `InputSetup` autoload (`src/input/input_setup.gd`).

Visual language: you are always blue with a circle under your units; the opponent is
orange with a diamond. Silhouettes: Avery = armored block + skirt + long sword, Jose = coat + wide red hat +
two revolvers, Jack = flared coat + floating cards (older notes below still name the
placeholder heroes Vanguard/Scout/Gunner they replaced), towers = hex pillars (inner taller), Core = gem. Locked
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
- [x] Guardians replace the Inner Towers: 4,200 HP, 8 m range, a beam (14 per 0.3 s) that
      gains +80% per second on one target up to x5 and resets on a new target. Like towers,
      the beam targets you only when no troopers are in range or you hit its hero in range
      (Lucy: hitting the Guardian itself does not draw it).
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
  (others 9:54 and 20:40); after 8:52 to 11:26.
- Watch: once a Guardian falls the Core usually follows within ~15 s, because overtime
  waves stack up and all turn into power minions at once (snowball by design, but steep).
  Heroes sit on 3,000+ unspendable gold late; a gold sink (consumables?) may be needed.

### M7a: structure polish (Lucy's playtest notes)

- [x] Structures stay dormant (can't be hit, don't attack) until the one in front falls
- [x] Troopers hard-focus structures: any structure in reach beats minions and heroes
- [x] Towers drop a hero target the moment a trooper is in range
- [x] Guardian rework: 5,000 HP, 7 m range, weaker beam (9 per 0.3 s, +50%/s up to x4),
      drawn whenever it fires, colour heats with the ramp, a pulsing ring marks the target.
      Stomp only at 66% and 33% health: 1.5 s telegraph (red disk filling a 7.5 m ring),
      then 220 + knockback + 1.5 s stun to the hero, 60% max HP to every enemy trooper
      inside (and a shove), then 3 s rest
- [x] Outer Tower HP 1,300 (was 1,000) to keep match length after the changes
- [x] Healing pad behind each Core (2.6 m, 12% max HP/s); heroes spawn on it. It shuts off
      once your Guardian falls, so the Core is never a healing fortress
- [x] Dev arg `--stage=guardian|stomp` sets up a Guardian dive for screenshots
- [x] 126 tests
- Bot-vs-bot length: 6:34 to 10:27 (was 8:52 to 11:26)

### M7b: quality of life (Lucy's playtest notes)

- [x] (Replaced by sprinting in M8.) Recall (B or the button above E): stand still 3 s to land on your healing pad.
      Moving, casting, carrying the Relay, stuns, knockbacks or any damage cancel it.
      The bot recalls when low and nobody is near
- [x] Shop range: buy and sell only within 8 m of your front (active) structure or your
      Core/pad. Cards read "at tower" elsewhere
- [x] Map +5% (every ArenaData number x1.05: lane 88.2 x 10.5 m), camera 14 m wide (was 16)
- [x] Denying pays the denier 40% of the bounty (the enemy still gets half by the nearby rule)
- [x] Basic-attack items: Whetstone (early, 350: +15% damage, +8% attack speed),
      Executioner's Edge (mid, 1000: +15% damage, +30% basic damage on heroes below half),
      Duelist's Crest (late, 2200: +20% damage and attack speed, every 3rd hit on the hero
      adds 7% of its max HP). Default deck and Scout/Gunner bot decks use them
- [x] 132 tests
- Bot-vs-bot length: 7:17 to 8:54

Lucy tried an Underdog Relay comeback (PR #12) and dropped it: the Relay stays as it is.

### M8: sprinting and camera clamp (Lucy)

- [x] Recall removed. Sprint instead: 3.5 s of moving in roughly one direction (within
      50 degrees of a running direction that follows gentle curves), with no hero combat or
      damage taken in the last 3 s, gives x1.45 move speed. Stopping (attacking), a sharp
      turn, casting, carrying the Relay, stuns, knockbacks or any damage end it
- [x] Look: each hero leans and bounces its own way and leaves a coloured speed trail
      (Vanguard orange, heavy lean; Scout cyan, low dart; Gunner yellow, hopping).
      Values in the "Sprint look" group of each hero .tres
- [x] Base round trip (tower front y=-12 or mid-lane y=0, to the pad and back):
      Vanguard 15.3 -> 13.2 s and 20.2 -> 16.5 s; Scout 12.5 -> 11.1 s and 16.4 -> 13.9 s;
      Gunner 16.0 -> 13.7 s and 21.1 -> 17.2 s. Sprint saves 12-19%; going home stays a cost
- [x] Camera clamp: the stretch of ground between the HUD bands never goes past the end
      walls (+0.8 m), so no void behind either base
- [x] Dev arg `--stage=sprint` (pair with `--walk-up`)
- [x] 132 tests. Bot-vs-bot length: 6:16 to 11:04

### M9: main menu (Lucy: Clash Royale layout, zine look)

- [x] `MainMenu` (`src/ui/menu/`): top bar (level, name, trophies, coins, gems: placeholders),
      swipeable pages, bottom tab bar Shop · Heroes & Items · Battle · Clan · Tournaments
- [x] Battle: your hero's match model on a turning paper pedestal (`HeroStage`, ink outline),
      arrows to change hero, blurb, deck strip (tap to edit), big PLAY! (sends you to
      Heroes & Items if the deck is short)
- [x] Heroes & Items: hero cards with 3D models and their kit, your 8-card deck, all 16 items
      by tier, tap to add/remove, detail footer. Replaces the old pre-match picker
- [x] Shop, Clan, Tournaments: "coming soon" pages
- [x] Zine kit: `ZineBox` (crooked cut-paper StyleBox, hard shadow, tape, halftone),
      `ZinePaper` collage backdrop, `RansomText` cut-out lettering, `DoodleIcon` tab icons.
      Fonts in `assets/fonts` (Luckiest Guy, Permanent Marker, Patrick Hand; Apache/OFL)
- [x] Dev args `--tab=shop|heroes|battle|clan|tournaments`, `--hero=N` for menu screenshots
- [x] 135 tests (3 menu tests)

### M10: Avery, Jose and Jack (replace Vanguard, Scout, Gunner)

- [x] Hero sheets: https://claude.ai/artifact/9CPvn4NAAjhpxD7kebD7o6 . Every hero moves at 4.6
- [x] Perks: pick 1 of 2 at levels 2, 4, 6 (`HeroData.perks` holds pairs, `HeroState.perk_picks`,
      `PlayerCommand.perk_pick`, HUD cards + Z/X). Unpicked after 12 s: first option
- [x] Follow-up casts on the same button (`Abilities.can_recast`): Jose's second dash (only after
      the first volley hits) and charged-shot release; Jack's cloak teleport and vanish burst
- [x] Skillshots (`Skillshot`, `sim.skillshots`): fly, can be dodged, walls stop them.
      Judgment Blade stops at the hero, Sweet Talk at the first unit, the cloak pierces
- [x] Jack's ult casts the enemy hero's ult (`Abilities.ability_for`) on his own cooldown,
      whether or not the enemy has unlocked it. No mirror matches (the bot takes the next hero)
- [x] Vanish: immune and untargetable; Misdirection: troopers and towers lose Jack 1.5 s
- [x] Sleight of Hand: killing blows already pay at any range, so it pays +50% for cloak kills
- [x] Sprint fix: `Sprint.blocked` no longer calls `move_forced` (it moved dashing heroes twice a tick)
- [x] Dev: `--stage=duel|perk`, `--hero=N` works with `--autoplay`; `tools/bot_matches.gd`
      runs every pairing with rotated perk picks
- [x] 154 tests. Bot matches (3 per pairing and seat): Avery 8/12, Jose 7/12, Jack 3/12;
      length 6:40 to 13:03 (median 10:34); Lv3 1:41, Lv5 3:59, Lv6 5:24 (medians)

### M11: power spikes (Lucy picked ideas 1, 2, 3, 4, 6, 8, 9, 10, 11)

Doc: https://claude.ai/artifact/7U1bEzZcY6GZDvb87P4Zo3

- [x] 1 Level timeline: target Lv3 ~1:30, Lv5 ~3:30, Lv6 ~5:30. Lv6 now needs 1,400 XP (was 1,200)
- [x] 4 Wave XP is the main source: passive XP 1.0 -> 0.35 per second; troopers give 22 XP
      (was 15), siege 60 (was 40)
- [x] 2 Level-up surge: +15% max HP healed and +30% attack speed for 3 s (`HeroState.surge_until`)
- [x] 3 Ult race: `sim.ult_race_winner`, `ult_race_won` event, HUD callout, a column of light
- [x] 6 Push, then shop: gold pulses with "Shop!" while a card is affordable away from the
      shop, plus a one-time callout per card
- [x] 8 Masterwork (Lv6 gold sink): pay 50% of an owned item's price for +25% to its stats and
      effect strengths (`Items.MASTERWORK_FIELDS`; thresholds, timings and counts unchanged).
      `HeroState.masterworks` holds boosted copies; `item_with`/`item_total` read them. Selling
      refunds half of both prices. HUD buttons at the shop (C/V/B); the bot buys them once
      its wishlist is done. Siege scrolls not built (the doc offered them as an alternative)
- [x] 9 Enemy spike icons: their name and items pulse for 8 s after a mid or late item, a
      Masterwork, or their Lv5 first, with a callout. Their XP bar was already there
- [x] 10 Level-up ring: gold ring on every level-up, bigger double ring at Lv5. No sound
      yet (the project has no audio)
- [x] 11 Item silhouettes: mid item = glowing weapon, late item = Avery's pauldrons and
      cape, Jose's poncho, Jack's top hat and cape; Masterwork = a gold gem over the head
- [x] Dev: `--stage=spikes|ultrace`; `tools/bot_matches.gd` prints Lv4, per-hero Lv5 times,
      how often the first to Lv5 won, and Masterworks made
- [x] 159 tests. Bot matches (4 per pairing and seat): Avery 15/16, Jose 9/16, Jack 0/16;
      length median 9:26; Lv3 1:31, Lv4 2:22, Lv5 3:25, Lv6 5:31; first to Lv5 won 21 of 24.
      Jack loses with or without the surge and Masterworks (0-1 of 8 either way), so his
      weakness predates this; he levels as fast as the others

### M12: wave depth (Lucy picked ideas 1, 5, 7 and 8)

Doc: https://claude.ai/artifact/VbQ4tux3mNk3tAK6rJV1pG

- [x] 1 Last-hit bonus: a killing blow pays +15% (`last_hit_bonus`); proximity gold unchanged
- [x] 5 Wave meeting marker: `Waves.meeting_y` (halfway between the two wave fronts); the view
      smooths its drift and draws an arrow on each lane edge (floats above the mid-lane pillars)
- [x] 7 Special troopers every 3rd wave (`special_wave_every`), alternating Sapper (320 HP vs
      melee 280, structure damage x5) and Shieldbearer (`shield_blocks` = 1: the first enemy
      skillshot touching it ends there, no damage)
- [x] 8 Banners: a dead special trooper drops one for 15 s; the first hero within 1 m takes
      it and their team's next wave gets +20% HP and damage (`sim.banner_pending`). Bots grab
      banners within 10 m when healthy and out of tower reach
- [x] Jack (Lucy: "bot skill issue, buff cloak and burst"): Cloak Toss 110 -> 135 (troopers
      100 -> 115), Vanish burst 100 -> 150 (troopers 80 -> 100), burst radius 3.2 -> 3.8 m
- [x] Fix from M11: the "Shop!" pulse and "you can afford" callout fired when you could not
      afford the card (shop range was checked before gold)
- [x] Dev: `--stage=waves`
- [x] Levels re-tuned for the extra wave XP: Lv4 560, Lv5 920, Lv6 1,560
- [x] 166 tests. Bot matches (4 per pairing and seat): Avery 13/16, Jose 11/16, Jack 0-3/16
      (the bot can't play Jack's range-and-cloak style; Lucy finds him strong by hand);
      length median 8:42; Lv3 1:29, Lv5 3:17, Lv6 5:18

### M13: playtest gameplay pass (Lucy)

- [x] Special troopers every 4th wave (`special_wave_every` 3 -> 4): first towers fell too fast
- [x] Relay: one enemy-hero hit knocks it loose (`relay_intercept_hits` 1). Minions and towers don't
- [x] Bushes (`ArenaData.bushes`, mirrored): a hidden enemy hero can't be targeted, aimed at or
      seen. Attacking, casting or an enemy-hero hit reveals for `bush_reveal_time` 1.5 s; an
      enemy within `bush_reveal_radius` 2.2 m sees you. Bots treat a hidden hero as absent
- [x] Map 5% bigger (lane length, width, structure and wall positions x1.05)
- [x] Core immune for `core_immunity_time` 8 s after its Guardian falls (dome + countdown)
- [x] Siege scrolls: Lv6, at the shop, 350 gold (+100 each), at most 2 pending; adds to
      `pending_siege` like a Relay delivery. Bots read them once their Masterworks are done
- [x] Fix from M11: C/V/B Masterwork keys were never wired (wrong indent in an edit)
- [x] Dev: `--stage=bush`, `--stage=core`; bot runner prints Relay and scroll counts
- [x] 170 tests. Bot matches (4 per pairing and seat): Avery 13/16, Jose 10/16, Jack 1/16;
      length median 9:22 (was 8:42); Lv3 1:25, Lv5 3:37, Lv6 5:55. Relays: 138 of 155
      delivered even with 67 knock-loose hits (carriers pick it back up). Bots alternate
      Masterworks and scrolls (6 scrolls in a 12-match check)

### M14: playtest UI pass (Lucy)

- [x] Aimed skillshots: `PlayerCommand.aim` (sim space). Judgment Blade, Sweet Talk, Cloak Toss
      and Spin Dash use it when set; zero keeps the old auto-aim (bots). Desktop aims at the
      ground under the mouse; touch drags the ability button (`AimButton`, multi-touch like the
      joystick) with a ground aim line, and a tap casts the way you last moved or aimed
- [x] Match clock under the top band, with the Relay timer and "Overtime in N" in the last
      minute (`Pacing.overtime_at`)
- [x] Cleaner HUD: slim top and bottom bands, structure pips instead of six health bars, item
      cards only in shop range (Masterwork and scroll row at Lv6), details panel on Tab / i,
      tool buttons folded into a ☰ menu, debug readout off by default
- [x] Fullscreen: F11 anywhere or the ☰ menu (`UiKit.toggle_fullscreen`); wide screens put the
      HUD in a centred column (max 1000 px or 0.8 x height)
- [x] Camera clamp: sideways it now stays inside the map's sides and always keeps your hero
      1.4 m inside the screen edge (the side pockets used to push you off screen); bands
      come from `Hud.TOP_BAND` / `Hud.BOTTOM_BAND`
- [x] Dev: `--stage=aim`, `--stage=shop`
- [x] 176 tests

### M15: closer camera, five new heroes, stats and items (Lucy)

- [x] Camera closer: `VIEW_WIDTH` 14 -> 11.5, `LEAD` 2.7, hero side margin 1.2; clamp unchanged
- [x] Stat model (`HeroStats`): ATK = base + growth + items; AP = growth + items, x (1 + amp).
      Abilities scale with `ap_ratio` / `atk_ratio` / `hp_ratio` (`heal_ap_ratio` for shields
      and heals). Per-level growth (`hp_per_level`, `attack_power_per_level`,
      `ability_power_per_level`). Armor cuts basic hits, Ward cuts enemy hero ability and item
      damage, both as 100 / (100 + points); pierce ignores a share. Cooldown haste divides cooldowns
- [x] Stat card (`StatCard`): lean, five rating pips, Lv1 -> Lv6 HP / ATK / AP, speed and range
      in the hero menu; live stats in the in-match details panel; every ability shows its scaling
- [x] 14 new items (16 -> 30): flat stat items, Runed Saber (ability resets the attack timer),
      Warlord's Greatsword (splash), Sunder Pick / Hex Needle (pierce), Archmage's Crown (AP amp,
      the late gold sink), Phoenix Feather (cheat death). Old % items converted to flat stats
- [x] Ahab (hook, Keelhaul fling, White Whale lane), Slayer (bear traps, Recoil Bolt, Headsman's
      Axe), Huddle (Latch Cloud, Scatter, Swarm Storm; Buzz stacks -> Overwhelm), Poppet
      (Threaded Needle + reel, Wind-Up Key terror freeze, Cut to Ribbons), Tot (Sovereign Sweep
      with Blood Price, Borrowed Time, Absolute Rule; Blood Debt defers 35% of damage).
      All kit logic in `src/sim/kits.gd`; displacement into a tower turns that tower on the victim
- [x] Looks: five silhouettes + gear tiers; traps (owner sees, enemy sees a glint within 2 m),
      delayed-cast telegraphs, thread and hook lines, swarm, root / silence / phase markers,
      Absolute Rule ring, Debt slice on the HP bar, Buzz pips over it
- [x] Bot rules for the five kits; `tools/bot_matches.gd` takes a shard (`-- 1 0/3`)
- [x] 207 tests. Bot matches (1 per pairing and seat, 56 games): Slayer 14/14 at first, so
      he lost HP 590 -> 540, ATK 42 -> 39, trap root 1.2 -> 0.9 s, trap cooldown 7 -> 9 s.
      After: Avery 13/14, Slayer 12/14, Jose 10/14, Ahab 6/14, Tot 5/14, Poppet 5/14,
      Huddle 3/14, Jack 2/14; length median about 8:30; first to Lv5 won 31 of 56 (was 21 of 24).
      The bots play the melee kits plainly; human playtests should decide the next tuning

### M16: cheaper items (Lucy: items felt like they didn't matter)

- [x] Early items 300–400 -> 150–200, mid 900–1100 -> 700–800, late 2000–2400 -> 1400–2000
      (each tier keeps its internal order). Masterworks stay a share of the item price; siege
      scrolls keep their own price. No bot run, at Lucy's request

**Next: metrics runner; M5 iOS.**

## Assumptions (change by editing data)

- Map (before the +5% scale in M7b): 10 m wide lane, 84 m long; pockets 5 × 12 m at the centre; pillars split each
  pocket mouth into two 4.5 m entrances. Structures at y = -16, -27, -37 (blue): 11 m from
  Outer to Inner, 10 m from Inner to Core, 32 m between the two Outer Towers.
- Hero speeds 4.2–5.4 m/s, radius 0.5 m. Combat numbers in `data/heroes/*.tres` are seeds for M1.
- Walls block movement and sight; units block neither sight nor each other (yet).
- The local human is always shown as blue at the bottom; F2 tests the other seat.
- No Godot physics or navigation server: circles and rectangles on a plane.
- Heroes walk through minions; minions push apart from each other only.
- **Base healing (not in the GDD):** heroes on the pad behind their own Core heal 12% max HP/s
  (off once their Guardian falls).
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
- Item damage (storm strikes, Overcharge) is cut by Ward but does not scale with AP, and
  never triggers on-hit effects (no chains). Overcharge and storms skip structures.
- Aegis Mirror only blocks hits of 60+ before defences, so single Barrage pulses get through.

## Known gaps

- Safe-area handling only offsets the top band on phones; full notch/home-bar pass in M5.
- Browser builds in a landscape window scale the portrait UI down; play in a narrow
  window or on a phone for the intended layout.
- FPS in CI/sandbox screenshots is software rendering, not a real measurement.

## Occult expansion, phase I: map and votive candles

Plan: [Occult Expansion Plan](https://claude.ai/artifact/8cY8YgQfxRdwM9Koj3BefU).

- Lane 15% longer (`half_length` 53.25); structures, spawns and pockets moved with it.
- Four back alleys (`ArenaData.alleys`), one on each flank of each half between the Outer
  Tower and the Guardian, joined to the lane by two 2.4 m gaps, with a bush each.
- Votive candles (`PickupController`, `ArenaData.candles`): six, mirrored. Two in each
  team's home alleys, one in each Relay pocket. All light at 1:30, relight 60 s after being
  taken. Stand on one alone for 0.5 s without taking damage: 45 XP (with catch-up) and 25 gold.
- `CandleView` draws them and puts screen-edge arrows on lit candles off screen.
- Bots take a lit candle on their half or in a pocket when nobody contests it.
- Overtime moved to 11:00 (15:00 if a Guardian has fallen).
- Screenshots: `--stage=candles` and `--stage=alley`.

## Occult expansion, phase II: nine levels, Lv6 ults, hero passives

- Max level is 9 (`level_xp` in `data/match_config.tres`). Ladder: abilities at Lv1/3/6 (ult at 6), perk picks at Lv2/4/7, automatic hero passives at Lv3/8, siege scrolls at Lv7 (`siege_scroll_level`), Masterworks at Lv8 (`masterwork_level`), Lv9 is the crown (surge heal and time doubled, gold crown ring). Constants live in `Leveling`.
- Passives are `PassiveData` resources in `data/passives/`, listed on each hero's `passives`. Flat stats feed `HeroState.recompute_stats`; `special` handles the odd ones (Poppet lifesteal / Restitched, Tot debt_slow).
- Poppet has 10% baked-in lifesteal on basics (`HeroData.lifesteal`); Restitched doubles it below 40% HP.
- Tot's Debt drains at 30 HP/s (was 45). Deferred Tribute slows it another 25%, stacking with Iron Faith.
- Ahab's Lv8 is Old Leviathan (+150 HP, +8 ATK) rather than a longer harpoon, which would duplicate the Long Line perk.
- Latch Cloud reworked: aims at heroes, passes through troopers, a big swarm and a BUZZ n/need counter show on the latched hero, damage ticks show yellow numbers, and a miss lingers 2 s as a small cloud.
- Bear traps show to the enemy as a chalk outline; the spikes stay hidden unless you're the owner or within 2 m.
- Tests: `tests/test_progression.gd`.

## Occult expansion, phase III: Serpent, Fermata and KOSMONAUT

- Eleven heroes. The new kits live in `src/sim/occult_kits.gd` (OccultKits), reached from `Kits` (cast, tick, skillshot hits, basic hits, clear). Their visuals are in `src/view/occult_fx.gd`; bodies are placeholders in `UnitFactory` (shapes `serpent`, `conductor`, `kosmonaut`) until Lucy's art arrives.
- **Serpent** (trait `venom`): basics add 1 Venom, Fang Dart 2, each viper bite 1 (max 8). Venom pops 2.5 s after the last stack for 14 + 0.12 AP per stack, raised by the target's missing HP share, capped at 30% of max HP, and only if Serpent is within 9 m (else it fizzles). A pop halves Shed Skin's cooldown left. Shed Skin can be cast while rooted and sheds roots and slows. Snake Pit: 3 vipers for 4 s, 6 m/s, bite every 1 s. Lv8 Neurotoxin: pops slow 40% for 1 s.
- **Fermata** (trait `ensemble`): up to 2 instruments; a third replaces the oldest, which plays its final note (30 + 0.2 AP in 2 m). Brass Section: 5 m cone (35° each side), 90 dmg, 2.5 m knockback, the tuba floats 2.5 s. Strings: 2.5 m circle up to 6 m away for 4 s, 8 pulses of 12, slows 25%. Grand Finale: 4 waves over 1.6 s in 4.5 m, 55 each, 1.5 m push. Lv8: instruments last 1 s longer.
- **KOSMONAUT** (trait `drone`, reworked after Lucy's playtest: the orbit was hard to control): the drone hovers at his side (always the same side, it never spins) or where he parked it, and zaps the nearest enemy within 3 m once a second for 22 + 0.15 AP (16 to troopers; it doesn't zap in flight). Launch Drone throws it up to 8 m at 16 m/s, 50 dmg to all it flies through; tap again to call it home (hitting again on the way); it comes home by itself past 12 m. Pulse: 70 dmg in 2.5 m around the drone and a 30% slow. Re-entry: lands after 1 s where the drone is, 160 dmg in 2.2 m, 0.6 s knock-up. Jack's Encore drops it on the enemy hero instead. Lv8 Escape Velocity: the drone flies 40% faster and zaps from 3.5 m.
- Bot: decks, wishlists, perk picks and ability rules for all three; Jack knows their ult reaches. No bot balance runs (Lucy playtests).
- HUD: long names step the font down; Venom shows as green pips and a countdown strip under the HP bar, plus "VENOM n" and a closing ring on the hero.
- Tests: `tests/test_occult.gd`.

## Occult expansion, phase IV part 1: street-occult world and hero animation

- **World** (`src/view/arena_view.gd`, `src/view/street_art.gd`): the map is a bright occult street. Cobbled lane, brick-red alley cobbles, violet pocket flagstones and a mossy plaza outside, all drawn in code as small cached textures and laid in world space (triplanar), so nothing stretches and there are no image assets. Walls are painted brick (rose, teal, mustard, lilac, cream, mint, picked by position so both halves match) with a painted cap. Chalk ritual circles sit under every structure, in each Relay pocket and on the heal pads; faint spray-paint sigils mark the lane edges. Outside the walls: shopfronts with glowing windows, awnings and neon sigils, lanterns, tarot banners and planters. Everything stays mid-tone; team colours, chalk and telegraphs still pop. Decorative candles were left out on purpose so they can't be mistaken for XP candles.
- **Animation** (`src/view/hero_animator.gd`, `src/view/anim_style.gd`): one animator for all heroes, tuned per hero by an AnimStyle (`AnimStyle.for_shape`). Idle breathing and sway, a walk cycle driven by distance moved, sprint lean, attack windup pull-back plus a strike (lunge, recoil, swing or hop), a cast pose (raise, spin, stomp, bow, leap or grow), a bigger ult pose, and a hit stagger. Timing comes from sim state and events (windup progress, `attack_fired`, `ability_cast`, `last_damaged_time`), so poses match the game. It only moves each hero's `Body/Pose` node, so Lucy's art can replace the parts inside without touching the animation. Troopers waddle and rock back on their windup.
- Tests: `tests/test_view.gd`.

## Occult expansion, phase IV part 2: lettering, portraits, intro, victory, menu

- **Lettering** (`src/ui/hero_lettering.gd`): each hero's name uses its own OFL font (table in `assets/fonts/README.md`, licences in `assets/fonts/heroes/licenses`), with a per-font size scale and Barlow Condensed as the fallback for missing glyphs. The HUD theme's default font is Barlow Condensed SemiBold. Names show in their lettering in the HUD bands, the menu showcase and hero grid, the intro and the victory flyer.
- **Portraits** (`src/ui/hero_portrait.gd`, `src/ui/portrait_mood.gd`): both HUD bands show a portrait with four moods. Low HP wins: on below 30% HP, off above 40%. Ahead/behind come from level gap + (gold on hand + item value) gap / 400, on at ±1.0, off inside ±0.4, held at least 2 s. Placeholder faces until art lands: drop `assets/portraits/<hero id>_<neutral|ahead|behind|low_hp>.png` and the portrait uses it with no code change.
- **Intro** (`src/ui/match_intro.gd`): 3 s, two flyers (theirs on top, yours below) with lettering, portrait and blurb, and a VS. Tap/click/key skips after 1 s. The match clock doesn't run until it's gone. `--autoplay` dev runs skip it (`--intro` forces it); tests never build it.
- **Victory** (`src/ui/match_victory.gd`): when the last Core falls, a 3 s VICTORY/DEFEAT flyer with the winner's lettering and grinning portrait, plus confetti; the camera zooms in (`CameraRig.zoom`), the winner loops their ult pose as a dance and the loser slumps (`HeroAnimator.celebrate`). The result panel waits for it. Dev stage `--stage=win` shows it.
- **Menu** (`src/ui/menu/zine_paper.gd`): the backdrop is a painted brick wall plastered with street flyers (printed eye/moon/pentacle sigils, tear-off tabs, staples, tape), a tarot card, chalk sigils and spray dots. Layout and buttons are unchanged.
- Tests: `tests/test_view.gd` (moods, lettering, intro and victory timing).

## Occult expansion, phase V: sound

- **No audio files.** `src/audio/sfx_synth.gd` (SfxSynth) builds every sound from recipes: oscillators (sine, triangle, square, saw, grainy noise) with pitch slides, envelopes, arpeggios, vibrato and a sweeping low-pass, mixed through a soft limiter into a 16-bit AudioStreamWAV. The 71 recipes live in `src/audio/sound_bank.gd` (SoundBank). They render on first use and are cached; `Sfx.warm_up()` renders them one per frame while you're in the menu (about 1 s of work in total on desktop).
- **Playback** (`src/audio/sfx.gd`): `Sfx.play(name, volume_db, pitch, gap)` from anywhere, with a pool of 14 voices (oldest stolen) and an optional per-sound minimum gap. Volume and mute are saved to `user://settings.cfg` and applied to the Master bus.
- **Match sounds** (`src/audio/match_audio.gd`): `MatchAudio.sound_for(event, data)` maps sim events to sounds. Basic attacks sound like the hero (Jose's gunshot, Serpent's dart, Fermata's baton, KOSMONAUT's zap...), casts get Q/E whooshes and an ult boom (Fermata's Grand Finale is a chord instead), and hooks, traps, venom pops, vipers, the drone, Re-entry's whistle and boom, the whale, Tot's Rule, Judgment and so on have their own. Every Fermata instrument has a voice: tuba, violin, plucked string pulses, drums and the final-note chime. Your own fights play at full volume; anything else fades 1.1 dB per metre from your hero and is silent past 18 m. Your level-ups, perks, buys, coins, Relay pickups and deliveries, candles, crumbling structures, kills, deaths, respawns and overtime all have sounds. The enemy's progress doesn't ding.
- **Stingers:** paper slaps and a VS hit in the intro, a fanfare on victory and a falling line on defeat.
- **Settings:** a speaker button and volume slider on the Battle page, Sound on/off and a slider in the in-match ☰ menu, and M mutes anywhere.
- Dev: `--perf` with `--screenshot` prints draw calls, visible objects and node count. A busy mid-lane fight is about 150 draw calls and an alley about 240, with about 4.8k nodes (most are static scenery parts).
- Tests: `tests/test_audio.gd` (every recipe renders, is audible and doesn't clip; event mapping; distance falloff; volume and mute).
