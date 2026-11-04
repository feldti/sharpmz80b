#!/usr/bin/env bash
# mzterm.sh – minicom im MZ-80B-Font starten
#   ./mzterm.sh [geraet] [baud] [terminal]
#   terminal: konsole (Standard) | xterm | kitty | alacritty
DEV=${1:-/dev/ttyUSB0}
BAUD=${2:-115200}
TERM_APP=${3:-konsole}
PX=16          # Pixelgröße: Vielfache von 8 (16, 24, 32) bleiben scharf
PT=12          # dasselbe in Punkt bei 96 dpi (16 px = 12 pt)

# -R CP437: minicom macht aus jedem Byte 0x80-0xFF ein eigenes Unicode-Zeichen,
# der Font "MZ80B Raw" zeigt dort die passende MZ-Glyphe.
FONT="MZ80B Raw"
CMD=(minicom -D "$DEV" -b "$BAUD" -w -R CP437)

case "$TERM_APP" in
  konsole)
    exec konsole --separate --profile MZ80B -e "${CMD[@]}" ;;
  xterm)
    exec xterm -fa "$FONT" -fs "$PT" -geometry 80x25 -bg black -fg '#5aff78' \
         -xrm 'XTerm*forceBoxChars: false' -e "${CMD[@]}" ;;
  kitty)
    exec kitty -o font_family="$FONT" -o font_size="$PT" -o modify_font='cell_height 100%' \
         -o foreground='#5aff78' -o background=black "${CMD[@]}" ;;
  alacritty)
    exec alacritty -o "font.normal.family=\"$FONT\"" -o font.size="$PT" \
         -o 'colors.primary.foreground="#5aff78"' -o 'colors.primary.background="#000000"' \
         -e "${CMD[@]}" ;;
  *) echo "Unbekanntes Terminal: $TERM_APP" >&2; exit 1 ;;
esac
