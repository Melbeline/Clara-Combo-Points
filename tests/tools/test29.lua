-- 1.60: mana about to be spent, weapon imbues, Windfury's internal cooldown
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function rect(r) M.ResetLayout(); local l, b, w, h = M.Rect(r); return l, b, w, h end
local function near(a, b) return math.abs(a - b) < 0.6 end

local ns = {}
S.class = "SHAMAN"; S.locale = "enUS"; S.mana, S.manaMax = 800, 1000; S.powerType = 0
S.manaCosts = { [403] = 100, [331] = 250 }
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.Frame(0.1)

out("== mana about to be spent")
local mana = ns.manaBar
local clip
for _, f in ipairs(M.frames) do if f._parent == mana and f._clips then clip = f end end
local tex
for _, r in ipairs(M.regions) do if clip and r._parent and r._parent._parent == clip then tex = r end end
check(clip ~= nil and tex ~= nil, "a clipped marker on the mana bar")
check(clip and not clip:IsShown(), "nothing marked while nothing is cast")
local function width() if not clip:IsShown() then return 0 end local _, _, w = rect(tex); return w end
local barW = ns.db.bars.mana.width
S.casting = 403; M.Fire("UNIT_SPELLCAST_START", "player")
check(near(width(), barW * 100 / 1000), "Lightning Bolt: 100 of 1000 mana marked (" .. width() .. ")")
local ml, _, mw = rect(mana:GetStatusBarTexture())
local tl, _, tw = rect(tex)
check(near(tl + tw, ml + mw), "the marker ends at the end of the fill")
S.casting = nil; M.Fire("UNIT_SPELLCAST_STOP", "player")
check(width() == 0, "cast over: gone")
S.casting = 331; M.Fire("UNIT_SPELLCAST_START", "player")
check(near(width(), barW * .25), "Healing Wave: 250 marked")
S.casting = nil; M.Fire("UNIT_SPELLCAST_INTERRUPTED", "player")
check(width() == 0, "interrupted: gone")
S.casting = 8042; M.Fire("UNIT_SPELLCAST_START", "player")
check(width() == 0, "a spell with no mana cost marks nothing")
S.casting = nil; M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 8042)

ns:SetElementOn("manaCost", false)
S.casting = 403; M.Fire("UNIT_SPELLCAST_START", "player")
check(width() == 0 and ns.db.predictMana == false, "turned off: nothing marked")
ns:SetElementOn("manaCost", true)
check(near(width(), barW * .1), "turned back on during the cast: marked")
S.casting = nil; M.Fire("UNIT_SPELLCAST_STOP", "player")
ns.db.colors.manaCost = { r = 0, g = 1, b = 0, a = .5 }
ns:ApplyColors()
check(tex._color and tex._color[2] == 1 and tex._color[4] == .5, "its own colour")

-- the Bars page lists it under the mana bar, with its box
ns:ToggleOptions()
for _, f in ipairs(M.frames) do
  if f._kind == "Button" and f.page == 2 and f.name and f.desc and f:IsVisible() then f:Click() end
end
local function colorRow(text)
  for _, f in ipairs(M.frames) do
    if f.on and f.swatch and f.slider and f.label and f.label._text == text and f:IsVisible() then return f end
  end
end
local row = colorRow("Mana about to be spent")
check(row ~= nil and row.on:IsVisible(), "Bars page, mana bar: its colour line, with a box")
local hint
for _, r in ipairs(M.regions) do
  if r._kind == "FontString" and r._text == "Spells with a cast time, while they are cast" and r:IsVisible() then hint = r end
end
check(hint ~= nil, "and which spells it counts")
row.on.check:Click()
check(ns.db.predictMana == false, "its box turns it off")
row.on.check:Click()
check(ns.db.predictMana == true, "and on")
ns:ToggleOptions()


out("== weapon imbues")
local sv = ns.sv
ns:ClearRow("above", 1)
check(ns:AddIcon("above", 1, 8017) ~= false and ns:AddIcon("above", 1, 8232) ~= false and ns:AddIcon("above", 1, 8024) ~= false,
  "Rockbiter, Windfury and Flametongue Weapon on the HUD")
