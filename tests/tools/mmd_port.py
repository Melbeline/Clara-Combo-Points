# MinimapDrawer into Clara Combo Points: python3 -I mmd_port.py <MinimapDrawer dir> <ClaraComboPoints dir>
import os, sys
src, dst = sys.argv[1], sys.argv[2]
out = os.path.join(dst, "Modules", "MinimapDrawer")
os.makedirs(out, exist_ok=True)
text = open(os.path.join(src, "MinimapDrawer.lua"), encoding="utf-8").read()

def edit(old, new, count=1):
    global text
    n = text.count(old)
    if n != count:
        sys.exit(f"edit found {n} times, wanted {count}: {old[:70]!r}")
    text = text.replace(old, new)

edit('local ADDON_NAME = ...\n',
     'local _, ClaraNS = ... -- (Clara Combo Points: MinimapDrawer built in, QoL.lua)\n'
     'if not (type(ClaraNS) == "table" and ClaraNS.MinimapDrawerRuns) then return end\n'
     'local ADDON_NAME = "ClaraComboPoints" -- (its settings load with Clara\'s: ClaraMinimapDrawerDB)\n')
edit('    MinimapDrawerDB = MinimapDrawerDB or {}\n    DB = MinimapDrawerDB\n',
     '    ClaraMinimapDrawerDB = ClaraMinimapDrawerDB or {}\n    DB = ClaraMinimapDrawerDB\n')
# the frames' own methods, from a frame (the same in the game; also with test stand-ins)
edit("""local FrameAPI = getmetatable(CreateFrame("Frame")).__index
local rawSetPoint, rawClearAllPoints = FrameAPI.SetPoint, FrameAPI.ClearAllPoints""",
     """local FrameProbe = CreateFrame("Frame") -- (Clara Combo Points: its methods, as the metatable's)
local rawSetPoint, rawClearAllPoints = FrameProbe.SetPoint, FrameProbe.ClearAllPoints""")
# Clara's own /rl
edit('-- /rl : raccourci de /reload (natif, non désactivable)\n'
     'SLASH_MINIMAPDRAWERRELOAD1 = "/rl"\n'
     'SlashCmdList["MINIMAPDRAWERRELOAD"] = function() ReloadUI() end\n',
     '-- (Clara Combo Points: /rl is Clara\'s own)\n')
# by default, on the level circle itself: the game's player frame, or ClassicUI's
edit('''    else
        local x, y = DefaultHotspotPosition()
        hotspot:SetSize(DEFAULT_HOTSPOT_SIZE, DEFAULT_HOTSPOT_SIZE)
        hotspot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    end''', '''    else
        hotspot:SetSize(DEFAULT_HOTSPOT_SIZE, DEFAULT_HOTSPOT_SIZE)
        -- (Clara Combo Points: on the level circle itself, wherever the player frame in use puts it)
        local region = FindLevelRegion()
        if region then
            hotspot:SetPoint("CENTER", region, "CENTER")
        else
            local x, y = DefaultHotspotPosition()
            hotspot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        end
    end''')
# built in: ready at once, no move mode nor chat lines the first time
edit('''    if firstRun then
        SetUnlocked(true)
        Print(L("first1"))
        Print(L("first2"))
    end''', '''    -- (Clara Combo Points: built in, it starts on the level circle, locked and quiet)''')
# never placed by hand: the drawer beside the hotspot, wherever that stands (frozen only once moved)
edit('''    if not (DB.menuPos and DB.menuPos.x and DB.menuPos.y) then
        -- Premier lancement ou migration d'une ancienne version : on part de la position
        -- que le menu avait par rapport à la zone, puis on la fige.
        local hx, hy = HotspotCenter()
        DB.menuPos = {
            x = Round2(hx + (DB.menuX or DEFAULTS.menuX)),
            y = Round2(hy + (DB.menuY or DEFAULTS.menuY)),
        }
    end''', '''    if not (DB.menuPos and DB.menuPos.x and DB.menuPos.y) then
        -- (Clara Combo Points: never moved by hand, it stays beside the hotspot, wherever that stands)
        menu:ClearAllPoints()
        menu:SetPoint("BOTTOMRIGHT", hotspot, "CENTER", DB.menuX or DEFAULTS.menuX, DB.menuY or DEFAULTS.menuY)
        return
    end''')
text = text.rstrip("\n") + '''

-- (Clara Combo Points: its settings and its drawer, for the Improvements tab: Glue.lua)
ClaraNS.MinimapDrawerSettings = function() return DB end
ClaraNS.MinimapDrawerToggle = function() if DB then Toggle() end end
ClaraNS.MinimapDrawerCancelHover = CancelHover
'''
open(os.path.join(out, "MinimapDrawer.lua"), "w", encoding="utf-8").write(text)
print("ok", out)
