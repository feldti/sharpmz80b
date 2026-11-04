# MZ-80B-Font für minicom

Erzeugt aus dem Original-CG-ROM (MZFONT.rom, 256 Zeichen à 8×8).

## Zwei Varianten
- **MZ80B Raw** (`MZ80BRaw.*`): für minicom. Zusammen mit `minicom -R CP437` erscheint
  jedes Byte 0x20–0xFF, das der Rechner sendet, als genau seine ROM-Glyphe: Grafikzeichen,
  Kartensymbole, Rahmen und die invertierten Zeichen 0xA0–0xFE.
- **MZ80B** (`MZ80B.*`): „normaler“ Font mit sinnvoller Unicode-Belegung (♠♥♦♣ ←↑→↓ ┌─┐ ¥ £ π …),
  zum Beispiel für Editor oder Doku.

Beide haben alle 256 ROM-Zeichen zusätzlich unter U+E000 + Code.

## Installation
    mkdir -p ~/.local/share/fonts ~/.local/share/konsole
    cp MZ80BRaw.ttf MZ80B.ttf ~/.local/share/fonts/ && fc-cache -f
    cp MZ80B.profile ~/.local/share/konsole/
    ./mzterm.sh /dev/ttyUSB0 9600            # Konsole
    ./mzterm.sh /dev/ttyUSB0 9600 xterm      # oder xterm / kitty / alacritty

Von Hand:  `minicom -D /dev/ttyUSB0 -b 9600 -R CP437` in einem Terminal mit Font „MZ80B Raw“.
Textkonsole (ohne X):  `setfont MZ80BRaw.psf && minicom -D /dev/ttyUSB0 -R CP437`

## Grenzen
- Steuercodes 0x00–0x1F und 0x7F zeigt kein Terminal als Zeichen an.
- `-R CP437` betrifft auch die Tastatur: Tippst du Zeichen außerhalb von ASCII, kommen sie als
  CP437-Bytes beim MZ an.
- Das Konsole-Profil setzt UseFontLineChararacters=true. Sonst zeichnet Konsole die
  Rahmenzeichen ┌─┐ selbst und die Inverszeichen 0xB3 usw. wären falsch.
