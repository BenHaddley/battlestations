# Browser smoke test

Run this checklist against a release Web export in two supported desktop browsers.
Record browser/version, operating system, date, tester, and any issue link.

Before the manual pass, run `tests/web_smoke.sh export/web`: it boots the exported
build in headless Chromium and fails if the level does not start with its railway and
train or if the console shows a script error (the exported build can lack files the
editor has — see [Current build](../wiki/current-build.md#running-the-project)).

## Launch and presentation

- [ ] The title screen loads without missing textures or console errors.
- [ ] Start, Continue (when available), and Challenge Mode respond to mouse and keyboard.
- [ ] The 1280×720 viewport scales without cropping the board or controls.
- [ ] Text and sprites remain readable at 100%, 125%, and 150% display scaling.

## Gameplay

- [ ] A car can be dragged from the Train Yard and attached to a valid train.
- [ ] An unaffordable or invalid placement does not spend Delta.
- [ ] A locomotive can be bought, placed on an empty route, selected, and driven.
- [ ] Up accelerates; a short Down press slows without stopping; holding Down reverses.
- [ ] Pause/resume and 2×/1× speed work without breaking timers or audio.
- [ ] Waves start, count down, spawn spiders, award kills, and advance normally.
- [ ] START WAVE is offered in every STATION window (including before wave two), is
      disabled during BATTLE, and cannot start a wave twice.
- [ ] Up/Down drive the train without moving the highlight through the Train Yard.
- [ ] During STATIONS, hovering a rail shows plus signs; laying a tile costs Δ50, a
      dead end shows the buffer stop, a join ring closes a detour, and right-click
      lifts a laid tile for a refund. Nothing of this is available during BATTLE.
- [ ] A spider steps into a clear neighbouring lane round a train and bites a unit
      when boxed in; the bitten unit shows its health bar and jaws marker.
- [ ] A destroyed car leaves the train with a debris burst; a wrecked engine shows
      the recover caption and a dropped locomotive puts it back into service.
- [ ] Dragging a gun shows its range ring at the coupling point; hovering a coupled
      car shows the same ring; a Passenger Coach shows none.
- [ ] Clicking an engine shows its weight/capacity tag and the readout at the top.
- [ ] Duck and Daisy objectives highlight the shop row or START WAVE button, and a
      fresh profile replays the opening lesson.
- [ ] Station defeat pauses play and fades in the supplied GAME OVER artwork.
- [ ] Restart and Main Menu work from the failure overlay.

## Browser services

- [ ] Music begins after the first user interaction if autoplay is initially blocked.
- [ ] Sound effects and music respect the browser/tab mute state.
- [ ] Campaign progress survives closing and reopening the tab.
- [ ] A new campaign replaces prior campaign progress as expected.
- [ ] Reloading during play returns to a valid title or level state.

## Sign-off

| Browser/version | OS | Date | Tester | Result/issues |
|---|---|---|---|---|
| | | | | |
| | | | | |
