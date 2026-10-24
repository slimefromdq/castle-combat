# Castle Combat

A portrait, real-time 1v1 single-lane MOBA prototype in Godot. You stop to attack, every
fired basic attack lands, and matches are won through waves, towers and the Relay
objective as much as through the duel. Working title; the design doc calls it
UNDERTOW: RELAY ([docs/GDD_v0.1.md](docs/GDD_v0.1.md)).

**Status: Milestone 3** — a full match against a bot with waves, towers, stop-to-attack
combat, hero-hit aggro, the Relay (pick it up, carry it across, deliver it for a siege
minion), and gold with a six-card item deck you pick before the match (buy up to three).

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
| Ability / Ultimate | Q / E (later milestone) | Right-thumb buttons |
| Buy item card | 1–6 | Tap a card |
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
