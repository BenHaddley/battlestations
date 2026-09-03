# Gubgub playtest and design notes — 2026-08-28–29

[Wiki home](../README.md) · [History and sources](../history-and-sources.md)

## Provenance

- Source: Discord conversation supplied directly by TheRealBen on 2026-08-29.
- Participants: Gubgub and TheRealBen.
- The supplied export used relative timestamps: “Yesterday” for the 2:11–2:32 PM
  messages and clock times for the 5:30–6:39 AM messages. The dates above therefore
  assume the repository session date of 2026-08-29 in Pacific/Auckland.
- This is a lightly edited transcription: HTML whitespace artifacts and unrelated
  banter have been omitted, while the design meaning is retained.
- Confidence: **Documented** design intent and playtest feedback. None of the future
  mechanics below should be described as implemented without corresponding code.

## Playtest feedback

Gubgub reported that the expanded engine control panel obscured the bottom of the
board, making it difficult to watch spiders reaching the station while driving a
train. They suggested condensing engine control to keyboard input: Up increases
forward speed and Down applies reverse movement.

Engine speed and stopping also need retuning. Manual control is intended primarily
to make an engine run faster than its normal default speed. Engines probably should
not stop completely, only slow substantially; otherwise the player can park a train
in one strong position and reduce the game to a train-themed static lane defense.
Gubgub noted that the wider positional problem may still need a more specific design
solution.

Spider kill rewards were judged too generous. Large waves currently inflate the
Delta economy until car costs become inconsequential. Kill bounty should fall and
the player should depend more on Passenger Coach income.

The spider death effects were specifically praised for adding impact and “pop.”
Gubgub felt the game was visibly taking shape and expressed excitement about its
direction.

## Confirmed future direction

- Engines should be individually placeable rail units. The player would receive one
  engine at the beginning of a level, then buy and manage additional engines during
  play.
- Conventional armed cars are being redesigned to fire in only one fixed direction,
  rather than using swivelling turrets. This is intended to make engine movement and
  positioning strategically necessary. Updated drawings are still pending, so the
  current art and implementation should remain for now.
- Ordinary trains do not run over spiders. At normal train speed, a threatened spider
  moves one tile backward or sideways before impact.
- A separate future engine concept may carry only one car but move fast enough to
  damage spiders by ramming them. Its art does not yet exist.
- A future Barrier Car is a heavy, two-tile-long divider that acts as a wall. When a
  train blocks a spider and no route around it exists within three blocks, the spider
  bites the train. Sustained biting can destroy individual cars.
- Players should eventually be able to add rails and expand the railway between
  waves. Gubgub explicitly deferred this feature until later.

## Deferred content and art

Gubgub considers the current shooting-unit designs outdated and plans to redraw them
for fixed-direction weapons. They were also redrawing the Steam Engine with updated
colors at the time of the conversation.

A collection gallery is planned for discovered units: entries fill in as the player
encounters units and contain a name plus a short description. Gubgub will supply the
assets, names, and descriptions; implementation should wait until those assets are
finished.
