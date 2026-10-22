-- Clara Combo Points - DynamicCam 2.21.5 (by mpstark and LudiusMaximus, MIT: LICENSE), built in
-- (QoL.lua). The first of the module's files: it tells the others (and their libraries) whether
-- they run, and gives them their shared table. They run only when the module does: in WoW Forever,
-- not turned off, and the standalone DynamicCam not enabled (that one runs instead: its settings
-- are copied at login and logout, so turning it off later needs nothing set again). Its settings
-- are saved in ClaraDynamicCamDB; its page in the game's options sits under Interface
-- improvements. Glue.lua (the last file) holds the one-click camera box.

local ADDON, ns = ...

ns.DynamicCamRuns = ns:QolRuns("dynamiccam")
if ns.DynamicCamRuns then
  ns.DynamicCamPrivate = {} -- (the standalone's own `...` table)
elseif ns:QolState("dynamiccam") == "standalone" then
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:RegisterEvent("PLAYER_LOGOUT")
  f:SetScript("OnEvent", function()
    if type(_G.DynamicCamDB) == "table" then ClaraDynamicCamDB = CopyTable(_G.DynamicCamDB) end
  end)
end
