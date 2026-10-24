# Castle Combat

A portrait, real-time 1v1 single-lane MOBA prototype in Godot. You stop to attack, every
fired basic attack lands, and matches are won through waves, towers and the Relay
objective as much as through the duel. Working title; the design doc calls it
UNDERTOW: RELAY ([docs/GDD_v0.1.md](docs/GDD_v0.1.md)).

**Status: Milestone 0** — a 3D graybox you can walk around. Combat starts in M1.

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
| Ability / Ultimate | Q / E | Right-thumb buttons (M1) |
| Buy item card | 1–6 | Tap a card (M3) |
| Drop the Relay | F | Button while carrying (M2) |
| Swap seat (debug) | F2 | Seat button |
| Touch mode (mouse drives the joystick) | F3 | Touch button |
| Debug readout | F1 | Debug button |
| Back to hero select | Esc | Menu button |

There is no attack button on purpose: standing still is how you attack.

## Developing

```sh
godot --headless --path . --import                 # first time, builds the class cache
godot --headless --path . -s tests/run_tests.gd    # rule tests, exit code 1 on failure
godot --path . -- --autoplay                       # skip the menu
godot --path . -- --autoplay --seat=red --touch --walk-up --screenshot=shot.png --frames=120
```

CI (`.github/workflows/build.yml`) runs the tests, a smoke run, and exports Windows + web
on every push and pull request.

See [DEV_NOTES.md](DEV_NOTES.md) for architecture, assumptions and the backlog.
