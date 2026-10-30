"""Render dumped draw ops. Usage: render.py <tools> <addon> <scene> <out.png> <bg.png|-> <crop: hud|panel>"""
import os, sys
from lupa import lua51
from PIL import Image, ImageDraw, ImageFont

tools, addon, scene, out_png, bg_png, crop = sys.argv[1:7]
extra = dict(a.split("=", 1) for a in sys.argv[7:])
ops_file = out_png + ".ops"
L = lua51.LuaRuntime(unpack_returned_tuples=True)
import os as _os
from PIL import ImageFont as _IF
_FONT_CACHE = {}
def measure(path, size, text):
    path = str(path); size = max(1, int(round(float(size))))
    if path.startswith("Interface\\AddOns\\ClaraComboPoints\\"):
        file = _os.path.join(addon, path.split("ClaraComboPoints\\", 1)[1].replace("\\", "/")); squeeze = 1.0
    else:
        file = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
        squeeze = 0.82 if path.upper().endswith("ARIALN.TTF") else 1.0
    key = (file, size)
    if key not in _FONT_CACHE:
        _FONT_CACHE[key] = _IF.truetype(file, size)
    return _FONT_CACHE[key].getlength(str(text)) * squeeze
g = L.globals()
g.MEASURE = measure
g.ADDON_DIR, g.SCENE, g.OUT_FILE = addon, scene, ops_file
g.LANG, g.SKIN, g.TAB, g.PAGE = extra.get("lang"), extra.get("skin"), extra.get("tab"), extra.get("page")
g.ACT = extra.get("act")
L.execute(open(f"{tools}/wowmock.lua").read())
L.execute(open(f"{tools}/render.lua").read())

PHYS_W, PHYS_H = 2560, 1359
PX = PHYS_H / 768.0  # physical px per absolute unit

if bg_png != "-":
    bg = Image.open(bg_png).convert("RGBA").resize((PHYS_W, PHYS_H))
else:
    bg = Image.new("RGBA", (PHYS_W, PHYS_H), (45, 30, 20, 255))
img = bg.copy()

FALLBACK = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
def font_file(path):
    if path.startswith("Interface\\AddOns\\ClaraComboPoints\\"):
        return os.path.join(addon, path.split("ClaraComboPoints\\", 1)[1].replace("\\", "/"))
    return FALLBACK

ops = []
for line in open(ops_file, encoding="utf-8"):
    p = line.rstrip("\n").split("\t")
    ops.append(p)
ops.sort(key=lambda p: (int(p[1]), int(p[2]), int(p[3]), int(p[4])))

def to_px(l, b, w, h):
    x0 = float(l) * PX; y1 = PHYS_H - float(b) * PX
    return x0, y1 - float(h) * PX, x0 + float(w) * PX, y1

