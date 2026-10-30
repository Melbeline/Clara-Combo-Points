local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
S.bags = { [6947] = 10 }
-- main hand: a poison applied in an earlier session (enchantment 2630, never learned)
S.weaponEnchants = { [0] = { { enchantID = 2630, timeLeft = 1200 * 1000, charges = 60, enchantType = 2 } } }
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.Frame(0.1)
local sv = ns.sv
ns:ClearRow("above", 1)
ns:AddIcon("above", 1, "item:6947") -- Instant Poison
M.Frame(0.1)
-- Instant Poison applied to the off hand (right click)
M.now = 100
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 8679)
S.weaponEnchants[1] = { { enchantID = 323, timeLeft = 1800 * 1000, charges = 40, enchantType = 2 } }
M.Fire("UNIT_INVENTORY_CHANGED", "player"); M.Frame(0.1)
while M.timers and #M.timers > 0 do M.RunTimer() end
M.Frame(0.1)
out("enchantKeys[2630] (main hand's old poison) = " .. tostring(sv.enchantKeys[2630]))
out("enchantKeys[323] (Instant Poison, just applied) = " .. tostring(sv.enchantKeys[323]))
local row
for _, f in ipairs(M.frames) do if f._parent == ns.iconLayer and f.side == "above" and f.k == 1 then row = f end end
local slot = row.slots[1]
out("Instant Poison icon swipe duration = " .. tostring(slot.cd._cd and slot.cd._cd[2]) .. " charges text = " .. tostring(slot.count._text))
