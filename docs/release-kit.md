# Battle Stations release kit

This draft supplies the text portions of the release package. Art capture and legal
sign-off remain release gates; see [asset provenance](../wiki/asset-provenance.md).

## Short description

Build a moving defense on rails. Couple armed, economy, and support cars to roaming
steam engines, manage their speed and direction, and stop specialist spiders from
overrunning the station.

## Store description

Battle Stations is a single-player railway lane-defense game where your towers never
stand still. Start with one locomotive, attach specialized cars, and reshape coverage
by accelerating, slowing, and reversing trains around authored rail circuits.

Seven campaign stops introduce new spider roles, railways, and train cars. Complete
the route to unlock endless Open Rails, or play rule-changing Challenge cards—including
commanding the swarm in Spider Assault.

## Controls

| Action | Keyboard/mouse |
|---|---|
| Buy a car | Drag its Train Yard row onto a valid train |
| Buy an engine | Drag Locomotive onto an empty rail stretch |
| Select a train | Left-click its locomotive |
| Boost selected train | Hold Up Arrow |
| Slow selected train | Hold Down Arrow briefly |
| Reverse selected train | Continue holding Down Arrow |
| Select a car | Left-click an attached car |
| Remove a car | Choose Remove Unit, then click the car |
| Start wave early | Click Skip Wait |
| Pause/settings | Pause control or Escape |
| Game speed | Toggle 1×/2× control |

## Known issues and release gates

- Art, music, recorded SFX, and one font are not yet rights-cleared.
- Armed cars still swivel while fixed-direction redraws and rules remain pending.
- Between-wave rail construction and Barrier Car mechanics are deferred.
- Browser autoplay may require the player's first interaction.
- Late-wave browser performance and fresh-player balance still need recorded tests.

For a CPU-only local stress probe, run:

```sh
godot --headless --path . tests/LateWaveProfile.tscn
```

Baseline on 2026-08-31 (Godot 4.7.2, local Linux headless build): 225 active spiders
simulated at **0.265 ms/frame** across 120 frames. This indicates pooling is not
currently justified by CPU movement cost alone; repeat in the release Web build with
rendering and audio before closing the performance gate.

## Capture list

Current rendered captures:
[campaign gameplay](screenshots/gameplay.png),
[active combat](screenshots/combat.png),
[Game Over](screenshots/game-over.png),
[pause/settings](screenshots/pause-settings.png), and
[Spider Assault](screenshots/spider-assault.png),
[title screen](screenshots/title.png),
[Open Rails](screenshots/open-rails.png), and the
[gameplay loop GIF](screenshots/gameplay-loop.gif). A silent, rights-safe
[14-second trailer preview](screenshots/trailer-preview.mp4) combines the title,
campaign action, Spider Assault, and Game Over presentation.

- [x] Title screen at 1280×720.
- [x] Campaign gameplay and multi-route board at 1280×720.
- [ ] Train Yard drag preview and valid attachment highlight.
- [ ] Coal Cannon or Ballast group hit with spider death feedback.
- [x] GAME OVER dim-and-fade presentation.
- [x] Pause/settings presentation.
- [x] Spider Assault challenge layout.
- [x] Active spiders in a combat frame.
- [x] Open Rails screen.
- [x] Short gameplay loop GIF.
- [x] Silent trailer preview: title, campaign action, Spider Assault, and Game Over.
