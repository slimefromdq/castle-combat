# Castle Combat

A portrait, real-time 1v1 single-lane MOBA prototype in Godot. You stop to attack, every
fired basic attack lands, and matches are won through waves, towers and the Relay
objective as much as through the duel. Working title; the design doc calls it
UNDERTOW: RELAY ([docs/GDD_v0.1.md](docs/GDD_v0.1.md)).

**Status: Milestone 4** — a full match against a bot with waves, towers, stop-to-attack
combat, hero-hit aggro, the Relay (pick it up, carry it across, deliver it for a siege
minion), gold with an eight-card item deck you pick before the match (own up to three, sell
for half to make room), and
six hero levels that unlock three abilities and three perks.

## Play it

- **Browser:** every merge to `main` publishes the web build to GitHub Pages
  (`https://slimefromdq.github.io/castle-combat/`). Works on desktop and in Safari on iPhone.
- **Windows:** open the latest run under the repo's **Actions** tab and download the
  `CastleCombat-windows` artifact. Unzip and run `CastleCombat.exe`.
- **From source:** install [Godot 4.7.2](https://github.com/godotengine/godot/releases/tag/4.7.2-stable),
  open `project.godot`, press F5.

## Controls

| Action | Desktop | Phone (or touch mode on desktop) |
| --- | --- | --- |
| Move | WASD / arrow keys | Floating joystick: drag in the lower left |
| Attack | Stand still: the nearest valid target is attacked automatically | Same |
| Focus a target (for last hits) | Left-click an enemy unit; click the ground to clear | Tap an enemy unit |
| Abilities (unlock at Lv 1 / 3 / 5) | Q / E / R | Right-thumb buttons |
| Buy item card | 1–8 | Tap a card |
| Sell an owned item (half price back) | Its number twice | Tap its card twice |
| Hide / show the item cards | Tab | — |
| Pick up / deliver the Relay | Stand in the gold ring / the outlined pocket | Same |
| Drop the Relay | F | Drop button while carrying |
| Swap seat (debug) | F2 | Seat button |
| Touch mode (mouse drives the joystick) | F3 | Touch button |
| Debug readout | F1 | Debug button |
| Back to hero select | Esc | Menu button |

There is no attack button on purpose: standing still is how you attack.

**Gold:** any enemy minion that dies inside the faint gold circle around you pays you its
gold, whoever killed it. A killing blow from farther away pays too.
**Denies:** once one of your own minions drops to half health its bar gets a white frame;
tap it and stand still to finish it yourself: the enemy only collects half its gold, and
you get a share too.

**Sprint:** keep moving in roughly one direction, out of combat, for 3.5 seconds and your hero breaks into a sprint (45% faster, with a speed trail). Stopping, turning sharply, casting, carrying the Relay or taking damage ends it.
**Camera:** it follows you but stops at the ends of the map.
**Shopping:** buy and sell only near your front tower or at your base.

**Items:** sixteen items in three tiers. Early items (300–400) help in lane, mid items
(900–1,100) answer the enemy (anti-heal, ability resist, damage that hurts tanks) or push
your plan, and late items (2,000–2,400) change how fights go. Your deck holds eight, you own
at most three at once, and selling an early item is how you make room for a late one.

**Levels:** you earn XP over time, from enemy minions (same rule as gold) and from
knockouts. Level 1, 3 and 5 unlock your abilities (5 is the ultimate); 2, 4 and 6 give
perks. Falling behind in level earns you bonus XP.

**Matches speed up.** Gold and Relay rewards grow over time; towers start tough and get
weaker; each base has a **Guardian** whose beam grows the longer it focuses one target, and
which stomps at 66% and 33% health (walk out of the red ring, then hit it while it
recovers). A structure can't be hit until the one in front of it falls, and troopers
always go for structures first. Heal on the green pad behind your Core; it shuts off
once your Guardian falls. Killing a Guardian powers up your minions for good. Respawns get longer as the
match goes on, and at 10:00 overtime weakens every structure.

**Watch your aggro.** Hitting the enemy hero calls their nearby minions onto you, and if
you stand inside their tower's range the tower switches to you too and hits harder. A "!"
over a minion or tower means it has been called (red = coming for you). Tap a minion to
farm next to their hero without starting a fight.

## Developing

```sh
godot --headless --path . --import                 # first time, builds the class cache
godot --headless --path . -s tests/run_tests.gd    # rule tests, exit code 1 on failure
godot --path . -- --autoplay                       # skip the menu
godot --path . -- --autoplay --seat=red --touch --walk-up --screenshot=shot.png --frames=120
godot --path . -- --autoplay --autopilot --skip=90   # the bot plays you, 90 s into the match
godot --headless --path . -s tests/run_tests.gd -- combat   # one suite
```

CI (`.github/workflows/build.yml`) runs the tests, a smoke run, and exports Windows + web
on every push and pull request.

See [DEV_NOTES.md](DEV_NOTES.md) for architecture, assumptions and the backlog.