for p in ops:
    kind = p[0]
    x0, y0, x1, y1 = to_px(*p[5:9])
    alpha = float(p[9])
    clip = None if p[10] == "-" else to_px(*p[10].split(","))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    if kind == "tmpl":
        name, state = p[11], p[12] if len(p) > 12 else ""
        X0, Y0, X1, Y1 = round(x0), round(y0), round(x1) - 1, round(y1) - 1
        A = int(255 * alpha)
        if name in ("PortraitFrameTemplate", "DefaultPanelTemplate"):
            d.rectangle([X0, Y0, X1, Y1], fill=(20, 19, 19, A))                      # rock background, darkened
            d.rectangle([X0 + 4, Y0 + 4, X1 - 4, Y0 + 36], fill=(20, 20, 22, A))     # title bar
            for k in range(6):
                c = (120 - k * 12, 120 - k * 12, 125 - k * 12, A)
                d.rectangle([X0 + k, Y0 + k, X1 - k, Y1 - k], outline=c)            # metal frame
        elif name == "InsetFrameTemplate":
            d.rectangle([X0, Y0, X1, Y1], fill=(16, 17, 19, A), outline=(70, 70, 74, A), width=3)
        elif name == "UIPanelButtonTemplate":
            d.rectangle([X0, Y0, X1, Y1], fill=(138, 18, 14, A), outline=(165, 165, 170, A), width=2)
            if "locked" in state:
                d.rectangle([X0 + 3, Y0 + 3, X1 - 3, Y1 - 3], outline=(255, 210, 60, A), width=2)
        elif name == "PanelTabButtonTemplate":
            bottom = Y0 + (Y1 - Y0) * 0.75
            if "selected" in state:
                d.rectangle([X0, Y0, X1, bottom], fill=(46, 44, 42, A), outline=(150, 150, 155, A), width=2)
            else:
                d.rectangle([X0, Y0 + 3, X1, bottom - 3], fill=(92, 22, 16, A), outline=(120, 120, 125, A), width=2)
        elif name == "PanelTopTabButtonTemplate":
            top = Y0 + (Y1 - Y0) * 0.25
            if "selected" in state:
                d.rectangle([X0, top, X1, Y1], fill=(46, 44, 42, A), outline=(150, 150, 155, A), width=2)
            else:
                d.rectangle([X0, top + 3, X1, Y1], fill=(92, 22, 16, A), outline=(120, 120, 125, A), width=2)
        elif name == "UICheckButtonTemplate":
            m = int((X1 - X0) * .2)
            d.rectangle([X0 + m, Y0 + m, X1 - m, Y1 - m], fill=(25, 25, 27, A), outline=(160, 160, 165, A), width=2)
            if "checked" in state:
                d.line([X0 + m + 3, (Y0 + Y1) // 2, (X0 + X1) // 2, Y1 - m - 3, X1 - m + 3, Y0 + m - 3], fill=(255, 210, 0, A), width=4)
        elif name == "UISliderTemplate":
            cy = (Y0 + Y1) // 2
            d.rectangle([X0, cy - 5, X1, cy + 5], fill=(25, 25, 28, A), outline=(140, 140, 145, A), width=2)
        elif name == "InputBoxTemplate":
            d.rectangle([X0 - 9, Y0, X1, Y1], fill=(12, 12, 14, A), outline=(110, 110, 115, A), width=2)
    elif kind == "backdrop":
        edge, bg, border = p[11], [float(v) for v in p[12].split(",")], [float(v) for v in p[13].split(",")]
        if "DialogBox" in edge:
            base, ec, ew, inset = (18, 18, 20), (150, 125, 80), 0.010, 0.015
        elif "SliderBar" in edge:
            base, ec, ew, inset = (35, 35, 38), (140, 140, 145), 0.0035, 0.0
        elif "Tooltip" in edge:
            base, ec, ew, inset = (255, 255, 255), (255, 255, 255), 0.0022, 0.004
        else:
            base, ec, ew, inset = (255, 255, 255), (160, 160, 160), 0.0035, 0.0
        X0, Y0, X1, Y1 = round(x0), round(y0), round(x1) - 1, round(y1) - 1
        ewp = max(2, int(PHYS_H * ew)); ins = int(PHYS_H * inset)
        if "SliderBar" in edge:  # thin bar in the middle
            cy = (Y0 + Y1) / 2; Y0, Y1 = int(cy - 4), int(cy + 4)
        fill = tuple(int(base[i] * bg[i]) for i in range(3)) + (int(255 * bg[3] * alpha),)
        d.rectangle([X0 + ins // 2, Y0 + ins // 2, X1 - ins // 2, Y1 - ins // 2], fill=fill)
        ecol = tuple(int(ec[i] * border[i]) for i in range(3)) + (int(255 * border[3] * alpha),)
        for k in range(ewp):
            d.rectangle([X0 + k, Y0 + k, X1 - k, Y1 - k], outline=ecol)
    elif kind == "file":
        r, gg, b, a = [float(v) for v in p[11].split(",")]
        path, ralpha = p[12], float(p[13])
        a = a * ralpha * alpha
        X0, Y0, X1, Y1 = round(x0), round(y0), round(x1) - 1, round(y1) - 1
        W_, H_ = X1 - X0, Y1 - Y0
        if W_ < 0 or H_ < 0: continue
        def col(c): return (int(c[0] * r), int(c[1] * gg), int(c[2] * b), int(255 * a))
        if "UI-Panel-Button-" in path:
            base = {"Up": (155, 22, 15), "Down": (95, 10, 8), "Disabled": (88, 88, 92)}.get(path.rsplit("-", 1)[1])
            if base and "Highlight" not in path:
                # only the slice that spans the button is drawn once (middle); caps darker
                d.rectangle([X0, Y0, X1, Y1], fill=col(base))
                d.line([X0, Y0, X1, Y0], fill=col((200, 160, 90)))
                d.line([X0, Y1, X1, Y1], fill=col((40, 10, 8)))
        elif path.endswith("UI-CheckBox-Up"):
            m = int(W_ * .22); d.rectangle([X0 + m, Y0 + m, X1 - m, Y1 - m], fill=col((30, 30, 32)), outline=col((170, 170, 170)), width=2)
        elif path.endswith("UI-CheckBox-Check"):
            m = int(W_ * .3)
            d.line([X0 + m, (Y0 + Y1) // 2, (X0 + X1) // 2, Y1 - m, X1 - m + 2, Y0 + m - 2], fill=col((255, 210, 0)), width=3)
        elif path.endswith("UI-SliderBar-Button-Horizontal"):
            cx, cy = (X0 + X1) / 2, (Y0 + Y1) / 2
            d.rectangle([cx - W_ * .16, cy - H_ * .28, cx + W_ * .16, cy + H_ * .28], fill=col((205, 205, 210)), outline=col((90, 90, 90)))
        elif path.endswith("Flags\\GB"):
            flag = Image.open(os.path.join(addon, "Media/Flags/GB.tga")).convert("RGBA").resize((max(1, W_ + 1), max(1, H_ + 1)))
            if a < 1: flag.putalpha(flag.getchannel("A").point(lambda v: int(v * a)))
            layer.alpha_composite(flag, (X0, Y0))
        elif path.startswith("ATLAS:"):
            u0, u1, v0, v1 = [float(v) for v in path.split("|")[1].split(",")]
            band_w, band_h = (X1 - X0 + 1) * .45, (Y1 - Y0 + 1) * .45
            grey, dark = (128, 126, 122, int(235 * a)), (30, 28, 26, int(255 * a))
            if u0 < .01: d.rectangle([X0, Y0, X0 + band_w, Y1], fill=grey); d.line([X0, Y0, X0, Y1], fill=dark)
            if u1 > .99: d.rectangle([X1 - band_w, Y0, X1, Y1], fill=grey); d.line([X1, Y0, X1, Y1], fill=dark)
            if v0 < .01: d.rectangle([X0, Y0, X1, Y0 + band_h], fill=grey); d.line([X0, Y0, X1, Y0], fill=dark)
            if v1 > .99: d.rectangle([X0, Y1 - band_h, X1, Y1], fill=grey); d.line([X0, Y1, X1, Y1], fill=dark)
        elif path.startswith("ICON:") or "INV_Misc_QuestionMark" in path:
            if path.startswith("ICON:"):
                _, nm, mode = path.split(":")
            else:
                nm, mode = "?", "C"
            import zlib
            h = zlib.crc32(nm.encode()) % 360
            import colorsys
            rr, g2, bb = colorsys.hsv_to_rgb(h / 360, .65, .75)
            base = (int(rr * 255), int(g2 * 255), int(bb * 255))
            if mode == "D":
                gray = int(sum(base) / 3); base = (gray, gray, gray)
            d.rectangle([X0, Y0, X1, Y1], fill=base + (int(255 * a),))
            initials = "".join(w[0] for w in nm.split()[:2]).upper()
            fnt = ImageFont.truetype(FALLBACK, max(8, int(min(W_, H_) * .45)))
            tw = d.textlength(initials, font=fnt)
            d.text(((X0 + X1) / 2 - tw / 2, (Y0 + Y1) / 2 - min(W_, H_) * .28), initials, font=fnt, fill=(255, 255, 255, int(200 * a)))
        elif "Interface\\Icons\\" in path:
            fill = (110, 30, 25, int(255 * a)) if "Rogue" in path else (120, 85, 40, int(255 * a))
            d.ellipse([X0 + 4, Y0 + 2, X1 - 4, Y1 - 6], fill=fill, outline=(200, 170, 90, int(255 * a)), width=4)
        elif path.endswith("WHITE8X8"):
            d.rectangle([X0, Y0, X1, Y1], fill=col((255, 255, 255)))
    elif kind == "cooldown":
        frac, rev, text, size = float(p[11]), p[12] == "1", p[13], float(p[14]) * PX
        X0, Y0, X1, Y1 = round(x0), round(y0), round(x1) - 1, round(y1) - 1
        R = max(X1 - X0, Y1 - Y0)
        cxp, cyp = (X0 + X1) / 2, (Y0 + Y1) / 2
        pie = Image.new("RGBA", img.size, (0, 0, 0, 0))
        pd = ImageDraw.Draw(pie)
        elapsed = 1 - frac
        if rev: start, end = -90, -90 + 360 * elapsed
        else: start, end = -90 + 360 * elapsed, 270
        pd.pieslice([cxp - R, cyp - R, cxp + R, cyp + R], start, end, fill=(0, 0, 0, int(163 * alpha)))
        mask = Image.new("L", img.size, 0); ImageDraw.Draw(mask).rectangle([X0, Y0, X1, Y1], fill=255)
        pie.putalpha(Image.composite(pie.getchannel("A"), Image.new("L", img.size, 0), mask))
        layer.alpha_composite(pie)
        if text:
            f = ImageFont.truetype(FALLBACK, max(6, round(size)))
            tw = d.textlength(text, font=f)
            d.text((cxp - tw / 2, cyp - size * .6), text, font=f, fill=(255, 255, 255, int(255 * alpha)), stroke_width=1, stroke_fill=(0, 0, 0, int(255 * alpha)))
    elif kind == "rect":
        r, gg, b, a = [float(v) for v in p[11].split(",")]
        if x1 - x0 > 0 and y1 - y0 > 0:
            d.rectangle([round(x0), round(y0), round(x1) - 1, round(y1) - 1], fill=(int(r * 255), int(gg * 255), int(b * 255), int(a * alpha * 255)))
    else:
        r, gg, b, a = [float(v) for v in p[11].split(",")]
        path, size, flags, text, justify = p[12], float(p[13]) * PX, p[14], p[15], p[16]
        f = ImageFont.truetype(font_file(path), max(6, round(size)))
        narrow = path.upper().endswith("ARIALN.TTF")
        tw = d.textlength(text, font=f)
        tmp = Image.new("RGBA", (int(tw) + 8, int(size * 1.6) + 8), (0, 0, 0, 0))
        td = ImageDraw.Draw(tmp)
        sw = 2 if "THICK" in flags else (1 if "OUTLINE" in flags else 0)
        td.text((4, 4), text, font=f, fill=(int(r * 255), int(gg * 255), int(b * 255), int(a * alpha * 255)),
                stroke_width=sw, stroke_fill=(0, 0, 0, int(a * alpha * 255)))
        if narrow:
            tmp = tmp.resize((max(1, int(tmp.width * 0.82)), tmp.height))
        bbox = tmp.getbbox() or (0, 0, 1, 1)
        tmp = tmp.crop(bbox)
        cx = (x0 + x1) / 2
        if justify == "LEFT" and x1 - x0 > tmp.width + 2:
            px = x0
        else:
            px = cx - tmp.width / 2
        py = (y0 + y1) / 2 - tmp.height / 2
        layer.alpha_composite(tmp, (int(round(px)), int(round(py))))
    if clip:
        mask = Image.new("L", img.size, 0)
        ImageDraw.Draw(mask).rectangle([clip[0], clip[1], clip[2], clip[3]], fill=255)
        layer.putalpha(Image.composite(layer.getchannel("A"), Image.new("L", img.size, 0), mask))
    img.alpha_composite(layer)

if crop == "hud":
    # same crop as the reference screenshot 1 (HUD at 30..322 x 43..96 inside a 398x122 image)
    cx, cy = PHYS_W / 2, PHYS_H / 2 + 204
    box = (int(cx - 146 - 30), int(cy - 26.5 - 43), int(cx - 146 - 30 + 398), int(cy - 26.5 - 43 + 122))
    img = img.crop(box)
elif crop == "hudwide":
    cx, cy = PHYS_W / 2, PHYS_H / 2 + 210
    img = img.crop((int(cx - 330), int(cy - 170), int(cx + 330), int(cy + 130)))
elif crop == "panelwide":
    img = img.crop((int(PHYS_W / 2 - 720 * 0.71 * PX / 2) - 20, int(PHYS_H / 2 - 660 * 0.71 * PX / 2) - 20,
                    int(PHYS_W / 2 + 720 * 0.71 * PX / 2 + 420 * 0.71 * PX) + 20, int(PHYS_H / 2 + 660 * 0.71 * PX / 2) + 60))
elif crop == "panel":
    img = img.crop((int(PHYS_W / 2 - 720 * 0.71 * PX / 2) - 20, int(PHYS_H / 2 - 660 * 0.71 * PX / 2) - 20,
                    int(PHYS_W / 2 + 720 * 0.71 * PX / 2) + 20, int(PHYS_H / 2 + 660 * 0.71 * PX / 2) + 60))
img.convert("RGB").save(out_png)
print("saved", out_png, img.size)
