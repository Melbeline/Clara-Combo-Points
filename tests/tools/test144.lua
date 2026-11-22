-- A recipe on the action bars (CraftShortcut.lua): the made item's icon at the top of a recipe dragged → the recipe's
-- macro (this character's; the account's once full) on the cursor, made once, found again by its line; not in a fight
-- unless made; barred and unlearned recipes refused. Its click: crafted at once while its profession is open (one;
-- Shift: as many as the bags allow), else the profession opened and the craft made once ready (within 10 s); a recipe
-- unknown said; a craft the game blocks says click again. Its tooltip: the made item and what a click does.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

-- the game's recipes (Alchemy, 171)
Enum = Enum or {}
Enum.CraftingReagentType = Enum.CraftingReagentType or { Basic = 0, Modifying = 1 }
local recipes = {
  [17187] = { recipeID = 17187, name = "Transmute: Arcanite", icon = 136243, learned = true, line = 171, out = { itemID = 12360, icon = 134459 },
    slots = { { quantityRequired = 1, reagentType = 0, reagents = { { itemID = 12359 } } }, { quantityRequired = 1, reagentType = 0, reagents = { { itemID = 12363 } } } } },
  [3171] = { recipeID = 3171, name = "Élixir de puissance des ténèbres", icon = 136244, learned = true, line = 171, out = { itemID = 9264, icon = 134811 },
    slots = { { quantityRequired = 2, reagentType = 0, reagents = { { itemID = 1 } } } } },
  [999] = { recipeID = 999, name = "Salvage", icon = 1, learned = true, isSalvageRecipe = true, line = 171 },
  [998] = { recipeID = 998, name = "Not yet", icon = 1, learned = false, line = 171 },
  [3275] = { recipeID = 3275, name = "Linen Bandage", icon = 2, learned = true, line = 129, out = { itemID = 1251, icon = 133688 }, slots = {} },
}
local bags = { [12359] = 5, [12363] = 2, [1] = 7 }
C_Item = C_Item or {}
C_Item.GetItemCount = function(id) return bags[id] or 0 end
local open = { base = nil, ready = false, linked = false } -- the profession open
local crafted, opened = {}, {}
C_TradeSkillUI = {
  GetRecipeInfo = function(id) local r = recipes[id]; if r then return r end end,
  GetRecipeOutputItemData = function(id) local r = recipes[id]; return r and r.out or {} end,
  GetRecipeSchematic = function(id) local r = recipes[id]; return { reagentSlotSchematics = r and r.slots or {} } end,
  GetTradeSkillLineForRecipe = function(id) local r = recipes[id]; if r then return r.line, "Line", nil end end,
  IsTradeSkillReady = function() return open.ready end,
  IsTradeSkillLinked = function() return open.linked end,
  IsTradeSkillGuild = function() return false end,
  GetChildProfessionInfo = function() return open.base and { professionID = open.base } or nil end,
  IsRecipeInSkillLine = function(id, line) local r = recipes[id]; return r ~= nil and r.line == line end,
  GetBaseProfessionInfo = function() return open.base and { professionID = open.base } or nil end,
  HasNoReagentCost = function() return false end,
  CraftRecipe = function(id, n) crafted[#crafted + 1] = { id, n } end,
  OpenTradeSkill = function(line) opened[#opened + 1] = line; return true end,
}
-- the game's macros: the account's 1-120, the character's 121-150
local macros = { account = {}, char = {} }
local accountMax, charMax = 120, 30
function GetNumMacros() return #macros.account, #macros.char end
function GetMacroBody(i)
  if i <= 120 then local m = macros.account[i]; return m and m.body end
  local m = macros.char[i - 120]; return m and m.body
end
local created = 0
function CreateMacro(name, icon, body, perCharacter)
  assert(not InCombatLockdown(), "CreateMacro in a fight")
  local list, max = perCharacter and macros.char or macros.account, perCharacter and charMax or accountMax
  if #list >= max then error("Too many macros") end
  list[#list + 1] = { name = name, icon = icon, body = body }
  created = created + 1
  return perCharacter and (120 + #list) or #list
end
local picked
function PickupMacro(i) picked = i end
function GetCursorInfo() return nil end
local said = {}
UIErrorsFrame = { AddMessage = function(_, text) said[#said + 1] = text end }
-- the action bar's tooltip
local actions = {}
function GetActionInfo(slot) local a = actions[slot]; if a then return a[1], a[2] end end
function GameTooltip:SetAction(slot) self._lines = { "macro name" } end
-- the professions window: its recipe's made item icon
local form = { recipe = 17187 }
form.OutputIcon = CreateFrame("Button", nil, UIParent)
function form:GetRecipeInfo() return recipes[self.recipe] end
ProfessionsFrame = { CraftingPage = { SchematicForm = form } }

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
M.Fire("ADDON_LOADED", "Blizzard_Professions")
local now = 1000
GetTime = function() return now end
local function Drag() local fn = form.OutputIcon:GetScript("OnDragStart"); if fn then fn(form.OutputIcon) end end

out("== the icon dragged: the recipe's macro on the cursor")
check(form.OutputIcon:GetScript("OnDragStart") ~= nil, "the made item's icon can be dragged")
Drag()
local m = macros.char[1]
check(m and m.name == "Transmute: Arcan" and m.icon == 134459 and m.body == "/run if ClaraCraft then ClaraCraft(17187) end",
  "a macro of this character: the recipe's name (16 letters), the made item's icon, its line (" .. tostring(m and m.name) .. ")")
check(picked == 121, "on the cursor")
picked = nil
Drag()
check(created == 1 and picked == 121, "dragged again: the same one, not another")
macros.char[1].name = "Arcanite"; macros.char[1].icon = 1
picked = nil; Drag()
check(created == 1 and picked == 121, "renamed in /macro: still found by its line")
form.recipe = 3171; Drag()
check(macros.char[2] and macros.char[2].name == "Élixir de puissa", "an accented name cut on a letter (" .. tostring(macros.char[2] and macros.char[2].name) .. ")")
form.recipe = 999; local before = created; Drag()
check(created == before and said[#said]:find("cannot go on a bar", 1, true), "a salvage recipe: refused, said")
form.recipe = 998; Drag()
check(created == before and said[#said]:find("does not know this recipe yet", 1, true), "not learned: refused")

out("== in a fight")
S.inCombat = true
form.recipe = 3275; picked = nil; Drag()
check(created == before and picked == nil and said[#said]:find("Not in a fight", 1, true), "none made yet: refused, said")
form.recipe = 17187; Drag()
check(picked == 121, "one made already: taken")
S.inCombat = false

out("== the macros full")
for i = #macros.char + 1, charMax do macros.char[i] = { name = "x", body = "/say hi" } end
form.recipe = 3275; Drag()
check(macros.account[1] and macros.account[1].body:find("ClaraCraft(3275)", 1, true) and picked == 1, "the character's full: the account's")
for i = #macros.account + 1, accountMax do macros.account[i] = { name = "x", body = "/say hi" } end
recipes[4000] = { recipeID = 4000, name = "Other", icon = 3, learned = true, line = 129, out = { icon = 5 }, slots = {} }
form.recipe = 4000; local c = created; Drag()
check(created == c and said[#said]:find("No room left", 1, true), "both full: said")

out("== the click: its profession open")
open.base, open.ready = 171, true
M.shift = false
ClaraCraft(17187)
check(#crafted == 1 and crafted[1][1] == 17187 and crafted[1][2] == 1, "one made at once")
M.shift = true
ClaraCraft(17187)
check(crafted[2] and crafted[2][2] == 2, "Shift: as many as the bags allow (5 thorium, 2 crystals: 2)")
ClaraCraft(3171)
check(crafted[3] and crafted[3][2] == 3, "Shift: 7 of 2 a craft: 3")
M.shift = false
bags[12363] = 0; M.shift = true; ClaraCraft(17187); M.shift = false
check(crafted[4] and crafted[4][2] == 1, "Shift with nothing: one asked (the game says what is missing)")
open.linked = true
local n = #crafted
ClaraCraft(17187)
check(#crafted == n and opened[#opened] == 171, "a linked list open: not crafted there, its own opened")
open.linked = false

out("== the click: its profession closed")
open.base, open.ready = nil, false
n = #crafted; opened = {}
ClaraCraft(3275)
check(#crafted == n and opened[1] == 129, "First Aid opened")
M.Fire("TRADE_SKILL_SHOW")
check(#crafted == n, "not ready yet: waits")
open.base, open.ready = 129, true
now = now + 2
M.Fire("TRADE_SKILL_LIST_UPDATE")
check(#crafted == n + 1 and crafted[n + 1][1] == 3275, "ready: made")
M.Fire("TRADE_SKILL_LIST_UPDATE")
check(#crafted == n + 1, "once")
M.Fire("ADDON_ACTION_BLOCKED", "ClaraComboPoints", "C_TradeSkillUI.CraftRecipe()")
check(said[#said]:find("click the shortcut again", 1, true), "the game blocked it: click again, said")
open.base, open.ready = nil, false
ClaraCraft(17187)
now = now + 11
open.base, open.ready = 171, true
M.Fire("TRADE_SKILL_LIST_UPDATE")
check(#crafted == n + 1, "ready too late (over 10 s): not made")
open.base, open.ready = nil, false
ClaraCraft(123456)
check(said[#said]:find("does not know this recipe", 1, true), "a recipe unknown: said")

out("== the shortcut's tooltip")
actions[5] = { "macro", 121 }
GameTooltip:SetAction(5)
local t = table.concat(GameTooltip._lines, " | ")
check(t:find("item:12360", 1, true) and t:find("a click makes one", 1, true), "the made item and what a click does (" .. t .. ")")
actions[6] = { "macro", 125 }
GameTooltip:SetAction(6)
check(table.concat(GameTooltip._lines, " | ") == "macro name", "another macro: left alone")
actions[7] = { "spell", 1 }
GameTooltip:SetAction(7)
check(table.concat(GameTooltip._lines, " | ") == "macro name", "a spell: left alone")
out("== with ClassicUI: its old trade skill window's icon too")
local cui = io.open(ADDON_DIR .. "/Modules/ClassicUI/Skills/TradeSkill.lua", "rb")
if cui then
  local src = cui:read("*a"); cui:close()
  check(src:find("ClaraNS.CraftShortcutDragFrom(iconButton, function() return selected end)", 1, true), "its recipe icon dragged too")
else out("  (no ClassicUI here)") end
out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
