-- Well Fed: in the General tab of the class spells, and lit by any food's buff (every one is named Well Fed)
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function lit(f) return f:IsShown() and not f.icon._desat and f._alpha == 1 end

M.SPELLS[19705] = { "Well Fed", 136000 }
local ns = {}
S.class = "HUNTER"; S.locale = "enUS"; S.powerType = 0
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.now = 100

local general
for _, group in ipairs(ns.SPELL_CATALOG) do if group.class == "GENERAL" then general = group end end
local entry
for _, spell in ipairs(general and general.spells or {}) do if spell[2] == 19705 then entry = spell end end
check(entry and entry[1] == "BUFF" and #entry == 2 and entry.alt and entry.alt[1] == 24799, "the General tab lists Well Fed: a buff, one entry (no ranks to pick)")
check(ns.SPELL_NAMES[19705] and ns.SPELL_NAMES[19705][1] == "Well Fed" and ns.SPELL_NAMES[19705][2] == "Bien nourri", "its names: Well Fed, Bien nourri")
local rec = ns:CatalogRecord("well fed")
check(rec and rec.class == "GENERAL" and rec.kind == "BUFF" and #rec.ranks == 1, "found by its name in the class spells")
check(ns:SpellByName("Well Fed") == 19705, "typed by name: Well Fed")

local function slotsOf(side, k)
  local list = {}
  for _, f in ipairs(M.frames) do
    if f.cd and f.spell ~= nil and f:GetParent() and f:GetParent().spells == ns.db.rows[side][k] then list[#list + 1] = f end
  end
  return list
end
ns.db.rows.above[1] = { 19705 }
ns:LayoutIcons(); M.Frame(0.016)
local icon = slotsOf("above", 1)[1]
check(icon and not lit(icon), "on the bar, no food: waiting (grey)")
for _, food in ipairs({ { 19709, "a food of another spell ID (+8 Stamina and Spirit)" }, { 24799, "Smoked Desert Dumplings (+20 Strength)" },
    { 25661, "a spell the catalog does not list" } }) do
  S.auras = { player = { { name = "Well Fed", icon = 136000, duration = 900, expirationTime = 1000, spellId = food[1] } } }
  M.Fire("UNIT_AURA", "player"); M.Frame(0.016)
  check(lit(icon), "lit by " .. food[2])
end
S.auras = { player = { { name = "Food", icon = 133945, duration = 30, expirationTime = 130, spellId = 433 } } }
M.Fire("UNIT_AURA", "player"); M.Frame(0.016)
check(not lit(icon), "still eating (Food), not yet Well Fed: grey")
S.auras = nil
M.Fire("UNIT_AURA", "player"); M.Frame(0.016)
check(not lit(icon), "gone: grey again")
-- the class spells panel, Show only known spells ticked: Well Fed still listed (every character has it)
ns:ShowOptions(); M.Frame(0.016)
local catalog = _G.ClaraComboPointsSpells
catalog:Show(); M.Frame(0.016)
if not ns.sv.catalog.knownOnly then catalog.knownOnly.check:Click() end
M.Frame(0.016)
local general
for _, g in ipairs(catalog.groups) do if g.class == "GENERAL" then general = g end end
check(general and general.head:IsShown() and general.count._text == "1" and general.head.sign._file == "Interface\\Buttons\\UI-MinusButton-Up",
  "Show only known spells: General unfolded, Well Fed counted as known (" .. tostring(general and general.count._text) .. ")")
check(rec.everyone == true, "marked as every character's")
out("")
out(fails .. " failure(s)")
