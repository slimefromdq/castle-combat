# UNDERTOW: RELAY
## Game Design Document, v0.1 (24 October 2026)

**Status:** Buildable prototype specification. **Working title:** UNDERTOW: RELAY; rename freely. This real-time design supersedes the older turn-based UNDERTOW rules. Character names and setting from that project can be reused later, but turn phases, tiles, XP and card combat do **not** carry over.

## 1. One-sentence pitch
A portrait-oriented, real-time **1v1 single-lane MOBA** where your hero attacks automatically **only when stationary**, every fired basic attack connects, and you outmaneuver your rival through wave control, a stealable carry-the-Relay objective, and a prebuilt six-item loadout.

## 2. Experience pillars
1. **Move or attack:** Stopping is an intentional combat commitment. Timing and positioning are the core micro skill.
2. **Win the map, not just the duel:** Last-hitting, wave pressure, tower defense, and objective routes let a disadvantaged matchup win through better decisions.
3. **Small battlefield, big choices:** One lane, two side pockets, clear minions, two towers and a Core per side. No jungle or RTS minion control.
4. **Deckbuilding without shop homework:** Select six items before the match; purchase any affordable item from that set during play, with three equipment slots.
5. **Instant readability:** Distinctive heroes, short matches, unmistakable telegraphs, portrait-first controls, and symmetric information.

## 3. Audience, platform, scope
- **Primary target:** Mobile phone, fixed portrait orientation; desktop keyboard/mouse debug controls for development.
- **Session target:** Roughly 4–6 minutes, not a hard timeout in the first prototype.
- **Game mode:** Live 1v1. First playable uses human versus a simple bot locally; eventual human-versus-human online.
- **Engine:** Godot 4.7.x / GDScript recommended for the prototype; **new standalone project**, not an EXALT module. Keep gameplay authority separate from input so networking can follow.
- **Art:** Simple readable shapes, colors, bars, and effects for the first milestone; no paid or external assets required.

## 4. Match loop and victory
1. Both players spawn at their Core and advance with autonomous minion waves.
2. A hero moves via joystick/WASD. Releasing movement begins stationary targeting and attack windup.
3. Players last-hit minions for bonus gold while defending their two towers and Core.
4. After an opening interval, a Relay appears in a side pocket. Either player may pick it up, transport it across the center, or instead push the lane.
5. Gold buys permanent match-only items from a six-item preset deck (up to three purchases).
6. Destroy the opponent's two defensive towers in sequence, then their Core, to win. For MVP, do not add hero levels or an XP tree.

## 5. Camera, board, structures
- **Portrait map:** One wide central lane running bottom to top, with two shallow side pockets opening near the center. Both clients see **their own base at the bottom**, using a 180° rotated/mirrored presentation of the same authoritative map when needed.
- **Structures per player:** Outer Tower → Inner Tower → Core, all positioned along the same lane. The next structure can only take damage after the preceding one is destroyed (clear shield state and visual lock).
- **Lane:** Wide enough for two heroes to pass or flank minions; side pockets have two entrances if geometry allows. Avoid walls that trap a melee hero permanently.
- **Minion waves:** Symmetric, autonomous, and deterministic. Prototype: two melee minions plus one ranged minion every 12 seconds, walking the lane and attacking nearby enemies/structures. No player minion commands.
- **Attack selection:** Minions prioritize opposing minions first, then heroes in range, then the next exposed structure. Towers prefer hostile minions, then hostile heroes. Specify and test aggro priorities explicitly.
- **Provisional balance values:** Outer Tower 900 HP, Inner Tower 1100 HP, Core 1400 HP. These are **tuning seeds**, not agreed final values; expose them in data resources.

## 6. Hero controls and combat contract
### Input
- Left thumb: continuous movement joystick.
- Right thumb: Hero Ability, Ultimate, and a **tap-on-unit target override**; no basic-attack button. Tapping an enemy locks it as preferred target until it dies, exits range/LOS for long enough, or the player taps another target.
- Item drawer: six small cards that can be opened or collapsed; purchases are one tap and must never obscure the fight for long.
- Desktop debug: WASD/arrow keys move, Q ability, E ultimate, 1–6 buy items, Tab show deck.

