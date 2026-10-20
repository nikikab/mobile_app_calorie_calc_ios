#!/usr/bin/env python3
"""Draws the app icon (1024x1024, opaque; iOS rounds the corners itself) with the same artwork as the Android
adaptive icon: a plate that is also a camera lens, between a fork and a knife, on a teal gradient.
Needs pycairo. Usage: tools/make_icon.py [output.png]"""
import math
import sys
import cairo

SIZE = 1024
# Android's foreground lives in a 108 unit box whose outer third is cropped by the launcher mask; iOS crops nothing,
# so the artwork is scaled up around the centre to fill the square the same way.
ZOOM = 1.3

out = sys.argv[1] if len(sys.argv) > 1 else "KaloCalc/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
s = cairo.ImageSurface(cairo.FORMAT_RGB24, SIZE, SIZE)
c = cairo.Context(s)

def rgb(h): return tuple(int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))

g = cairo.LinearGradient(0, 0, 0, SIZE)
g.add_color_stop_rgb(0, *rgb("#18BFAB"))
g.add_color_stop_rgb(1, *rgb("#0A5F5B"))
c.set_source(g)
c.paint()

k = SIZE / 108 * ZOOM
c.translate(SIZE / 2, SIZE / 2)
c.scale(k, k)
c.translate(-54, -54)
c.set_line_cap(cairo.LINE_CAP_ROUND)
c.set_line_join(cairo.LINE_JOIN_ROUND)

def stroke(color, width, build, cap=True):
    c.set_source_rgb(*rgb(color)); c.set_line_width(width)
    c.set_line_cap(cairo.LINE_CAP_ROUND if cap else cairo.LINE_CAP_BUTT)
    c.new_path(); build(); c.stroke()

def circle(x, y, r): c.new_sub_path(); c.arc(x, y, r, 0, 2 * math.pi)

def fork():
    for x in (25, 28.5, 32): c.move_to(x, 38); c.line_to(x, 47)
    c.move_to(25, 47); c.curve_to(26.2, 50, 30.8, 50, 32, 47)  # Q28.5,52 as a cubic
    c.move_to(28.5, 51); c.line_to(28.5, 70)

def knife():
    c.move_to(79, 40); c.curve_to(83, 45, 83, 54, 79, 58); c.line_to(79, 70)

stroke("#FFFFFF", 2.4, fork)
stroke("#FFFFFF", 2.4, knife)
stroke("#FFFFFF", 3, lambda: circle(54, 54, 18))
c.set_source_rgb(*rgb("#073F3E")); c.new_path(); circle(54, 54, 16.5); c.fill()
stroke("#8EE9D6", 1.4, lambda: circle(54, 54, 11))
c.set_source_rgb(*rgb("#19A596")); c.new_path(); circle(54, 54, 6); c.fill()
c.set_source_rgb(*rgb("#052B2A")); c.new_path(); circle(54, 54, 2.6); c.fill()
c.set_source_rgb(1, 1, 1); c.new_path(); circle(49.8, 49.8, 2.2); c.fill()
stroke("#C6F432", 1.6, lambda: (c.move_to(42.74, 47.5), c.arc(54, 54, 13, math.radians(210), math.radians(250))))
s.write_to_png(out)
