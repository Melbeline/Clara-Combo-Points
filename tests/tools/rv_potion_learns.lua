local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
S.bags = { [13446] = 5, [6947] = 10 }
-- a poison already on the main hand (applied from the bags earlier)
S.weaponEnchants = { [0] = { { enchantID = 323, timeLeft = 1700 * 1000, charges = 30, enchantType = 2 } } }
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.Frame(0.1)
local sv = ns.sv
ns:ClearRow("above", 1)
ns:AddIcon("above", 1, "item:13446")   -- Major Healing Potion only
M.Frame(0.1)
M.now = 100
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 17534) -- drinks the potion
M.now = 100.5
while M.timers and #M.timers > 0 do M.RunTimer() end
M.Frame(0.1)
out("enchantKeys[323] = " .. tostring(sv.enchantKeys[323]))
out("enchantItems[13446] = " .. tostring(sv.enchantItems[13446]))
local row
for _, f in ipairs(M.frames) do if f._parent == ns.iconLayer and f.side == "above" and f.k == 1 then row = f end end
local slot = row.slots[1]
out("potion slot.imbue = " .. tostring(slot.imbue) .. " cd=" .. tostring(slot.cd._cd and slot.cd._cd[2]))
-- now put Instant Poison on the row: is the poison's enchantment still shown on it?
ns:AddIcon("above", 1, "item:6947")
M.Frame(0.1)
local poison = row.slots[2]
out("poison imbue=" .. tostring(poison.imbue) .. " lit=" .. tostring(not poison.icon._desat) .. " cd=" .. tostring(poison.cd._cd and poison.cd._cd[2]))
ns:SetIconsLocked(true); M.Frame(0.1); ns:SyncClickers()
for _, b in ipairs(ns:ClickButtons()) do if b:IsShown() and b.item == 13446 then out("potion click type1=" .. tostring(b:GetAttribute("type1")) .. " macro=" .. tostring(b:GetAttribute("macrotext"))) end end
