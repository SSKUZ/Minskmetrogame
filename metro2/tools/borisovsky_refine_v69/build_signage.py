"""Station-local navigation artwork, redrawn from owner photo 6728.

The direction is the destination, independent of the face used to view a board.
Wall signs have a transparent outline; overhead signs retain their framed panel.
Only these four SVG assets are written. No Godot import or export is performed.
"""
from pathlib import Path
import math
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen

OUT = Path(__file__).resolve().parents[2] / 'modules/stations/borisovsky_trakt/art_v69'
FONT = TTFont('/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf')
GLYPHS = FONT.getGlyphSet()
CMAP = FONT.getBestCmap()
UPEM = FONT['head'].unitsPerEm
STATIONS = [
    ('УРУЧЧА', 'УРУЧЬЕ', '124'),
    ('БАРЫСАЎСКІ ТРАКТ', 'БОРИСОВСКИЙ ТРАКТ', '123'),
    ('УСХОД', 'ВОСТОК', '122'),
    ('МАСКОЎСКАЯ', 'МОСКОВСКАЯ', '121'),
    ('ПАРК ЧАЛЮСКІНЦАЎ', 'ПАРК ЧЕЛЮСКИНЦЕВ', '120'),
    ('АКАДЭМІЯ НАВУК', 'АКАДЕМИЯ НАУК', '119'),
    ('ПЛОШЧА ЯКУБА КОЛАСА', 'ПЛОЩАДЬ ЯКУБА КОЛАСА', '118'),
    ('ПЛОШЧА ПЕРАМОГІ', 'ПЛОЩАДЬ ПОБЕДЫ', '117'),
    ('КАСТРЫЧНІЦКАЯ', 'ОКТЯБРЬСКАЯ', '116'),
    ('ПЛОШЧА ЛЕНІНА', 'ПЛОЩАДЬ ЛЕНИНА', '115'),
    ('ІНСТЫТУТ КУЛЬТУРЫ', 'ИНСТИТУТ КУЛЬТУРЫ', '114'),
    ('ГРУШАЎКА', 'ГРУШЕВКА', '113'),
    ('МІХАЛОВА', 'МИХАЛОВО', '112'),
    ('ПЯТРОЎШЧЫНА', 'ПЕТРОВЩИНА', '111'),
    ('МАЛІНАЎКА', 'МАЛИНОВКА', '110'),
]
BLUE, GREY, YELLOW = '#343879', '#9b9d9f', '#edb735'
CREAM, INK = '#f2f1e7', '#242632'
W, H = 2325, 480
PITCH, BAND_HEIGHT = 130, 290
ANGLE = math.radians(50)
SKEW = BAND_HEIGHT / math.tan(ANGLE)


def width(value, size):
    return sum(GLYPHS[CMAP[ord(c)]].width for c in value) * size / UPEM


def text(value, x, y, size, fill=CREAM):
    result = []
    for char in value:
        glyph = GLYPHS[CMAP[ord(char)]]
        pen = SVGPathPen(GLYPHS)
        glyph.draw(pen)
        if pen.getCommands():
            result.append(f'<path transform="translate({x:.3f} {y:.3f}) '
                          f'scale({size/UPEM:.7f} {-size/UPEM:.7f})" '
                          f'd="{pen.getCommands()}" fill="{fill}"/>')
        x += glyph.width * size / UPEM
    return ''.join(result)


def centred(value, x, y, size, fill=CREAM):
    return text(value, x - width(value, size)/2, y, size, fill)


def palette(station_index, toward_uruchye):
    if station_index == 1:
        return YELLOW, INK
    ahead = station_index < 1 if toward_uruchye else station_index > 1
    return (BLUE, CREAM) if ahead else (GREY, CREAM)


