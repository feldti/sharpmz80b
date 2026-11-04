import sys, struct, os
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

rom = open(sys.argv[1], 'rb').read()
out = sys.argv[2]
RAW = len(sys.argv) > 3 and sys.argv[3] == 'raw'
# raw: Bytes 0x80-0xFF liegen auf den Unicode-Zeichen, die CP437 daraus macht.
# Gedacht für "minicom -R CP437": jedes Byte vom MZ erscheint als seine ROM-Glyphe.
NAME = "MZ80B Raw" if RAW else "MZ80B"
FILE = NAME.replace(' ', '')

# Byte -> Unicode-Zuordnung (zusätzlich hat jedes Byte b immer U+E000+b)
extra = {
    0x01: 0x21E9, 0x02: 0x21E7, 0x03: 0x21E8, 0x04: 0x21E6,
    0x1F: 0x2592, 0x7F: 0x21B4,
    0x80: 0x2016, 0x81: 0x2193, 0x82: 0x2191, 0x83: 0x2192, 0x84: 0x2190,
    0x85: 0x2660, 0x86: 0x2665, 0x87: 0x2666, 0x88: 0x2663,
    0x89: 0x251D, 0x8A: 0x2525, 0x8B: 0x2565, 0x8C: 0x2568,
    0x8E: 0x253F, 0x8F: 0x256B, 0x90: 0x2501,
    0x91: 0x00A5, 0x92: 0x00A3, 0x93: 0x25CF, 0x94: 0x25CB,
    0x95: 0x2510, 0x96: 0x2518, 0x97: 0x250C, 0x98: 0x2514, 0x99: 0x253C,
    0x9A: 0x2502, 0x9B: 0x2500, 0x9C: 0x2534, 0x9D: 0x252C, 0x9E: 0x2524, 0x9F: 0x251C,
    0xA0: 0x2588, 0xFF: 0x03C0,
}
cps = {}  # byte -> list of codepoints
for b in range(256):
    l = []
    if 0x20 <= b <= 0x7E: l.append(b)
    if RAW:
        if b >= 0x80: l.append(ord(bytes([b]).decode('cp437')))
    elif b in extra: l.append(extra[b])
    l.append(0xE000 + b)
    cps[b] = l

def rows(b): return rom[b*8:b*8+8]

# ---------- TTF ----------
PX = 128; UPM = 1024; ASC = 7*PX; DESC = PX
gnames = ['.notdef'] + ['mz%02X' % b for b in range(256)]
cmap = {}
for b in range(256):
    for c in cps[b]: cmap[c] = 'mz%02X' % b
glyphs = {}
pen = TTGlyphPen(None); glyphs['.notdef'] = pen.glyph()
for b in range(256):
    pen = TTGlyphPen(None)
    r = rows(b)
    for y in range(8):
        x = 0
        while x < 8:
            if r[y] & (0x80 >> x):
                x0 = x
                while x < 8 and r[y] & (0x80 >> x): x += 1
                top = ASC - y*PX; bot = top - PX
                pen.moveTo((x0*PX, bot)); pen.lineTo((x0*PX, top))
                pen.lineTo((x*PX, top)); pen.lineTo((x*PX, bot)); pen.closePath()
            else:
                x += 1
    glyphs['mz%02X' % b] = pen.glyph()
fb = FontBuilder(UPM, isTTF=True)
fb.setupGlyphOrder(gnames)
fb.setupCharacterMap(cmap)
fb.setupGlyf(glyphs)
gt = fb.font['glyf']
for g in gnames: gt[g].recalcBounds(gt)
fb.setupHorizontalMetrics({g: (8*PX, getattr(gt[g], 'xMin', 0)) for g in gnames})
fb.setupHorizontalHeader(ascent=ASC, descent=-DESC)
fb.setupNameTable({"familyName": NAME, "styleName": "Regular",
                   "uniqueFontIdentifier": FILE + "-Regular", "fullName": NAME,
                   "psName": FILE + "-Regular", "version": "Version 1.0"})
fb.setupOS2(sTypoAscender=ASC, sTypoDescender=-DESC, sTypoLineGap=0,
            usWinAscent=ASC, usWinDescent=DESC, xAvgCharWidth=8*PX,
            panose=dict(bFamilyType=2,bSerifStyle=0,bWeight=5,bProportion=9,bContrast=0,bStrokeVariation=0,bArmStyle=0,bLetterForm=0,bMidline=0,bXHeight=0))
fb.setupPost(isFixedPitch=1)
from fontTools.ttLib import newTable
from fontTools.ttLib.tables import ttProgram
prep = newTable('prep'); prep.program = ttProgram.Program()
prep.program.fromAssembly(['SVTCA[0]'])
fb.font['prep'] = prep
fb.font['head'].flags |= (1 << 3)
gasp = newTable('gasp'); gasp.gaspRange = {0xFFFF: 0x0001}  # nur Gridfit, kein Smoothing
fb.font['gasp'] = gasp
fb.save(os.path.join(out, FILE + ".ttf"))

# ---------- BDF (ISO10646) ----------
entries = sorted((c, b) for b in range(256) for c in cps[b])
with open(os.path.join(out, FILE + ".bdf"), 'w') as f:
    f.write("STARTFONT 2.1\nFONT -mz-%s-medium-r-normal--8-80-75-75-c-80-iso10646-1\n" % FILE.lower())
    f.write("SIZE 8 75 75\nFONTBOUNDINGBOX 8 8 0 -1\n")
    f.write("STARTPROPERTIES 6\nFONT_ASCENT 7\nFONT_DESCENT 1\nSPACING \"C\"\n"
            "CHARSET_REGISTRY \"ISO10646\"\nCHARSET_ENCODING \"1\"\nDEFAULT_CHAR 57344\nENDPROPERTIES\n")
    f.write("CHARS %d\n" % len(entries))
    for c, b in entries:
        f.write("STARTCHAR U+%04X\nENCODING %d\nSWIDTH 1000 0\nDWIDTH 8 0\nBBX 8 8 0 -1\nBITMAP\n" % (c, c))
        for v in rows(b): f.write("%02X\n" % v)
        f.write("ENDCHAR\n")
    f.write("ENDFONT\n")

# ---------- PSF2 für die Linux-Konsole (mit Unicode-Tabelle) ----------
with open(os.path.join(out, FILE + ".psf"), 'wb') as f:
    f.write(struct.pack('<IIIIIIII', 0x864ab572, 0, 32, 0x01, 256, 8, 8, 8))
    for b in range(256): f.write(rows(b))
    for b in range(256):
        for c in cps[b]: f.write(chr(c).encode('utf-8'))
        f.write(b'\xff')