M.Frame(0.1)
local row
for _, f in ipairs(M.frames) do if f._parent == ns.iconLayer and f.side == "above" and f.k == 1 then row = f end end
local rock, wind, flame = row.slots[1], row.slots[2], row.slots[3]
local function lit(slot) return slot:IsShown() and not slot.icon._desat and slot._alpha == 1 end
check(rock.imbue and wind.imbue and flame.imbue, "they watch weapon enchantments")
check(not lit(rock) and not lit(wind) and rock:IsShown(), "no enchantment: grayed out")
M.now = 100
S.weaponEnchants = { [0] = { { enchantID = 29, timeLeft = 3600 * 1000 } } }
M.Fire("WEAPON_ENCHANT_CHANGED"); M.Frame(0.1)
check(lit(rock) and not lit(wind), "Classic's Rockbiter enchantment on the main hand: Rockbiter lit")
check(rock.cd._cd and math.abs(rock.cd._cd[1] - 100) < 0.2 and rock.cd._cd[2] == 3600, "its 60 minutes on the swipe")
M.now = 700
S.weaponEnchants[0][1].timeLeft = 3000 * 1000
M.Fire("UNIT_INVENTORY_CHANGED", "player"); M.Frame(0.1)
check(rock.cd._cd and math.abs(rock.cd._cd[1] - 100) < 0.2 and rock.cd._cd[2] == 3600, "ten minutes later: the same swipe (full time remembered)")

-- an enchantment this client gives another ID: learned from the cast
M.now = 800
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 8232)
S.weaponEnchants[1] = { { enchantID = 7777, timeLeft = 3600 * 1000 } }
M.Fire("WEAPON_ENCHANT_CHANGED"); M.Frame(0.1)
check(sv.enchantKeys[7777] == "imbue:windfury weapon" and lit(wind), "Windfury Weapon cast, a new enchantment on the off hand: learned, lit")
check(lit(rock) and not lit(flame), "Rockbiter still lit, Flametongue not")
-- recast on the same enchantment: renewed, nothing else learned
M.now = 900
S.weaponEnchants[1][1].timeLeft = 3500 * 1000
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 8024)
M.Frame(0.1)
check(sv.enchantKeys[7777] == "imbue:windfury weapon", "an unrelated cast with no new enchantment learns nothing")
-- an enchantment matched by its icon
S.weaponEnchants[0] = { { enchantID = 5555, timeLeft = 600 * 1000, enchantIconID = 135814 } }
M.Fire("WEAPON_ENCHANT_CHANGED"); M.Frame(0.1)
check(lit(flame) and not lit(rock), "an unknown enchantment with Flametongue's icon: Flametongue lit, Rockbiter gone")
S.weaponEnchants[0] = { { enchantID = 29, timeLeft = 3600 * 1000, charges = 0 } }
M.Fire("WEAPON_ENCHANT_CHANGED"); M.Frame(0.1)

out("== Windfury's internal cooldown")
M.now = 1000
local before = wind.cd._cd and wind.cd._cd[2]
M.Fire("PLAYER_SWING", 2.6, 1)
M.now = 1000.2
M.Fire("PLAYER_SWING", 2.6, 1); M.Frame(0.1)
check(wind.cd._cd and math.abs(wind.cd._cd[1] - 1000.2) < 0.01 and wind.cd._cd[2] == 1.5, "two off-hand swings 0.2 s apart (Windfury there): 1.5 s swipe")
check(lit(wind), "still lit")
M.now = 1001
M.Fire("PLAYER_SWING", 2.6, 1)
M.now = 1001.1
M.Fire("PLAYER_SWING", 2.6, 1); M.Frame(0.1)
check(math.abs(wind.cd._cd[1] - 1000.2) < 0.01, "another extra attack during the cooldown does not restart it")
M.now = 1003.3
while M.timers and #M.timers > 0 do M.RunTimer() end
M.Frame(0.1)
check(wind.cd._cd and wind.cd._cd[2] == before, "over: back to the enchantment's time left")
M.now = 1010
M.Fire("PLAYER_SWING", 3.6, 0)
M.now = 1010.2
M.Fire("PLAYER_SWING", 3.6, 0); M.Frame(0.1)
check(wind.cd._cd[2] ~= 1.5, "a double swing of the main hand (Rockbiter there) is not Windfury")
M.now = 1020
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "proc", 8233); M.Frame(0.1)
check(wind.cd._cd and math.abs(wind.cd._cd[1] - 1020) < 0.01 and wind.cd._cd[2] == 1.5, "Windfury Weapon's proc spell seen: 1.5 s swipe")

out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
