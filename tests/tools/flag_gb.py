"""Draw the Union Jack (2:1) and save it as an uncompressed 32-bit TGA, bottom-left origin."""
import math, struct, sys
from PIL import Image, ImageDraw

out = sys.argv[1]
W, H = 1200, 600                      # 60 x 30 units, 20 px per unit
u = W / 60
NAVY, RED, WHITE = (1, 33, 105, 255), (200, 16, 46, 255), (255, 255, 255, 255)
im = Image.new("RGBA", (W, H), NAVY)
d = ImageDraw.Draw(im)

def band(p0, p1, width, offset, color):
    # strip along p0->p1, `width` wide, centre shifted by `offset` along the normal
    (x0, y0), (x1, y1) = p0, p1
    dx, dy = x1 - x0, y1 - y0
    n = math.hypot(dx, dy)
    nx, ny = -dy / n, dx / n
    a, b = offset - width / 2, offset + width / 2
    d.polygon([(x0 + nx * a, y0 + ny * a), (x1 + nx * a, y1 + ny * a),
               (x1 + nx * b, y1 + ny * b), (x0 + nx * b, y0 + ny * b)], fill=color)

c = (W / 2, H / 2)
corners = [(0, 0), (W, 0), (W, H), (0, H)]
for corner in corners:                 # white saltire, 6 units
    band(c, corner, 6 * u, 0, WHITE)
for corner in corners:                 # red saltire, 2 units, counterchanged (pinwheel)
    band(c, corner, 2 * u, 1 * u, RED)
d.rectangle([W / 2 - 5 * u, 0, W / 2 + 5 * u, H], fill=WHITE)   # white cross, 10 units
d.rectangle([0, H / 2 - 5 * u, W, H / 2 + 5 * u], fill=WHITE)
d.rectangle([W / 2 - 3 * u, 0, W / 2 + 3 * u, H], fill=RED)     # red cross, 6 units
d.rectangle([0, H / 2 - 3 * u, W, H / 2 + 3 * u], fill=RED)

small = im.resize((64, 32), Image.LANCZOS)
small.save(out + ".png")
pixels = small.load()
with open(out, "wb") as f:
    f.write(struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, 64, 32, 32, 8))
    for y in range(31, -1, -1):        # bottom row first
        for x in range(64):
            r, g, b, a = pixels[x, y]
            f.write(bytes((b, g, r, a)))
print("saved", out)
