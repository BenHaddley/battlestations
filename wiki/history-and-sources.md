# History and Sources

[Wiki home](README.md)

## Evidence hierarchy

1. Active Godot code and scenes — best evidence of current behavior.
2. Archived Unity code, scenes, and assets — best evidence of the earlier prototype.
3. Contemporary collaborator messages — evidence of intent and project history.
4. Filenames and visual interpretation — useful clues, but not confirmed design.
5. Roadmap ideas — proposals only.

## Timeline

| Date | Event | Confidence |
|---|---|---|
| 2023-12-16 | A Google Sheet titled “battle stations unit concepts” was shared. Its visible preview included Steam, Diesel, Electric, and Oil engines. | Documented |
| 2023-12-18 | A dormant Twitter/X account was being repurposed for the game. | Documented |
| 2024-01-02 | The game files were said to be on an old PC; more concept work was underway. | Documented |
| 2024-02-02 | A collaborator planned a level theme and replacement Spider art after gameplay existed. Existing music was described as a banjo placeholder. | Documented |
| 2024-02-12 | Moving trains on rails was an active development goal. | Documented |
| 2024-03-07 | Alternatives to Unity were discussed. This is the last known mention in the searched DM. | Documented |
| Repository history | The Unity project was snapshotted, then scaffolded into Godot 4. | Implemented/archived |

## Lost concept sheet

The deleted sheet used columns `UNIT`, `COST`, `CLASS`, `RANGE`, and `WHAT DO?`. The
Discord preview preserved these entries:

| Unit | Cost | Preserved description |
|---|---:|---|
| Steam Engine | 300 | Carries up to 5 cars |
| Diesel Engine | 375 | Slower; carries up to 7 cars |
| Electric Engine | 250 | Faster; carries up to 3 cars |
| Oil Engine | 350 | Description cut off in preview |

These concepts imply a train-and-car system that is absent from both the active
Godot scaffold and the recovered gameplay scripts. They should not be silently
reinterpreted as stationary tower stats.

The original Google Sheets URL now returns a deleted-file message. It is retained in
the raw notes for identification, but not repeated here as a usable reference.

## Leads worth recovering

- Gubgub's separate Discord server had a `battle stations` channel and is the most
  likely location for concept posts or missing assets.
- The old PC mentioned in January 2024 may contain a fuller or later project copy.
- The repurposed Twitter/X account may preserve a public name, branding, or post.
- The ownership and intended status of `Train 45.mp3` need confirmation.

## Raw and archived sources

- [Discord conversation research](../discord-gubgub-notes.md) — search scope,
  excerpts, broken link, and caveats.
- [`legacy_unity/`](../legacy_unity/) — original Unity snapshot.
- [`scripts/`](../scripts/) and [`scenes/`](../scenes/) — active implementation.

When new information is recovered, retain its source, date, author if known, and any
limitations. Summaries belong here; long transcripts and exports should go in a
dedicated `wiki/sources/` subdirectory.
