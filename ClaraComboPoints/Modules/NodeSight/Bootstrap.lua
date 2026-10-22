-- Clara Combo Points - NodeSight 1.4.0 (by Krelock), built in (QoL.lua): what every herb and ore
-- on the minimap is, an arrow to the nearest one, sparkles on it when close. The first of the
-- module's files: it gives the others their shared table, or none (they then do nothing) when
-- the module does not run. Its settings are saved in ClaraNodeSightDB; its pages in the game's
-- options sit under Interface improvements. While the standalone NodeSight runs instead, its
-- settings are copied at login and logout, so turning it off later needs nothing set again.

local ADDON, ns = ...

-- the key binding (Bindings.xml is read whether the module runs or not)
BINDING_NAME_CLARA_NODESIGHT_SYMBOLS = "NodeSight: Toggle Herb and Ore Symbols"

if ns:QolRuns("nodesight") then
  -- the table the module's files share (the standalone's own `...` table)
  ns.NodeSight = { VERSION = "1.4.0" }
elseif ns:QolState("nodesight") == "standalone" then
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:RegisterEvent("PLAYER_LOGOUT")
  f:SetScript("OnEvent", function()
    if type(_G.NodeSightDB) == "table" then ClaraNodeSightDB = CopyTable(_G.NodeSightDB) end
  end)
end

-- Its main switches, on its page of Clara's options window (Improvements tab)
local N = ns.NodeSight
if N then
  local function Scanner() if N.UpdateScanner then N.UpdateScanner() end end
  local function Sparkles() -- (as its own boxes: the sparkles need some of the game's settings)
    if N.UpdateAll then N.UpdateAll() end
    if N.Setup then N.Setup() end
  end
  local function Switch(label, key, apply)
    return {
      label = label,
      get = function() return N.db and N.db[key] and true or false end,
      set = function(on)
        if not N.db then return end
        N.db[key] = on and true or false
        apply()
      end,
    }
  end
  ns:SetQolSwitches("nodesight", {
    Switch("NS_SW_SCAN", "scan", Scanner),
    Switch("NS_SW_SYMBOLS", "mapIcons", Scanner),
    Switch("NS_SW_ARROW", "arrow", Scanner),
    Switch("NS_SW_HERBS", "herbs", Sparkles),
    Switch("NS_SW_ORE", "ore", Sparkles),
  })
end

-- Its options: its pages in the game's options (the standalone's: its own category)
ns:SetQolOpener("nodesight", function() ns:OpenSettingsTo(ns.nodeSightCategory or "NodeSight") end)