### Basic attacks (nonnegotiable)
- A hero **cannot begin or continue a basic-attack windup while moving**. Any meaningful movement cancels an uncompleted windup.
- When stopped, the hero acquires a valid target in range and line of sight and begins a visible windup. Prefer a player-tapped target if valid; otherwise use a **clear deterministic priority**: enemy hero > last-hittable enemy minion > nearest other hostile unit > exposed structure, subject to explicit range/LOS checks. Tapping a minion must make it possible to last-hit even while an enemy hero is nearby.
- Once an attack is fired, **it is guaranteed to hit its locked target**, even if that target moves afterward. It may use a cosmetic projectile, but no miss chance, projectile dodging, or aim check after firing.
- Movement after firing is allowed; the next attack still requires stopping. Attacks can be interrupted before firing by a stun, death, or movement.
- Provisional seeds: 0.25 s windup; 0.70–1.0 s attack interval; fair-fight hero TTK ~6–10 seconds; all data driven.
- Active hero abilities **may** have dodgeable zones/telegraphs. Guaranteed hit applies to basic attacks, not every ability.
- Damage, range, target selection, interrupts, and hit registration run through shared gameplay logic, not client-only visual code.

### Hero roster for test builds
Begin with three deliberately contrasting **placeholder archetypes**, not a finalized canonical roster:
- **Vanguard (bruiser):** Short-range, sturdy; Ability is a telegraphed shove that displaces an enemy from a good firing position.
- **Scout (skirmisher):** Fast, fragile; Ability is a short dash; particularly good at flanking and Relay runs but worse when planted in a prolonged trade.
- **Gunner (marksman):** Long-range, fragile; Ability places a small temporary hazard; strong when allowed to stand still, vulnerable to displacement.
- Each has one passive, one active ability, and one ultimate (the ultimate can be a simple long-cooldown ability in the first build). Distinctive permanent names/art may be assigned later from the existing UNDERTOW cast.
- Heroes must have viable approaches to both lane defense and the Relay. Do not balance only around isolated 1v1 DPS.

## 7. The Relay: signature macro objective
**Purpose:** Force an interactive *transport, escort, intercept, or lane-trade* decision without giving permanent combat stats.

### Flow
1. First Relay appears at **1:00**; subsequent Relays approximately every **70 seconds** after completion/expiry. A 10-second on-screen warning gives both players time to react.
2. Each activation identifies a **pickup pocket** and the opposite **delivery pocket**. The initial side is fixed for testing; alternate sides on successive activations. Both sides have equal access and identical scoring rules.
3. Pickup requires the hero to stand in the pickup radius for **0.5 seconds**. Either hero may carry it. Only **one Relay exists** at a time.
4. The carrier is globally visible, moves at **90%** speed, can stop and make normal basic attacks, but cannot use movement/dash/teleport abilities. Carrier may manually drop the Relay.
5. **Interception:** Two distinct qualifying enemy-hero hits within a rolling **3-second window** force a drop. Damage-over-time ticks do not count as separate hits from the same cast. Minion and tower hits do not count in the first prototype. This hit rule is a *playtest hypothesis*, especially for ranged matchups.
6. Dropped Relay is neutral, shows a conspicuous ground marker, and cannot be repicked up for **0.75 seconds**. It returns to its origin after **8 seconds** untouched. Both heroes may claim it after lockout.
7. Delivering requires standing inside the target pocket for **0.8 seconds**, uncontested by an enemy hero inside the same pocket. Successful delivery consumes the Relay and queues **one empowered allied siege minion on the next wave**.
8. At the beginning of the MVP, the delivery reward is **never** raw gold, permanent hero stats, direct tower damage, or extra item slots.
9. Relay must have an **expiry/reset rule** (e.g. 25 seconds after spawning if never picked up), with state clearly communicated. During carrier/drop states, avoid an abrupt timeout without warning.

