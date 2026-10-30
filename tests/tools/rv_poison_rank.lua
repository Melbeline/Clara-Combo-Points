local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.SPELLS[8686] = { "Instant Poison II", 132273, 0 }
M.ITEMS[6949] = { "Instant Poison II", 132273, 0, 0, "Instant Poison II", 8686 }
S.bags = { [6947] = 0, [6949] = 10 }
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.Frame(0.1)
local sv = ns.sv
ns:ClearRow("above", 1)
ns:AddIcon("above", 1, "item:6947") -- Instant Poison (the family's icon)
M.Frame(0.1)
local row
for _, f in ipairs(M.frames) do if f._parent == ns.iconLayer and f.side == "above" and f.k == 1 then row = f end end
local slot = row.slots[1]
out("imbue key: " .. tostring(slot.imbue))
-- Instant Poison II applied from the bags
M.now = 100
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 8686)
S.weaponEnchants = { [0] = { { enchantID = 324, timeLeft = 1800 * 1000, charges = 40, enchantType = 2 } } }
M.Fire("WEAPON_ENCHANT_CHANGED"); M.Frame(0.1)
while M.timers and #M.timers > 0 do M.RunTimer() end
M.Frame(0.1)
out("enchantKeys[324] = " .. tostring(sv.enchantKeys[324]) .. ", family icon swipe = " .. tostring(slot.cd._cd and slot.cd._cd[2]))
