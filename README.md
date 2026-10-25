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
| Abilities (unlock at Lv 1 / 3 / 5), press again for a follow-up | Q / E / R | Right-thumb buttons |
| Pick a level-up perk | Z / X | Tap a perk card |
| Buy item card | 1–8 | Tap a card |
| Sell an owned item (half price back) | Its number twice | Tap its card twice |
| Make an owned item a Masterwork (Lv 6, at the shop) | C / V / B | Tap a Masterwork button |
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

**Levels:** most XP comes from enemy minions dying near you (same rule as gold), then
knockouts, with a small trickle over time, so a trip back to shop costs XP as well as gold.
Level 1, 3 and 5 unlock your abilities (5 is the ultimate); at 2, 4 and 6 you
pick one of two perks (Z / X or tap a card; after 12 s the first one is taken for you).
Falling behind in level earns you bonus XP. Expect Lv3 around 1:30, Lv5 around 3:30 and
Lv6 around 5:30.

**Power spikes:**
- **Level-up surge:** every level-up heals 15% of your max HP and gives +30% attack
  speed for 3 seconds, so fight right as you level. A gold ring marks every level-up.
- **Ult race:** the first hero to reach Lv5 gets a column of light and a callout. Play
  around the enemy's Lv5.
- **Push, then shop:** when you can afford a card away from the shop, your gold pulses
  and says "Shop!". Push your wave into their tower, then head back.
- **Enemy spikes:** when the enemy finishes a mid or late item or a Masterwork, their name
  and items pulse with a callout. Their XP bar sits under their health.
- **Item looks:** a mid item makes your weapon glow, and a late item adds armor or
  clothing (Avery's pauldrons and cape, Jose's poncho, Jack's top hat and cape).
- **Masterwork (Lv6 gold sink):** at the shop, pay half an owned item's price to make it a
  Masterwork with +25% to its stats and effects. A gold gem floats over your head.

**Heroes** (all move at the same speed):

- **Avery**, the beginner paladin: a slow, hard, long-reach slash. *Cleave* heals her for
  every trooper and hero it hits, *Oath* shields and speeds her up, and the *Judgment Blade*
  skillshot stuns the enemy hero and pulls it to her.
- **Jose**, the gunslinger: fragile, and his basic attacks grow 8% per level. *Spin Dash*
  dashes and fires a volley; if the volley hits, press again for a second dash. *Sweet
  Talk* charges while you hold the shot (tap, then tap again to fire). *Last Tango*: he
  dances slowly with gunfire all around him. He moonwalks when he sprints.
- **Jack**, the skill hero: *Cloak Toss* cuts through everything in a line; press again to
  teleport to the cloak. *Vanish* makes him immune and very slow; press again to burst
  out (teleporting to the cloak while vanished bursts there). *Encore Performance* casts
  the enemy hero's ultimate, on Jack's own cooldown.

Skillshots (Judgment Blade, Sweet Talk, Cloak Toss) fly toward where the target was, so
they can be dodged; walls stop them.

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
