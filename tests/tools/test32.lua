-- 1.60: items on the rows (from the bags): count, cooldown, buff, weapon enchantment, click
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
S.bags = { [13446] = 5, [13452] = 2, [6947] = 10, [20749] = 1 }
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.Frame(0.1)
local db, sv = ns.db, ns.sv
local function row(side, k)
  for _, f in ipairs(M.frames) do if f._parent == ns.iconLayer and f.side == side and f.k == k then return f end end
end
local function lit(slot) return slot:IsShown() and not slot.icon._desat and slot._alpha == 1 end

out("== from the bags onto a row")
M.cursorItem = 13446; M.Fire("CURSOR_CHANGED")
check(not ns:EditingIcons(), "locked: an item held does not open the rows")
ns:SetIconsLocked(false)
M.Frame(0.1)
local r = row("below", 1)
r.hit._scripts.OnReceiveDrag(r.hit)
check(db.rows.below[1][1] == "item:13446" and M.cursorItem == nil, "unlocked: Major Healing Potion dropped on the first row below")
M.cursorItem = 13452; M.Fire("CURSOR_CHANGED")
r.slots[1]._scripts.OnReceiveDrag(r.slots[1])
check(db.rows.below[1][1] == "item:13452" and db.rows.below[1][2] == "item:13446", "an elixir dropped on the potion: before it")
M.cursorItem = 13446; M.Fire("CURSOR_CHANGED")
r.hit._scripts.OnReceiveDrag(r.hit)
check(#db.rows.below[1] == 2, "the same potion again: refused")
ClearCursor()
M.Frame(0.1)
local elixir, potion = r.slots[1], r.slots[2]
check(potion.icon._file == 134833 and potion.count._text == 5 and lit(potion), "the potion: its icon, 5 carried, lit")
S.bags[13446] = 0; M.Fire("BAG_UPDATE_DELAYED"); M.Frame(0.1)
check(not lit(potion) and potion.count._text == "", "none left: grayed out, no count")
S.bags[13446] = 3; M.now = 50; S.itemCooldowns = { [13446] = { 40, 120 } }
M.Fire("BAG_UPDATE_COOLDOWN"); M.Frame(0.1)
check(lit(potion) and potion.cd._cd and potion.cd._cd[1] == 40 and potion.cd._cd[2] == 120, "drunk: its 2 min cooldown on the swipe")
check(not lit(elixir) or elixir.count._text == 2, "the elixir: 2 carried")
S.auras = { player = { { name = "Elixir of the Mongoose", icon = 134812, applications = 0, duration = 3600, expirationTime = 3000, spellId = 17538 } } }
M.Fire("UNIT_AURA", "player"); M.Frame(0.1)
check(lit(elixir) and elixir.cd._cd and elixir.cd._cd[2] == 3600, "its buff up: the hour on the swipe")
S.bags[13452] = 0; M.Fire("BAG_UPDATE_DELAYED"); M.Frame(0.1)
check(lit(elixir), "none left but the buff up: still lit")
S.auras = nil; S.bags[13452] = 2

out("== a weapon's item: learned when used")
ns:AddIcon("above", 1, "item:6947")
ns:AddIcon("above", 1, "item:99001")
S.bags[99001] = 4
M.Frame(0.1)
local poison, venom = row("above", 1).slots[1], row("above", 1).slots[2]
check(poison.item == 6947 and not poison.imbue, "Instant Poison: not known to enchant weapons yet")
check(venom.item == 99001 and not venom.imbue, "the same for a venom of Forever")
M.now = 100
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 99002)
S.weaponEnchants = { [0] = { { enchantID = 4001, timeLeft = 1800 * 1000, charges = 40, enchantType = 2 } } }
M.Fire("WEAPON_ENCHANT_CHANGED"); M.Frame(0.1)
check(sv.enchantItems[99001] == true and sv.enchantKeys[4001] == "item:99001", "used, an enchantment on the main hand: learned")
check(venom.imbue == "item:99001" and lit(venom) and venom.cd._cd and venom.cd._cd[2] == 1800, "lit with its 30 minutes")
check(not lit(poison) or poison.count._text == 10, "Instant Poison: not that enchantment")
M.now = 200
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 8679)
S.weaponEnchants[1] = { { enchantID = 323, timeLeft = 3600 * 1000, charges = 0, enchantType = 2 } }
M.Fire("WEAPON_ENCHANT_CHANGED"); M.Frame(0.1)
check(sv.enchantKeys[323] == "item:6947" and poison.cd._cd and poison.cd._cd[2] == 3600, "Instant Poison used, on the off hand: its enchantment, its hour")

