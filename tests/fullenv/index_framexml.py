"""Indexes the game's own UI code (Interface/AddOns of the client): global functions, global tables
(mixins and others), global numeric/string constants with literal values, XML frames (global names)
and XML templates (virtual). Writes framexml_index.lua. Usage: index_framexml.py <Interface/AddOns> <out.lua>"""
import os, re, sys
root, out = sys.argv[1], sys.argv[2]
funcs, tables, nums, strs, frames, templates, exprs = set(), set(), {}, {}, set(), {}, {}
fonts, called, parentkeys = set(), set(), set()
rx_call = re.compile(r'(?<![\w.:])([A-Z][A-Za-z0-9_]*)\b')
rx_func = re.compile(r'^function\s+([A-Za-z_][\w]*)\s*\(', re.M)
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
            called.update(re.findall(r'(?:text|label|title|tooltip)="([A-Z][A-Z0-9_]+)"', s))
            for tag, attrs in rx_xml.findall(s):
                a = dict(rx_attr.findall(attrs))
                n = a.get("name")
                if not n or "$parent" in n.lower(): continue
                if a.get("virtual") == "true":
                    templates[n] = (tag, a.get("inherits", ""), a.get("mixin", ""))
                    if tag in ("Font", "FontFamily"): fonts.add(n)
                elif tag in ("Font", "FontFamily"):
                    fonts.add(n)
                elif tag not in ("Script", "Include", "Anchor", "Size", "Color", "Texture", "FontString", "Layer", "Layers"):
                    frames.add(n)
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
print("native", len(called - funcs - tables), "fonts", len(fonts), "functions", len(funcs), "tables", len(tables - funcs), "numbers", len(nums), "strings", len(strs), "frames", len(frames), "templates", len(templates))
