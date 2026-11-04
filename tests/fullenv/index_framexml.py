"""Indexes the game's own UI code (Interface/AddOns of the client): global functions, global tables
(mixins and others), global numeric/string constants with literal values, XML frames (global names)
and XML templates (virtual). Writes framexml_index.lua. Usage: index_framexml.py <Interface/AddOns> <out.lua>"""
import os, re, sys
import xml.etree.ElementTree as ET
root, out = sys.argv[1], sys.argv[2]
funcs, tables, nums, strs, frames, templates, exprs = set(), set(), {}, {}, set(), {}, {}
fonts, called, parentkeys = set(), set(), set()
tchildren = {}
selftables = set()
cfuncs = set()
dialogs = set()
xmlroots = []
def local(t): return t.split("}", 1)[1] if "}" in t else t
FRAMEISH = {"Frame","Button","CheckButton","ScrollFrame","EditBox","StatusBar","Slider","Cooldown","GameTooltip","Model","PlayerModel",
  "MessageFrame","ScrollingMessageFrame","SimpleHTML","Texture","FontString","MaskTexture","Line","EventFrame","DropdownButton"}
def kids(el, out, depth=0):
    for ch in el:
        tag = local(ch.tag)
        if tag in FRAMEISH:
            n, pk = ch.attrib.get("name"), ch.attrib.get("parentKey")
            if (n and n.lower().startswith("$parent")) or pk:
                if depth == 0 or (n and n.lower().startswith("$parent")):
                    out.append((n or "", pk or "", "Texture" if tag in ("Texture","MaskTexture","Line") else ("FontString" if tag == "FontString" else "Frame"), ch.attrib.get("inherits","")))
            if tag not in ("Texture","FontString","MaskTexture","Line"):
                continue  # a child frame's own children: its own template's business (they hang on it, not on us)
        else:
            kids(ch, out, depth)
rx_call = re.compile(r'(?<![\w.:])([A-Z][A-Za-z0-9_]*)\b')
rx_func = re.compile(r'^[ \t]*function\s+([A-Za-z_][\w]*)\s*\(', re.M)
rx_meth = re.compile(r'^function\s+([A-Za-z_][\w]*)[.:]', re.M)
rx_assign = re.compile(r'^([A-Za-z_][\w]*)\s*=\s*(.+?)\s*;?\s*(?:--.*)?$', re.M)
rx_num = re.compile(r'^-?\d+(\.\d+)?$')
rx_str = re.compile(r'^"([^"\\]*)"$')
rx_xml = re.compile(r'<(\w+)\s+([^>]*?)/?>', re.S)
rx_attr = re.compile(r'(\w+)\s*=\s*"([^"]*)"')
for d, _, fs in os.walk(root):
    for f in fs:
        p = os.path.join(d, f)
        if f.endswith(".lua"):
            s = open(p, encoding="utf-8", errors="replace").read()
            funcs.update(rx_func.findall(s))
            selftables.update(re.findall(r'\bself\.([a-z_]\w*)\s*=\s*\{', s))
            cfuncs.update(re.findall(r'\b(C_\w+\.\w+)', s))
            dialogs.update(re.findall(r'StaticPopupDialogs\["(\w+)"\]\s*=', s))
            code = re.sub(r'--\[\[.*?\]\]', '', s, flags=re.S)
            code = re.sub(r'--[^\n]*', '', code)
            code = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', code)
            for m in rx_call.finditer(code):
                before = code[max(0, m.start() - 9):m.start()]
                if not before.rstrip().endswith("function") and not before.rstrip().endswith("local"): called.add(m.group(1))
            tables.update(rx_meth.findall(s))
            for name, val in rx_assign.findall(s):
                if name in ("local", "function", "return", "end", "if", "for"): continue
                v = val.strip()
                if rx_num.match(v): nums[name] = v
                elif rx_str.match(v): strs[name] = rx_str.match(v).group(1)
                elif v.startswith("{") or v.startswith("CreateFromMixins") or v.startswith("Mixin("): tables.add(name)
                elif v.startswith("function"): funcs.add(name)
                else:
                    tables.add(name)  # something global exists under that name
                    if re.match(r'^[A-Z_][A-Z0-9_]+$', name) and name not in exprs and len(v) < 200: exprs[name] = v
        elif f.endswith(".xml"):
            s = open(p, encoding="utf-8", errors="replace").read()
            s = re.sub(r'<!--.*?-->', '', s, flags=re.S)
            parentkeys.update(re.findall(r'parentKey="([A-Za-z_]\w*)"', s))
            try:
                root = ET.fromstring(s)
                xmlroots.append(root)
                for el in root.iter():
                    if el.attrib.get("virtual") == "true" and el.attrib.get("name"):
                        found = []
                        kids(el, found)
                        if found: tchildren[el.attrib["name"]] = found
            except Exception:
                pass
            called.update(re.findall(r'(?:text|label|title|tooltip)="([A-Z][A-Z0-9_]+)"', s))
            # Lua in XML (bindings, scripts): the functions it calls
            for body in re.findall(r'>([^<]+)<', s):
                called.update(re.findall(r'(?<![\w.:])([A-Z][A-Za-z0-9_]*)\s*\(', body))
            for tag, attrs in rx_xml.findall(s):
                a = dict(rx_attr.findall(attrs))
                n = a.get("name")
                if not n or "$parent" in n.lower(): continue
                if a.get("virtual") == "true":
                    templates[n] = (tag, a.get("inherits", ""), a.get("mixin", ""))
                    if tag in ("Font", "FontFamily"): fonts.add(n)
                elif tag in ("Font", "FontFamily"):
                    fonts.add(n)
                elif tag not in ("Script", "Include", "Anchor", "Size", "Color", "Layer", "Layers"):
                    frames.add(n)