### Meaningful alternatives
- A lane push can take a tower while the rival runs the Relay.
- A losing duelist can reposition to intercept rather than kill the carrier.
- An opponent can decline Relay entirely and convert a prepared minion wave into structure damage.
- Carrier exposes their route and gives up mobility, so owning the objective creates vulnerability rather than a guaranteed reward.

### Balance guardrails
- Relay should be good but **concedable**. If it is almost always right to fight for it, reduce its reward or increase the lane tradeoff.
- A ranged basic attacker must not be able to deny every delivery for free merely by standing still far away; assess pocket geometry, range, and the hit threshold.
- Track Relay capture rate per hero, first-Relay correlation with victory, tower HP traded while Relay was active, and victories by players losing most hero duels.

## 8. Economy and six-item deck
### Gold
- Each hero gains **2 gold per second** passively (prototype seed).
- Last-hit bonus: **20 gold** per melee minion, **30 gold** per ranged minion; no equal last-hit bonus for merely being nearby.
- Hero knockouts award a modest **50 gold**; their primary advantage is respawn time and pressure, not runaway income.
- All amounts tunable; expected total cash should allow about **2–3 meaningful item purchases in 4–6 minutes** if farming reasonably.

### Pre-match loadout and shopless buying
- Choose **six distinct items from an initial pool of at least eight** before the match. The six are visible throughout the match in a compact card tray.
- Cards are available immediately, but only **affordable** cards can be purchased. No shop NPC, recall, or modal item encyclopedia required.
- Purchase any order, **three equipped items maximum**. Purchases are permanent for that match; no selling, combining, upgrading, or inventory swapping in v0.1.
- Items are passive or simple triggered effects in v0.1, avoiding six more active buttons on a phone.
- Remaining gold is displayed. Both players can inspect the opponent's **equipped three items** to reduce invisible knowledge advantages. Opponent's unpurchased six-card deck may remain hidden initially.

### Initial test item pool (illustrative names and prices)
| Item | Cost | Illustrative effect |
|---|---:|---|
| Fleet Sandals | 250 | +8% hero move speed |
| Iron Shell | 350 | +12% maximum health |
| Grip Gloves | 350 | +8% basic attack damage |
| Quickstring | 400 | +10% attack speed while stationary |
| Anchor Charm | 300 | -25% received displacement distance |
| Siege Banner | 450 | +12% allied minion damage to structures while nearby |
| Watchful Lens | 500 | +7% hero basic-attack range |
| Recovery Sigil | 400 | After avoiding hero damage for 7 s, restore a small amount of HP over time |

These are test knobs, **not final economy or balance**. Effects must not stack into unstoppable dueling power. Later items can focus on Relay play, anti-siege defenses, and macro styles without trivializing interactions.

## 9. Hero KO, progression, pacing
- A defeated hero respawns near their Core after a **provisional 7 seconds**. Death never permanently removes them from the round.
- Gold and purchased items remain after death.
- No level or XP system in prototype; it would add a second runaway economy before the basic systems are understood.
- At ~5:00, optionally accelerate waves for an endgame test. **Do not** add sudden random damage, arbitrary Relay rewards, or an automatic victor in v0.1.
- Long-term content ideas: arena variants, telegraphed wave variants, hero mastery, ranked, cosmetics and replays. None are needed for the first playable.

## 10. UI and feedback requirements
- Portrait top-down camera; blue team always locally appears at bottom, opponent at top, regardless of match seat.
- Show both heroes' health, outer/inner/core HP, gold, wave timers, item cards, equipment slots, ability cooldowns, and Relay timer/status.
- Display attack range when stationary, windup pulse, an unmistakable fired-hit cue, target selection highlight, carrier silhouette/trail, drop marker, delivery progress and siege wave spawn.
- Avoid visual clutter: objective warnings should be legible at a glance; friendly/enemy units must never rely on hue alone (shape/outline supports differentiation).
- Phone UI must tolerate touch controls without the item drawer covering the lane.

