# Title-screen music — October 2026 alpha

The four tracks and vinyl bed were supplied by the user from Downloads on
7 October 2026. Original WAVs are preserved without modification in
`assets/_reference/audio/title_menu/`, outside Godot's import/export scan.
`sources.json` records their SHA-256 hashes and the conversion gains.

One of `track_1.ogg` through `track_4.ogg` is selected uniformly at random on
the first title-screen visit of each app launch. It loops for that session;
returning from gameplay restarts the same selection. A fresh launch (or Web
page reload) makes a new pick, which may naturally be the same track.

`vinyl.ogg` loops independently underneath the song. Both scene-owned players
use the Music bus at -8 dB, follow the profile's Music volume, and stop when
leaving the menu. These tracks do not enter the gameplay playlist.

Runtime copies use Ogg Vorbis quality 5 at the source 48 kHz stereo format.
Constant gains of 0, +6, +5.5 and +8.8 dB respectively bring the four songs to
approximately -22 dBFS mean level while preserving their dynamics. The vinyl
bed keeps its original level (approximately -52.4 dBFS mean, with louder
individual crackles). No trimming, time stretching or soundtrack replacement
was applied.

Reproduction, substituting the gain and filenames from `sources.json`:

```sh
ffmpeg -i Track_2.wav -map_metadata -1 -af volume=6dB \
  -c:a libvorbis -q:a 5 track_2.ogg
```

Project note from the supplied conversation: these are temporary alpha/demo
selections intended to be replaced by original songs if the project develops
further. Track titles, artists and licensing details were not supplied.
