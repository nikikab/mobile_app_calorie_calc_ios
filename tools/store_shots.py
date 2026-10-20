#!/usr/bin/env python3
"""Turns the CI simulator screenshots into App Store screenshots: the icon's teal gradient, a caption, and the screen
in a rounded frame. Input must be 6.9-inch shots (1320x2868); output is the same size, which App Store Connect accepts.
Needs pycairo. Usage: tools/store_shots.py <screenshots dir> <output dir>"""
import os
import sys
import cairo

W, H = 1320, 2868
SCREENS = ["diary", "search", "photo", "progress", "goal", "settings"]
CAPTIONS = {
    "en": ["Your day at a glance", "Find any food fast", "Snap a meal, get an estimate",
           "Watch your progress", "A target made for you", "Your data stays on your phone"],
    "bg": ["Денят ти накратко", "Намери всяка храна", "Снимай ястие, получи оценка",
           "Следи напредъка си", "Цел, направена за теб", "Данните остават на телефона"],
}
FONT = "DejaVu Sans"

def rgb(h): return tuple(int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))

def rounded(c, x, y, w, h, r):
    c.new_sub_path()
    for cx, cy, a in ((x + w - r, y + r, -90), (x + w - r, y + h - r, 0), (x + r, y + h - r, 90), (x + r, y + r, 180)):
        c.arc(cx, cy, r, a * 3.14159265 / 180, (a + 90) * 3.14159265 / 180)
    c.close_path()

def wrap(c, text, width):
    lines, line = [], ""
    for word in text.split():
        trial = (line + " " + word).strip()
        if c.text_extents(trial).width <= width or not line:
            line = trial
        else:
            lines.append(line); line = word
    return lines + [line]

def compose(shot, caption, out):
    img = cairo.ImageSurface.create_from_png(shot)
    s = cairo.ImageSurface(cairo.FORMAT_RGB24, W, H)
    c = cairo.Context(s)
    g = cairo.LinearGradient(0, 0, 0, H)
    g.add_color_stop_rgb(0, *rgb("#18BFAB")); g.add_color_stop_rgb(1, *rgb("#0A5F5B"))
    c.set_source(g); c.paint()

    c.select_font_face(FONT, cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
    c.set_font_size(96)
    lines = wrap(c, caption, W - 160)
    c.set_source_rgb(1, 1, 1)
    y = 190
    for line in lines:
        c.move_to((W - c.text_extents(line).x_advance) / 2, y)
        c.show_text(line)
        y += 118

    # The screen is scaled to 84% and cut off at the bottom edge, like a phone rising from below.
    scale = 0.84
    sw, sh = img.get_width() * scale, img.get_height() * scale
    x0, y0 = (W - sw) / 2, y + 40
    c.save()
    rounded(c, x0, y0, sw, sh, 70)
    c.clip()
    c.translate(x0, y0); c.scale(scale, scale)
    c.set_source_surface(img, 0, 0)
    c.paint()
    c.restore()
    c.set_source_rgba(1, 1, 1, 0.9); c.set_line_width(10)
    rounded(c, x0, y0, sw, sh, 70); c.stroke()
    s.write_to_png(out)

def main():
    src, dst = sys.argv[1], sys.argv[2]
    for lang, captions in CAPTIONS.items():
        os.makedirs(os.path.join(dst, lang), exist_ok=True)
        for i, (name, caption) in enumerate(zip(SCREENS, captions), 1):
            compose(os.path.join(src, f"{name}-{lang}.png"), caption, os.path.join(dst, lang, f"{i}-{name}.png"))

main()
