# Main menu steam footage

`main_menu_steam.ogv` is a silent 22-second locomotive departure excerpt from
**The Great Train Robbery (1903)**, directed by Edwin S. Porter, Edison
Manufacturing Company. Source scan: Library of Congress, Motion Picture,
Broadcasting, and Recorded Sound Division; distributed through Wikimedia Commons.

- [Library of Congress catalog](https://www.loc.gov/item/00694220/)
- [Source file and public-domain declaration](https://commons.wikimedia.org/wiki/File:The_Great_Train_Robbery_(1903).webm)
- [Public Domain Mark](https://creativecommons.org/publicdomain/mark/1.0/)

The Commons file declares the film public domain in the US and in countries
with copyright terms of the author's life plus 80 years or less (Porter died
in 1941). No modern soundtrack is included. Retrieved 7 October 2026.

Download used:

```text
https://upload.wikimedia.org/wikipedia/commons/transcoded/d/d7/The_Great_Train_Robbery_%281903%29.webm/The_Great_Train_Robbery_%281903%29.webm.480p.vp9.webm
```

Conversion (source timings 07:46–08:08):

```sh
ffmpeg -ss 466 -i source.webm -t 22 -an \
  -vf 'fps=24,format=yuv420p' -c:v libtheora -q:v 6 main_menu_steam.ogv
```

The player loops locally, muted, beneath the menu artwork. The 4:3 film is
scaled uniformly and cropped by the 16:9 menu canvas; the original artwork's
black bars are drawn above it. The existing menu music remains separate.
The scene directly references the video, so scene-based Web exports include it.
`main_menu_steam_poster.jpg` is the same excerpt's first frame, displayed beneath
the player while its decoder starts.
