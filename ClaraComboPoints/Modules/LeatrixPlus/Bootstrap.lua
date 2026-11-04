-- Clara Combo Points - Leatrix Plus, built in (QoL.lua). The first of the module's files: it gives
-- the others their shared table, or none (they then do nothing) when the module does not run:
-- the standalone Leatrix_Plus addon is enabled, the module is turned off, or this is not WoW
-- Forever. While the standalone runs, its settings are carried over (the same table is saved in
-- both addons' files), so turning it off later needs nothing set again.

local ADDON, ns = ...

-- The key bindings (Bindings.xml is read whether the module runs or not)
BINDING_CATEGORY_CLARA_QOL = ns.L.QOL_TITLE
BINDING_NAME_CLARA_LEAPLUS_TOGGLE = "Leatrix Plus: Toggle panel"
BINDING_NAME_CLARA_LEAPLUS_RARE = "Leatrix Plus: Announce rare"
BINDING_NAME_CLARA_LEAPLUS_MOUNTSPECIAL = "Leatrix Plus: Mount special"

if ns:QolRuns("leatrix") then
  -- the table the module's files share (the standalone's own `...` table; not Clara's ns, whose
  -- L it would replace)
  ns.LeatrixPlus = {}
  -- no first-run line in the chat (Clara Combo Points writes nothing there by itself)
  if type(ClaraLeaPlusDB) ~= "table" then ClaraLeaPlusDB = {} end
  if ClaraLeaPlusDB.FirstRunMessageSeen == nil then ClaraLeaPlusDB.FirstRunMessageSeen = true end
elseif ns:QolState("leatrix") == "standalone" then
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if type(LeaPlusDB) ~= "table" then return end
    local mine = type(ClaraLeaPlusDB) == "table" and ClaraLeaPlusDB or nil
    -- the built-in copy's own settings, once used, are kept
    if not mine or next(mine) == nil or mine.__source == "standalone" then
      LeaPlusDB.__source = "standalone" -- (Leatrix ignores keys it does not know)
      ClaraLeaPlusDB = LeaPlusDB
    end
  end)
end

-- Its options: the built-in copy's panel, or the standalone's
-- Its options: its pages in the game's options (SettingsPages.lua; its window one click from there, or /ltp), else
-- its window, else the standalone's
ns:SetQolOpener("leatrix", function()
  if ns.LeatrixPlus and ns.LeatrixPlus.settingsCategory then
    ns:OpenSettingsTo(ns.LeatrixPlus.settingsCategory)
  elseif ns.LeatrixPlus and ns.LeatrixPlus.Open then
    ns.LeatrixPlus.Open()
  elseif SlashCmdList and SlashCmdList["Leatrix_Plus"] then
    SlashCmdList["Leatrix_Plus"]("")
  end
end)
