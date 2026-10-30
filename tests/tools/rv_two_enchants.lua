local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local ns = {}
S.class = "SHAMAN"; S.locale = "enUS"; S.mana, S.manaMax = 800, 1000; S.powerType = 0
S.bags = { [12404] = 3 }
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.Frame(0.1)
local sv = ns.sv
ns:ClearRow("above", 1)
ns:AddIcon("above", 1, 8017)        -- Rockbiter Weapon
ns:AddIcon("above", 1, "item:12404") -- Dense Sharpening Stone
M.now = 100
-- main hand: a sharpening stone (applied earlier, enchantment 1643) and Rockbiter (29)
S.weaponEnchants = { [0] = {
  { enchantID = 1643, timeLeft = 1500 * 1000, enchantType = 2 },
  { enchantID = 29, timeLeft = 200 * 1000, enchantType = 3 } } }
M.Fire("WEAPON_ENCHANT_CHANGED"); M.Frame(0.1)
local row
for _, f in ipairs(M.frames) do if f._parent == ns.iconLayer and f.side == "above" and f.k == 1 then row = f end end
local rock, stone = row.slots[1], row.slots[2]
out("before: rock cd=" .. tostring(rock.cd._cd and rock.cd._cd[2]) .. " stone imbue=" .. tostring(stone.imbue) .. " stone cd=" .. tostring(stone.cd._cd and stone.cd._cd[2]))
-- Rockbiter recast (renewed to its full time)
M.now = 110
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 8017)
S.weaponEnchants[0][2].timeLeft = 300 * 1000
S.weaponEnchants[0][1].timeLeft = 1490 * 1000
M.Fire("WEAPON_ENCHANT_CHANGED"); M.Frame(0.1)
out("enchantKeys[1643] = " .. tostring(sv.enchantKeys[1643]))
-- the stone stays, Rockbiter wears off
M.now = 500
S.weaponEnchants[0] = { { enchantID = 1643, timeLeft = 1100 * 1000, enchantType = 2 } }
M.Fire("WEAPON_ENCHANT_CHANGED"); M.Frame(0.1)
local function lit(slot) return slot:IsShown() and not slot.icon._desat and slot._alpha == 1 end
out("after Rockbiter wore off: rock lit=" .. tostring(lit(rock)) .. " rock cd=" .. tostring(rock.cd._cd and rock.cd._cd[2]))
out("stone shows its enchant: " .. tostring(stone.cd._cd and stone.cd._cd[2]))
