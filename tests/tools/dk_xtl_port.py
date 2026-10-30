"""Port DialogKey (Numy Edition v1.2.62) and XToLevel 12.1.5 into Clara Combo Points.
Usage: dk_xtl_port.py <DialogKey_Numy dir> <XToLevel dir> <ClaraComboPoints dir>
Every file gets a guard (it does nothing unless its module runs: ClaraNS.DialogKeyRuns,
ClaraNS.XToLevelRuns, set by each module's Bootstrap.lua), its libraries too. Each edit must match
the exact count given, or the script stops. Bootstrap.lua and Glue.lua are Clara's own (kept)."""
import os, re, shutil, sys

dk_src, xtl_src, dst = sys.argv[1], sys.argv[2], sys.argv[3]

def guard(flag, what):
    return (f"local _, ClaraNS = ... -- (Clara Combo Points: {what} built in, QoL.lua)\n"
            f"if not (type(ClaraNS) == \"table\" and ClaraNS.{flag}) then return end\n")

def lib_guard(flag, what):
    return (f"local _, ClaraNS = ... -- (Clara Combo Points: loaded only for {what} built in)\n"
            f"if type(ClaraNS) == \"table\" and not ClaraNS.{flag} then return end\n")

def edit(text, old, new, count, where):
    n = text.count(old)
    if n != count:
        sys.exit(f"{where}: expected {count}, found {n}: {old[:80]!r}")
    return text.replace(old, new)

def read(path):
    with open(path, "rb") as f:
        return f.read().decode("utf-8-sig").replace("\r\n", "\n")

def write(path, text):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)

def fresh(out, src, ignore):
    keep = {}
    for own in ("Bootstrap.lua", "Glue.lua"):
        p = os.path.join(out, own)
        if os.path.exists(p):
            keep[own] = read(p)
    if os.path.isdir(out):
        shutil.rmtree(out)
    shutil.copytree(src, out, ignore=shutil.ignore_patterns(*ignore))
    for own, text in keep.items():
        write(os.path.join(out, own), text)

def port(out, flag, what, edits, every=None):
    done = set()
    for root, _, files in os.walk(out):
        for name in files:
            rel = os.path.relpath(os.path.join(root, name), out)
            if rel in ("Bootstrap.lua", "Glue.lua"):
                continue
            is_lib = rel.split(os.sep)[0] in ("libs", "Libs") and os.sep in rel
            if not (name.endswith(".lua") or name.endswith(".xml")):
                continue
            path = os.path.join(out, rel)
            text = read(path)
            if every and not is_lib:
                text = every(rel, text)
            for old, new, count in edits.get(rel, []):
                text = edit(text, old, new, count, rel)
                done.add(rel)
            if name.endswith(".lua"):
                text = (lib_guard(flag, what) if is_lib else guard(flag, what)) + text
            write(path, text)
    missing = set(edits) - done
    if missing:
        sys.exit(f"files not found: {sorted(missing)}")

modules = os.path.join(dst, "Modules")

# ---------------------------------------------------------------- DialogKey
out = os.path.join(modules, "DialogKey")
fresh(out, dk_src, ["DialogKey_Numy.toc", "LibVersionCheck-1.0", "media", "CHANGELOG.md", "README.md"])
PRIVATE_DK = "local ns = ClaraNS.DialogKeyPrivate -- (its own table: Clara's is the one `...` gives)"
port(out, "DialogKeyRuns", "DialogKey", {
    # its libraries, without LibVersionCheck (it tells other players' clients which version runs)
    "embeds.xml": [('    <Include file="libs\\LibVersionCheck-1.0\\LibVersionCheck-1.0.xml"/>\n', "", 1)],
    "api.lua": [("local ns = select(2, ...);", PRIVATE_DK, 1)],
    "main.lua": [("local name = ...", 'local name = "DialogKey_Numy" -- (its own addon\'s name: only one of the two runs)', 1),
                 ("local ns = select(2, ...)", PRIVATE_DK, 1),
                 ("DialogKeyNumyDB", "ClaraDialogKeyDB", 3)],
    # its page in the game's options: under Clara's "Interface improvements"
    "options.lua": [("local ns = select(2, ...)", PRIVATE_DK, 1),
                    ('LibStub("AceConfigDialog-3.0"):AddToBlizOptions(self.configPanelName)',
                     'LibStub("AceConfigDialog-3.0"):AddToBlizOptions(self.configPanelName, "DialogKey",\n'
                     '            ClaraNS.qolCategory and ClaraNS.qolCategory:GetID() or nil)', 1)],
})
print("ok", out)

