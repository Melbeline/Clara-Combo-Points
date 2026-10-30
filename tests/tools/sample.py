import sys
from PIL import Image
from collections import Counter
for path, box in [(sys.argv[1], None), (sys.argv[2], (140, 350, 545, 385)), (sys.argv[3], (100, 342, 505, 378))]:
    im = Image.open(path).convert("RGB")
    if box: im = im.crop(box)
    c = Counter(im.getdata())
    print(path.split('/')[-1], im.size, [(k, v) for k, v in c.most_common(6)])
