"""Port NodeSight 1.4.0 into Clara Combo Points (Modules/NodeSight).
Usage: nodesight_port.py <NodeSight dir> <ClaraComboPoints dir>
Each edit must match the exact number of times given, or the script stops."""
import os, sys

src, dst = sys.argv[1], sys.argv[2]
out = os.path.join(dst, "Modules", "NodeSight")
os.makedirs(out, exist_ok=True)

HEADER = ("local _, Clara = ... -- (Clara Combo Points: NodeSight built in, QoL.lua)\n"
          "local ns = Clara.NodeSight\n"
          "if not ns then return end -- (the module does not run)")

def edit(text, old, new, count=1):
    n = text.count(old)
    if n != count:
        sys.exit(f"edit expected {count}, found {n}: {old[:70]!r}")
    return text.replace(old, new)

FILES = ["Names.lua", "NodeSight.lua", "Sparkles.lua", "FarSparkles.lua", "WhatsNew.lua", "Settings.lua"]
for name in FILES:
    with open(os.path.join(src, name), "rb") as f:
        text = f.read().decode("utf-8-sig").replace("\r\n", "\n")
    if "local ADDON_NAME, ns = ..." in text:
        text = edit(text, "local ADDON_NAME, ns = ...", HEADER + "\nlocal ADDON_NAME = \"ClaraComboPoints\" -- (its files load with Clara's)")
    else:
        text = edit(text, "local _, ns = ...", HEADER)
    # its saved settings: Clara's own copy
    text = text.replace("NodeSightDB", "ClaraNodeSightDB")
    if name == "NodeSight.lua":
        text = edit(text, 'BINDING_HEADER_NODESIGHT = "NodeSight"\nBINDING_NAME_NODESIGHT_SYMBOLS = "Toggle Herb and Ore Symbols"\n'
                          "function NodeSight_ToggleSymbols()",
                    "-- (Clara Combo Points: the binding is Clara's, named in Bootstrap.lua)\n"
                    "function ClaraNodeSight_ToggleSymbols()")
    if name == "WhatsNew.lua":
        text = edit(text, 'C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")', "ns.VERSION")
    if name == "Settings.lua":
        text = edit(text, '    local main, layout = Settings.RegisterVerticalLayoutCategory("NodeSight")',
                    "    -- (Clara Combo Points: under Interface improvements, not a category of its own)\n"
                    "    local main, layout\n"
                    "    if Clara.qolCategory then\n"
                    '        main, layout = Settings.RegisterVerticalLayoutSubcategory(Clara.qolCategory, "NodeSight")\n'
                    "    else\n"
                    '        main, layout = Settings.RegisterVerticalLayoutCategory("NodeSight")\n'
                    "    end")
        text = edit(text, "    Settings.RegisterAddOnCategory(main)\n",
                    "    if not Clara.qolCategory then Settings.RegisterAddOnCategory(main) end\n"
                    "    Clara.nodeSightCategory = main\n")
    with open(os.path.join(out, name), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("wrote", name)