# ---------------------------------------------------------------- XToLevel
out = os.path.join(modules, "XToLevel")
fresh(out, xtl_src, ["XToLevel.toc", "customPatterns.txt"])
TEX_OLD_XML = "Interface\\AddOns\\XToLevel\\textures\\"
TEX_NEW_XML = "Interface\\AddOns\\ClaraComboPoints\\Modules\\XToLevel\\textures\\"
PRIVATE_XTL = "local addonTable = ClaraNS.XToLevelPrivate -- (its own table: Clara's is the one `...` gives)"

def every_xtl(rel, text):
    # its frames' and templates' global names: Clara's own (no clash with the standalone's XML)
    text = re.sub(r"\bXToLevel_", "ClaraXToLevel_", text)
    text = text.replace(TEX_OLD_XML, TEX_NEW_XML)
    text = text.replace(TEX_OLD_XML.replace("\\", "\\\\"), TEX_NEW_XML.replace("\\", "\\\\"))
    if rel.endswith(".lua") and "local _, addonTable = ..." in text:
        text = edit(text, "local _, addonTable = ...", PRIVATE_XTL, 1, rel)
    if "AddOns\\XToLevel" in text or "AddOns\\\\XToLevel" in text:
        sys.exit(f"{rel}: a path to the standalone's folder left")
    return text

port(out, "XToLevelRuns", "XToLevel", {
    "Main.lua": [('LibStub("AceDB-3.0"):New("XToLevelDB"', 'LibStub("AceDB-3.0"):New("ClaraXToLevelDB"', 1)],
    # its pages in the game's options: under Clara's "Interface improvements"
    "Config.lua": [('    self.frames.Information = A3CFG:AddToBlizOptions("XToLevel", head_frame_str, nil, "Information")\n',
                    '    local headID -- (Clara Combo Points: under Interface improvements, its pages under it)\n'
                    '    self.frames.Information, headID = A3CFG:AddToBlizOptions("XToLevel", head_frame_str,\n'
                    '        ClaraNS.qolCategory and ClaraNS.qolCategory:GetID() or nil, "Information")\n'
                    '    if ClaraNS.qolCategory and headID then head_frame_str = headID end\n', 1),
                   # its window by default: in a row (no Vertical Align), without the dungeons' and battles' boxes
                   ("\t\t        orientation = 'v',\n",
                    "\t\t        orientation = 'h', -- (Clara Combo Points: in a row)\n", 1),
                   ("\t\t        playerDungeons = true,\n\t\t        playerBGs = true,\n",
                    "\t\t        playerDungeons = false, -- (Clara Combo Points: these two off)\n"
                    "\t\t        playerBGs = false,\n", 1)],
    # the windows: templates, made by Glue.lua only while the module runs (an XML frame would be
    # made, and shown, in every session)
    os.path.join("frames", "AverageFrame_Classic.xml"): [
        ('<Frame name="ClaraXToLevel_AverageFrame_Classic" parent="UIParent"',
         '<Frame name="ClaraXToLevel_AverageFrame_Classic_Template" virtual="true"', 1),
        # its place by default: the middle of the screen's top (Clara Combo Points)
        ('<Anchor point="TOPLEFT" relativeTo="WorldFrame" relativePoint="TOPLEFT">\n\t\t\t<Offset x="25" y="-100" />',
         '<Anchor point="TOP" relativeTo="UIParent" relativePoint="TOP"> <!-- (Clara Combo Points: the top\'s middle) -->\n'
         '\t\t\t<Offset x="0" y="-1" />', 1)],
    os.path.join("frames", "AverageFrame_Blocky.xml"): [
        ('<Frame name="ClaraXToLevel_AverageFrame_Blocky_PlayerFrame" parent="UIParent"',
         '<Frame name="ClaraXToLevel_AverageFrame_Blocky_PlayerFrame_Template" virtual="true"', 1),
        ('<Anchor point="TOPLEFT" relativeTo="WorldFrame" relativePoint="TOPLEFT">\n            <Offset x="25" y="-100" />',
         '<Anchor point="TOP" relativeTo="UIParent" relativePoint="TOP"> <!-- (Clara Combo Points: the top\'s middle) -->\n'
         '            <Offset x="0" y="-1" />', 1)],
}, every_xtl)
print("ok", out)