out("== clicks")
ns:AddIcon("above", 1, "item:20749")
ns:SetIconsLocked(true)
M.Frame(0.1)
ns:SyncClickers()
local byItem = {}
for _, b in ipairs(ns:ClickButtons()) do if b:IsShown() and b.item then byItem[b.item] = b end end
local p = byItem[13446]
check(p and p:GetAttribute("type1") == "item" and p:GetAttribute("item") == "item:13446" and p:GetAttribute("type2") == "item",
  "the potion: used by a click (either button)")
local oil = byItem[20749]
check(oil and oil:GetAttribute("type1") == "macro" and oil:GetAttribute("macrotext") == "/use item:20749\n/use 16"
  and oil:GetAttribute("type2") == "macro" and oil:GetAttribute("macrotext2") == "/use item:20749\n/use 17",
  "the wizard oil (a weapon enhancement): left click on the main hand, right click on the off hand")
local ip = byItem[99001]
check(ip and ip:GetAttribute("macrotext") == "/use item:99001\n/use 16", "the venom, learned: the same")
ip._scripts.OnEnter(ip)
check(GameTooltip._lines and GameTooltip._lines[1] == "item:99001", "its tooltip: the item's")

out("== by link, by name not loaded yet")
local ok = ns:AddIcon("above", 2, "|cffffffff|Hitem:13452::::::::60:::::|h[Elixir of the Mongoose]|h|r")
check(ok and db.rows.above[2][1] == "item:13452", "an item link typed: the item")
S.uncachedItems = { [12404] = true }
local before = M.itemRequests or 0
ns:AddIcon("above", 2, "item:12404")
check((M.itemRequests or 0) > before, "a name not loaded: asked for")
S.uncachedItems = nil
M.Fire("GET_ITEM_INFO_RECEIVED", 12404, true)
check(ns:SpellName("item:12404") == "Dense Sharpening Stone", "arrived: named")

out("== saved and exported as they are")
ns:SaveProfile("ROGUE", "Items")
local text = ns:ExportProfile("ROGUE", "Items")
local ok2, name = ns:ImportProfile("ROGUE", text)
local back = ok2 and sv.saved.ROGUE[name]
check(back and back.rows.below[1][1] == "item:13452" and back.rows.below[1][2] == "item:13446", "exported and imported: the items kept")

out("== items without a use: not taken")
M.ITEMS[2319] = { "Medium Leather", 134257, 7, 6 }   -- a trade good
M.ITEMS[1414] = { "Cutlass", 135321, 2, 7 }          -- a weapon
S.bags[2319], S.bags[1414] = 20, 1
local n = #db.rows.below[1]
for _, id in ipairs({ 2319, 1414 }) do
  M.cursorItem = id; M.Fire("CURSOR_CHANGED")
  local ok = pcall(r.hit._scripts.OnReceiveDrag, r.hit)
  check(ok and #db.rows.below[1] == n and M.cursorItem == id, M.ITEMS[id][1] .. ": not added, no error, still on the cursor")
  ClearCursor()
end
-- one already on a row (put there by an older version): shown, no error
table.insert(db.rows.below[1], "item:2319")
local ok, err = pcall(ns.LayoutIcons, ns)
M.Frame(0.1)
check(ok, "an item without a use already on a row: laid out without error " .. tostring(err))
table.remove(db.rows.below[1])
ns:LayoutIcons()
check(ns:ParseSpell("item:1414") == nil, "typed as item:1414: refused too")

out("== no consumables' lists in the class spells panel")
SlashCmdList.CLARACOMBOPOINTS("")
for _, f in ipairs(M.frames) do if f._kind == "Button" and f.page == 3 and f.name and f.desc then f:Click() end end
local listed = false
for _, r2 in ipairs(M.regions) do
  if r2._kind == "FontString" and type(r2._text) == "string" and r2._text:find("^Consumables") and r2:IsVisible() then listed = true end
end
check(ClaraComboPointsSpells and ClaraComboPointsSpells:IsShown() and not listed, "the panel shows spells only")
SlashCmdList.CLARACOMBOPOINTS("")

out(fails .. " failure(s)")
