local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local ns = {}
S.class = "WARRIOR"; S.locale = "enUS"
S.bags = { [13446] = 5 }
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.Frame(0.1)
local sv = ns.sv
ns:ClearRow("above", 1)
ns:AddIcon("above", 1, "item:13446") -- Major Healing Potion
M.Frame(0.1)
-- a party shaman's Windfury Totem: its enchantment on the main hand, renewed by each pulse
M.now = 95
S.weaponEnchants = { [0] = { { enchantID = 1783, timeLeft = 10 * 1000, enchantType = 2 } } }
ns:WeaponEnchants() -- (the weapons read: an up to date snapshot)
M.now = 100
S.weaponEnchants[0][1].timeLeft = 5 * 1000
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 17534) -- drinks the potion
M.now = 101
S.weaponEnchants[0][1].timeLeft = 10 * 1000 -- the totem pulses
M.Fire("UNIT_INVENTORY_CHANGED", "player"); M.Frame(0.1)
out("enchantKeys[1783] (Windfury Totem) = " .. tostring(sv.enchantKeys[1783]) .. ", potion now a weapon item: " .. tostring(sv.enchantItems[13446]))
