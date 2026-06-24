#!/usr/bin/env python3
"""Generate a 1024x1024 Distill app icon using only stdlib."""
import struct, zlib, math

SIZE = 1024

def make_png(pixels):
    def chunk(tag, data):
        c = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', c)

    raw = b''
    for row in pixels:
        raw += b'\x00' + bytes(row)

    ihdr = struct.pack('>IIBBBBB', SIZE, SIZE, 8, 2, 0, 0, 0)
    idat = zlib.compress(raw, 9)

    return (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', ihdr)
            + chunk(b'IDAT', idat)
            + chunk(b'IEND', b''))

def lerp(a, b, t):
    return a + (b - a) * t

def clamp(v, lo=0, hi=255):
    return max(lo, min(hi, int(v)))

def dist(x, y, cx, cy):
    return math.sqrt((x - cx)**2 + (y - cy)**2)

pixels = []

# Colors
BG_TOP    = (18, 12, 48)       # deep indigo
BG_BOT    = (38, 24, 82)       # mid indigo-purple
BOOK_DARK = (255, 255, 255)    # white book pages
SPINE     = (180, 140, 255)    # soft lavender spine
GLOW      = (200, 160, 255)    # glow color
DROP_COL  = (240, 210, 255)    # droplet / beam

cx, cy = SIZE // 2, SIZE // 2

for y in range(SIZE):
    row = []
    yf = y / SIZE
    for x in range(SIZE):
        xf = x / SIZE

        # Background gradient
        t = yf
        r = lerp(BG_TOP[0], BG_BOT[0], t)
        g = lerp(BG_TOP[1], BG_BOT[1], t)
        b = lerp(BG_TOP[2], BG_BOT[2], t)

        # Subtle radial vignette lift in center
        d = dist(x, y, cx, cy) / (SIZE * 0.7)
        lift = max(0, 1 - d) * 18
        r += lift; g += lift * 0.6; b += lift * 1.2

        # ── Open book ──────────────────────────────────────────
        # Book sits in lower-center, slightly raised
        book_cx = cx
        book_cy = int(SIZE * 0.56)
        bw = int(SIZE * 0.54)   # total width
        bh = int(SIZE * 0.32)   # height
        bx0 = book_cx - bw // 2
        bx1 = book_cx + bw // 2
        by0 = book_cy - bh // 2
        by1 = book_cy + bh // 2

        in_book = bx0 <= x <= bx1 and by0 <= y <= by1
        spine_w = int(SIZE * 0.025)

        if in_book:
            # Page gradient — left page
            if x < book_cx - spine_w:
                page_t = (x - bx0) / (book_cx - spine_w - bx0 + 1)
                pr = lerp(200, 248, page_t)
                pg = lerp(195, 243, page_t)
                pb = lerp(220, 255, page_t)
                # page lines
                line_y = (y - by0) % int(bh * 0.12)
                if line_y < max(2, int(bh * 0.015)):
                    pr *= 0.88; pg *= 0.88; pb *= 0.88
                r, g, b = pr, pg, pb

            # Spine
            elif abs(x - book_cx) <= spine_w:
                spine_t = (y - by0) / bh
                r = lerp(140, 180, spine_t)
                g = lerp(100, 130, spine_t)
                b = lerp(220, 255, spine_t)

            # Right page
            else:
                page_t = (bx1 - x) / (bx1 - (book_cx + spine_w) + 1)
                pr = lerp(200, 248, page_t)
                pg = lerp(195, 243, page_t)
                pb = lerp(220, 255, page_t)
                line_y = (y - by0) % int(bh * 0.12)
                if line_y < max(2, int(bh * 0.015)):
                    pr *= 0.88; pg *= 0.88; pb *= 0.88
                r, g, b = pr, pg, pb

            # Top curve of open book (subtle arc shadow at spine top)
            arc_y = by0 + int(bh * 0.08 * (1 - abs((x - book_cx) / (bw / 2)) ** 0.5))
            if y < arc_y:
                r *= 0.7; g *= 0.7; b *= 0.7

        # ── Droplet / beam rising from spine ───────────────────
        # Beam: thin vertical shimmer above book spine
        beam_x = book_cx
        beam_top = int(SIZE * 0.15)
        beam_bot = by0
        beam_w = int(SIZE * 0.018)

        if beam_top <= y <= beam_bot and abs(x - beam_x) <= beam_w:
            beam_t = 1 - (y - beam_top) / (beam_bot - beam_top + 1)
            alpha = beam_t ** 1.4
            edge = 1 - (abs(x - beam_x) / beam_w) ** 2
            alpha *= edge * 0.85
            r = lerp(r, DROP_COL[0], alpha)
            g = lerp(g, DROP_COL[1], alpha)
            b = lerp(b, DROP_COL[2], alpha)

        # Droplet shape above beam
        drop_cx = beam_x
        drop_cy = int(SIZE * 0.22)
        drop_r  = int(SIZE * 0.065)
        drop_tip = drop_cy - int(drop_r * 1.55)

        # Circle body of drop
        dd = dist(x, y, drop_cx, drop_cy)
        if dd <= drop_r:
            drop_t = 1 - (dd / drop_r) ** 2
            r = lerp(r, DROP_COL[0], drop_t * 0.95)
            g = lerp(g, DROP_COL[1], drop_t * 0.95)
            b = lerp(b, DROP_COL[2], drop_t * 0.95)

        # Triangle tip of drop
        if y <= drop_cy and y >= drop_tip:
            tip_t = (drop_cy - y) / (drop_cy - drop_tip + 1)
            half_w = drop_r * (1 - tip_t)
            if abs(x - drop_cx) <= half_w:
                alpha = (1 - tip_t) * 0.9
                r = lerp(r, DROP_COL[0], alpha)
                g = lerp(g, DROP_COL[1], alpha)
                b = lerp(b, DROP_COL[2], alpha)

        # Inner highlight on droplet
        hi_d = dist(x, y, drop_cx - int(drop_r*0.25), drop_cy - int(drop_r*0.3))
        if hi_d <= drop_r * 0.35:
            hi_t = (1 - hi_d / (drop_r * 0.35)) * 0.55
            r = lerp(r, 255, hi_t)
            g = lerp(g, 255, hi_t)
            b = lerp(b, 255, hi_t)

        # Soft glow around droplet
        glow_d = dist(x, y, drop_cx, drop_cy)
        if glow_d <= drop_r * 2.8:
            glow_t = (1 - glow_d / (drop_r * 2.8)) ** 2 * 0.22
            r = lerp(r, GLOW[0], glow_t)
            g = lerp(g, GLOW[1], glow_t)
            b = lerp(b, GLOW[2], glow_t)

        row += [clamp(r), clamp(g), clamp(b)]
    pixels.append(row)

out = "/Users/jtrant/Documents/Coding Projects/Distill/Distill/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
with open(out, 'wb') as f:
    f.write(make_png(pixels))

print(f"Written {out}")