def diagram(filename, toward_uruchye, wall=False):
    # Every diagonal ends on the SAME two horizontal baselines. The old rotated
    # rectangles overlapped and left a sawtooth edge instead of parallel lanes.
    top = 22 if wall else 66
    bottom = top + BAND_HEIGHT
    axis = bottom + 25
    indices = list(range(14, -1, -1)) if toward_uruchye else list(range(15))
    body = []
    if not wall:
        body.append(f'<rect width="{W}" height="{H}" fill="{CREAM}"/>')
        body.append(f'<rect x="12" y="12" width="{W-24}" height="42" fill="{BLUE}"/>')
        body.append(centred('ДА СТАНЦЫЙ    К СТАНЦИЯМ', W/2, 42, 30))
        for x in [38, W-78]:
            body.append(f'<path d="M{x} 22l12 11-12 11m17-22l12 11-12 11" '
                        f'fill="none" stroke="{YELLOW}" stroke-width="5"/>')
    for slot, index in enumerate(indices):
        be, ru, code = STATIONS[index]
        fill, foreground = palette(index, toward_uruchye)
        x = 20 + slot*PITCH
        points = (f'{x+SKEW:.3f},{top} {x+PITCH+SKEW:.3f},{top} '
                  f'{x+PITCH},{bottom} {x},{bottom}')
        body.append(f'<g id="station-{code}" data-state="'
                    f'{"current" if index==1 else "ahead" if fill==BLUE else "passed"}">')
        body.append(f'<polygon points="{points}" fill="{fill}" '
                    f'stroke="{CREAM}" stroke-width="3"/>')
        # Fitted bilingual outlines share the 50-degree lane angle. The normal
        # offsets leave a full line of clearance at each parallel boundary.
        size = min(26, 285/max(width(be, 1), width(ru, 1)))
        tx = x + 23/math.tan(ANGLE) + 0.8*size/math.sin(ANGLE) + 12
        body.append(f'<g transform="translate({tx:.3f} {bottom-23}) rotate(-50)">')
        body.append(text(be, 0, 0, size, foreground))
        body.append(text(ru, 0, 29, size*.94, foreground))
        body.append('</g>')
        cx = x+PITCH/2
        if slot < len(indices)-1:
            next_fill, _ = palette(indices[slot+1], toward_uruchye)
            line_fill = BLUE if fill in [BLUE, YELLOW] and next_fill in [BLUE, YELLOW] else GREY
            body.append(f'<path d="M{cx+18} {axis}h{PITCH-36}" stroke="{line_fill}" stroke-width="5"/>')
        body.append(f'<path d="M{cx} {bottom}v{axis-bottom-18}" stroke="{fill}" stroke-width="4"/>')
        body.append(f'<circle cx="{cx}" cy="{axis}" r="18" fill="{fill}" stroke="{CREAM}" stroke-width="2"/>')
        body.append(centred(code, cx, axis+6, 17, foreground))
        # Local interchange identifiers, as on the supplied platform photograph.
        if index in [8, 9]:
            transfer_colour = '#aa3446' if index==8 else '#138477'
            transfer_code = '216' if index==8 else '314'
            if fill == GREY:
                transfer_colour = GREY
            body.append(f'<path d="M{cx} {axis+18}v7" stroke="{transfer_colour}" stroke-width="4"/>')
            body.append(f'<circle cx="{cx}" cy="{axis+43}" r="18" fill="{transfer_colour}" stroke="{CREAM}" stroke-width="2"/>')
            body.append(centred(transfer_code, cx, axis+49, 17))
        body.append('</g>')
    if not wall:
        track = '1' if toward_uruchye else '2'
        body.append(f'<path d="M{W-115} {H-12}l103-117v117Z" fill="{YELLOW}"/>')
        body.append(f'<circle cx="{W-50}" cy="{H-74}" r="27" fill="{BLUE}"/>')
        body.append(centred(track, W-50, H-63, 34))
        body.append(centred('ПУЦЬ', W-49, H-28, 14, INK))
        body.append(centred('ПУТЬ', W-49, H-12, 14, INK))
    # Wall art has no rectangular backdrop/header: only the shaped lane strip,
    # common number baseline and small interchange circles appear on marble.
    height = 423 if wall else H
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT/filename).write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{height}" '
        f'viewBox="0 0 {W} {height}">' + ''.join(body) + '</svg>\n')


def build_signage():
    diagram('direction_1.svg', True)
    diagram('direction_2.svg', False)
    diagram('wall_toward_uruchye.svg', True, wall=True)
    diagram('wall_toward_malinovka.svg', False, wall=True)


if __name__ == '__main__':
    build_signage()
