"""Locale keys used at a revision but no more in the work tree. Usage: unused_keys.py <repo> <rev>"""
import re, subprocess, sys, os
repo, rev = sys.argv[1], sys.argv[2]
loc = open(os.path.join(repo, "ClaraComboPoints/Locales.lua"), encoding="utf-8").read()
en = loc.split("frFR = {")[0]
keys = re.findall(r"^\s+([A-Z][A-Z0-9_]+)\s*=", en, re.M)
def corpus_now():
    out = []
    for root, _, files in os.walk(os.path.join(repo, "ClaraComboPoints")):
        for f in files:
            if f.endswith((".lua", ".xml")) and f != "Locales.lua":
                out.append(open(os.path.join(root, f), encoding="utf-8", errors="replace").read())
    return "\n".join(out)
def corpus_rev():
    files = subprocess.check_output(["git", "-C", repo, "ls-tree", "-r", "--name-only", rev, "ClaraComboPoints"], text=True).split()
    out = []
    for f in files:
        if f.endswith((".lua", ".xml")) and not f.endswith("/Locales.lua"):
            out.append(subprocess.check_output(["git", "-C", repo, "show", f"{rev}:{f}"]).decode("utf-8", "replace"))
    return "\n".join(out)
def used(key, text, modkeys):
    if re.search(r"\b" + key + r"\b", text): return True
    for fam in ("QOL_NAV_", "QOL_NAVDESC_", "QOL_ABOUT_"):
        if key.startswith(fam) and key[len(fam):].lower() in modkeys: return True
    return False
def modkeys(text): return set(re.findall(r'\{ key = "([a-z]+)", name =', text))
now, old = corpus_now(), corpus_rev()
mk_now, mk_old = modkeys(now), modkeys(old)
gone = [k for k in keys if used(k, old, mk_old) and not used(k, now, mk_now)]
print(" ".join(gone))
