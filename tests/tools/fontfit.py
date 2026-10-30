import sys, os
from PIL import ImageFont
d = sys.argv[1]
names = {"EmilysCandy-Regular.ttf":"Emily's Candy","Bangers-Regular.ttf":"Bangers","LuckiestGuy-Regular.ttf":"Luckiest Guy",
"Chewy-Regular.ttf":"Chewy","PermanentMarker-Regular.ttf":"Permanent Marker","Creepster-Regular.ttf":"Creepster",
"PirataOne-Regular.ttf":"Pirata One","MedievalSharp.ttf":"MedievalSharp","CinzelDecorative-Bold.ttf":"Cinzel Decorative",
"BebasNeue-Regular.ttf":"Bebas Neue","RussoOne-Regular.ttf":"Russo One","BlackOpsOne-Regular.ttf":"Black Ops One",
"Audiowide-Regular.ttf":"Audiowide","Righteous-Regular.ttf":"Righteous","PressStart2P-Regular.ttf":"Press Start 2P",
"ShareTechMono-Regular.ttf":"Share Tech Mono"}
ref = ImageFont.truetype("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf", 100)
def cap(f): b = f.getbbox("H"); return (b[3]-b[1])/100
def xh(f): b = f.getbbox("x"); return (b[3]-b[1])/100
print("ref arial cap %.3f x %.3f" % (cap(ref), xh(ref)))
textW = (320 - 16) / 2 - 10 - 10  # row width minus insets, with margin
for fn, nm in names.items():
    f100 = ImageFont.truetype(os.path.join(d, fn), 100)
    c, x = cap(f100), xh(f100)
    w13 = ImageFont.truetype(os.path.join(d, fn), 13).getlength(nm)
    # cap height like Arial at 13, never above 13, then shrink to fit the width
    s = min(13.0, 13.0 * cap(ref) / c)
    wid = ImageFont.truetype(os.path.join(d, fn), 100).getlength(nm) / 100
    s = min(s, textW / wid)
    print("%-28s cap %.3f x %.3f  w@13 %5.1f  -> size %.1f" % (nm, c, x, w13, s))
