-- A recipe on the action bars (CraftShortcut.lua): the made item's icon at the top of a recipe dragged → the recipe's
-- own spell on the cursor (C_Spell.PickupSpell, as Classic 1.15.9's macro), no macro made; something held let go
-- first; not in a fight; barred and unlearned recipes refused; a pickup the game refuses said. The first version's
-- macros (/run ClaraCraft(...)) deleted at login, out of a fight (else once it ends), the others kept, the count said.
-- With ClassicUI, its old trade skill window's icon dragged too.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

-- the game's recipes
local recipes = {
  [17187] = { recipeID = 17187, name = "Transmute: Arcanite", learned = true },
  [999] = { recipeID = 999, name = "Salvage", learned = true, isSalvageRecipe = true },
  [998] = { recipeID = 998, name = "Not yet", learned = false },
  [3275] = { recipeID = 3275, name = "Linen Bandage", learned = true },
}
C_TradeSkillUI = { GetRecipeInfo = function(id) return recipes[id] end }
-- the cursor and the game's pickup
local cursor, refuse, picks, cleared = nil, false, {}, 0
function GetCursorInfo() if cursor then return cursor[1], cursor[2], cursor[3], cursor[4] end end
function ClearCursor() cursor = nil; cleared = cleared + 1 end
C_Spell = C_Spell or {}
C_Spell.PickupSpell = function(id)
  picks[#picks + 1] = id
  if not refuse then cursor = { "spell", 1, "spell", id } end
end
local made = 0
function CreateMacro() made = made + 1 end
local said = {}
UIErrorsFrame = { AddMessage = function(_, text) said[#said + 1] = text end }
-- the first version's macros, among others: the account's 1-120, the character's 121-150
local macros = {
  account = { { body = "/say hello" }, { body = "/run if ClaraCraft then ClaraCraft(3275) end" } },
  char = { { body = "/run if ClaraCraft then ClaraCraft(17187) end" }, { body = "/cast Stealth" }, { body = "/run if ClaraCraft then ClaraCraft(3171) end" } },
}
function GetNumMacros() return #macros.account, #macros.char end
function GetMacroBody(i)
  local m = i <= 120 and macros.account[i] or macros.char[i - 120]
  return m and m.body
end
local deletedInFight = false
function DeleteMacro(i)
  if InCombatLockdown() then deletedInFight = true end
  if i <= 120 then table.remove(macros.account, i) else table.remove(macros.char, i - 120) end
end
-- the professions window: its recipe's made item icon
local form = { recipe = 17187 }
form.OutputIcon = CreateFrame("Button", nil, UIParent)
function form:GetRecipeInfo() return recipes[self.recipe] end
ProfessionsFrame = { CraftingPage = { SchematicForm = form } }

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
local chat = {}
local oldAdd = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(self, text, ...) chat[#chat + 1] = text; if oldAdd then return oldAdd(self, text, ...) end end
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
M.Fire("ADDON_LOADED", "Blizzard_Professions")
local function Run() while M.timers and #M.timers > 0 do M.RunTimer() end end
local function Drag() local fn = form.OutputIcon:GetScript("OnDragStart"); if fn then fn(form.OutputIcon) end end

out("== the icon dragged: the recipe's own spell on the cursor")
check(form.OutputIcon:GetScript("OnDragStart") ~= nil, "the made item's icon can be dragged")
Drag()
check(picks[1] == 17187 and cursor and cursor[1] == "spell" and cursor[4] == 17187, "C_Spell.PickupSpell(17187): the recipe on the cursor")
check(made == 0, "no macro made")
check(rawget(_G, "ClaraCraft") == nil, "no ClaraCraft any more")
cursor = { "item", 6948 }
form.recipe = 3275; Drag()
check(cleared == 1 and cursor[4] == 3275, "something held: let go, then the recipe")
cursor = nil
local n = #picks
form.recipe = 999; Drag()
check(#picks == n and said[#said]:find("cannot go on a bar", 1, true), "a salvage recipe: refused, said")
form.recipe = 998; Drag()
check(#picks == n and said[#said]:find("does not know this recipe yet", 1, true), "not learned: refused")
S.inCombat = true
form.recipe = 17187; Drag()
check(#picks == n and cursor == nil and said[#said]:find("Not in a fight", 1, true), "in a fight: refused, said")
S.inCombat = false
refuse = true; Drag(); refuse = false
check(#picks == n + 1 and said[#said]:find("did not put this recipe", 1, true), "the game refusing it: said")

out("== the first version's macros")
S.inCombat = true
M.Fire("PLAYER_ENTERING_WORLD"); Run()
check(#macros.char == 3 and #macros.account == 2 and not deletedInFight, "in a fight at login: kept until it ends")
S.inCombat = false
M.Fire("PLAYER_REGEN_ENABLED")
check(#macros.char == 1 and macros.char[1].body == "/cast Stealth", "the character's: deleted, its other macro kept")
check(#macros.account == 1 and macros.account[1].body == "/say hello", "the account's: deleted, its other kept")
local line = chat[#chat] or ""
check(line:find("3 macro(s) of the first recipe shortcuts deleted", 1, true), "the chat says how many (" .. line .. ")")
local c = #chat
M.Fire("PLAYER_REGEN_ENABLED")
check(#chat == c, "once")

out("== with ClassicUI: its old trade skill window's icon too")
local cui = io.open(ADDON_DIR .. "/Modules/ClassicUI/Skills/TradeSkill.lua", "rb")
if cui then
  local src = cui:read("*a"); cui:close()
  check(src:find("ClaraNS.CraftShortcutDragFrom(iconButton, function() return selected end)", 1, true), "its recipe icon dragged too")
else out("  (no ClassicUI here)") end
out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
