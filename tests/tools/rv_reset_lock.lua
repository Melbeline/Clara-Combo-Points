local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.Frame(0.1)
ns:SetLocked(false)
out("unlocked: locked=" .. tostring(ns.db.locked) .. " iconsLocked=" .. tostring(ns.db.iconsLocked))
ns:ResetAll()
out("after Reset (this tab): locked=" .. tostring(ns.db.locked) .. " iconsLocked=" .. tostring(ns.db.iconsLocked)
  .. " editing rows=" .. tostring(ns:EditingIcons()) .. " AllLocked=" .. tostring(ns:AllLocked()))
