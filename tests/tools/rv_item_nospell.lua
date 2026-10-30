local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.ITEMS[14047] = { "Runecloth", 132903, 7, 5 } -- a trade good: no use spell
S.bags = { [14047] = 20 }
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.Frame(0.1)
ns:SetIconsLocked(false)
M.Frame(0.1)
local r
for _, f in ipairs(M.frames) do if f._parent == ns.iconLayer and f.side == "below" and f.k == 1 then r = f end end
M.cursorItem = 14047; M.Fire("CURSOR_CHANGED")
local ok, err = pcall(r.hit._scripts.OnReceiveDrag, r.hit)
out("drop ok=" .. tostring(ok) .. " err=" .. tostring(err))
out("row: " .. tostring(ns.db.rows.below[1][1]))
local ok2, err2 = pcall(ns.LayoutIcons, ns)
out("next layout ok=" .. tostring(ok2) .. " err=" .. tostring(err2))