## 11. Technical design and implementation order
### Suggested Godot architecture
- `MatchController`: match phase, victory, waves, spawn, timers, scoring.
- `Arena`: structure instances, lane paths, pockets, mirrored spawn markers.
- `HeroController`: movement, stopped-state, ability input and targeting policy.
- `CombatSystem`: range/LOS checks, winding up, locked fired attacks, damage, KO and effects.
- `MinionAI`, `TowerAI`: intentionally simple autonomous priority behavior.
- `RelayController`: explicit state machine `DORMANT → SPAWNED → CARRIED → DROPPED → DELIVERED/EXPIRED`.
- `Economy` and `Equipment`: gold events, deck validation, purchase and effects.
- Godot `Resource` data definitions: `HeroData`, `ItemData`, `MatchConfig` to keep values tunable.
- `PlayerCommandSource`: human keyboard/touch and bot both issue gameplay actions through the same interface. Later replace a command source with server-authoritative networking; do not pretend local-only logic is secure multiplayer.

### Milestones
**M0, visible graybox:** Portrait arena, player movement, camera, UI placeholders, two towers + Core per side.

**M1, combat loop:** Movement-cancels-windup basic attacks, guaranteed hit on fire, target logic, autonomous waves, towers, HP, damage, KO/respawn, exposed Core and victory. A simple bot can move, stop, attack and defend.

**M2, Relay loop:** Two pockets, pickup/carrier/drop/delivery/reset state machine, telegraphs, siege-wave reward, bot contest and lane-trade rules.

**M3, economy:** Passive income, last hits, eight-item pool, preselected six-card decks, three-item inventory cap, quick-buy, item stats, bot purchasing.

**M4, proof of strategy:** Debug overlay, test metrics, two more hero archetypes, balance iterations and phone-touch usability. Online 1v1 comes after the local systems feel good.

## 12. Definition of first playable
A player can launch the Godot project, select a hero and a six-item deck, fight a local bot on a portrait map, move/stop to auto-attack, farm gold, buy up to three items, steal/carry/drop/deliver the Relay, generate a siege wave, destroy two towers and the Core, and see a win/loss screen. All major mechanics work with placeholder graphics and no web connection.

## 13. Essential QA / balance checks
- Moving during a windup cancels the attack; stopping enables it. A fired basic attack cannot miss due to subsequent target movement.
- Both local viewpoints are symmetric, with own base at bottom; attack, tower and objective rules are identical.
- Gold cannot become negative, purchases cannot duplicate an owned item, a deck has exactly six distinct valid entries and equipment has at most three.
- Relay cannot be held by two heroes; carrying blocks movement abilities; only qualifying hits force drops; delivery works for either player; drop/expiry timers clean up state.
- Relay success does not apply permanent combat stats, and one player can win through a lane trade without ever delivering a Relay.
- Structures are invulnerable until their preceding structure falls. Minions do not attack friendly units. Match ends reliably on Core destruction.
- Collect at least 30–50 bot or local test matches before changing the 3-slot cap, gold rates, or Relay reward based on intuition alone.

## 14. Open balance hypotheses (do not silently hard-code as doctrine)
- Is two hits in 3 seconds the right carrier drop threshold, or should it depend on effective damage and attack speed?
- Does the Relay provide enough value to contest, but not so much that declining is automatically wrong?
- Should players buy three of six, or eventually equip more?
- Does prioritizing heroes for default auto-targeting interfere with last-hitting despite tap-to-override? Try a last-hit target filter or a hold-to-focus-minions control only if testing shows it is needed.
- Does the stationary-attack cadence create deliberate decisions or excessive stutter-stepping? Tune minimum-stop time, animation cues and attack interval.

**Design north star:** The better fighter should not always be the better player. The match winner should emerge from micro, farming, timing, build choices and objective decisions together.