vtemplates = {}
for root in xmlroots:
    for el in root.iter():
        if el.attrib.get("virtual") == "true" and el.attrib.get("name"): vtemplates[el.attrib["name"]] = el
derived = set()
def walk(el, named, depth):
    if depth > 12: return
    for inh in [x for x in re.split(r"[,\s]+", el.attrib.get("inherits", "")) if x]:
        t = vtemplates.get(inh)
        if t is not None: walk(t, named, depth + 1)
    for ch in el:
        tag = local(ch.tag)
        n = ch.attrib.get("name")
        child_named = named
        if n and tag not in ("Script", "Include", "KeyValue"):
            if "$parent" in n.lower():
                if named: n = re.sub(r"\$[Pp]arent", named, n); derived.add(n); child_named = n
                else: child_named = None
            else:
                child_named = n
        if tag in FRAMEISH or tag in ("Frames", "Layers", "Layer", "ScrollChild", "ButtonText", "NormalTexture", "PushedTexture",
                                     "HighlightTexture", "DisabledTexture", "CheckedTexture", "ThumbTexture", "BarTexture"):
            walk(ch, child_named, depth + 1)
for root in xmlroots:
    for el in root:
        n = el.attrib.get("name")
        if n and el.attrib.get("virtual") != "true" and "$" not in n:
            walk(el, n, 0)
frames |= derived
def q(s): return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'
with open(out, "w", encoding="utf-8") as o:
    o.write("return {\nfunctions = {")
    o.write(",".join("[%s]=true" % q(n) for n in sorted(funcs)))
    o.write("},\ntables = {")
    o.write(",".join("[%s]=true" % q(n) for n in sorted(tables - funcs)))
    o.write("},\nnumbers = {")
    o.write(",".join("[%s]=%s" % (q(n), v) for n, v in sorted(nums.items())))
    o.write("},\nstrings = {")
    o.write(",".join("[%s]=%s" % (q(n), q(v)) for n, v in sorted(strs.items())))
    o.write("},\nexprs = {")
    o.write(",".join("[%s]=%s" % (q(n), q(v)) for n, v in sorted(exprs.items())))
    o.write("},\ntchildren = {")
    o.write(",".join("[%s]={%s}" % (q(n), ",".join("{%s,%s,%s,%s}" % (q(a), q(b), q(c), q(d)) for a, b, c, d in lst)) for n, lst in sorted(tchildren.items())))
    o.write("},\ndialogs = {")
    o.write(",".join("[%s]=true" % q(n) for n in sorted(dialogs)))
    o.write("},\ncfuncs = {")
    o.write(",".join("[%s]=true" % q(n) for n in sorted(cfuncs)))
    o.write("},\nselftables = {")
    o.write(",".join("[%s]=true" % q(n) for n in sorted(selftables)))
    o.write("},\nparentkeys = {")
    o.write(",".join("[%s]=true" % q(n) for n in sorted(parentkeys)))
    o.write("},\nfonts = {")
    o.write(",".join("[%s]=true" % q(n) for n in sorted(fonts)))
    o.write("},\nnative = {")
    o.write(",".join("[%s]=true" % q(n) for n in sorted(called - funcs - tables)))
    o.write("},\nframes = {")
    o.write(",".join("[%s]=true" % q(n) for n in sorted(frames)))
    o.write("},\ntemplates = {")
    o.write(",".join("[%s]={%s,%s,%s}" % (q(n), q(t), q(i), q(m)) for n, (t, i, m) in sorted(templates.items())))
    o.write("},\n}\n")
print("derived", len(derived), "selftables", len(selftables), "native", len(called - funcs - tables), "fonts", len(fonts), "functions", len(funcs), "tables", len(tables - funcs), "numbers", len(nums), "strings", len(strs), "frames", len(frames), "templates", len(templates))
