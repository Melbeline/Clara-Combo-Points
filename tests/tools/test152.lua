-- The professions window opened again on the recipe picked last (RecipeMemory.lua): the game's page, shut and opened
-- again, sets its profession up anew (its first recipe picked); the recipe the player picked is picked again and the
-- list scrolled to it; per profession; the game's own picks (as it sets up) not kept; a recipe from a link: the game's;
-- a recipe the list does not show: the game's; through a reload (kept in the saved variables, the character's).
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local callbacks = {}
EventRegistry = { RegisterCallback = function(_, event, fn, owner) callbacks[event] = callbacks[event] or {}; table.insert(callbacks[event], { fn, owner }) end,
  TriggerEvent = function(_, event, ...) for _, c in ipairs(callbacks[event] or {}) do c[1](c[2], ...) end end }
local SELECTED = "ProfessionsRecipeListMixin.Event.OnRecipeSelected"
-- Two professions' recipes, as the list shows them
local recipes = { [185] = { 2538, 2540, 2541, 3370, 3371 }, [197] = { 2385, 2386, 2387 } }
local hidden = {}
local empty = false -- (the game's list before its recipes have come)
C_TradeSkillUI = C_TradeSkillUI or {}
C_TradeSkillUI.GetRecipeInfo = function(id) return { recipeID = id } end
-- The game's page (Blizzard_ProfessionsCrafting): Init picks the first recipe on a new profession, Reset as it shuts
ProfessionsFrame = CreateFrame("Frame", "ProfessionsFrame", UIParent)
local page = CreateFrame("Frame", nil, ProfessionsFrame)
ProfessionsFrame.CraftingPage = page
local list = CreateFrame("Frame", nil, page)
page.RecipeList = list
list.ScrollBox = { ScrollToElementData = function(_, data) list.scrolledTo = data.recipeID end }
function list:ProfessionChanged() self.previousRecipeID = nil end
function list:SelectRecipe(info, scroll)
  local pid = page.professionInfo.professionID
  if empty then return nil end
  for _, id in ipairs(recipes[pid]) do
    if id == info.recipeID and not hidden[id] then
      self.selected = id
      if self.previousRecipeID ~= id then self.previousRecipeID = id; EventRegistry:TriggerEvent(SELECTED, { recipeID = id }, self) end
      if scroll then self.ScrollBox:ScrollToElementData({ recipeID = id }) end
      return { recipeID = id }
    end
  end
end
function page:Init(professionInfo)
  local old = self.professionInfo
  self.professionInfo = professionInfo
  if not old or old.professionID ~= professionInfo.professionID then self.RecipeList:ProfessionChanged() end
  local id = professionInfo.openRecipeID or self.RecipeList.previousRecipeID or recipes[professionInfo.professionID][1]
  self.RecipeList.scrolledTo = nil
  self.RecipeList:SelectRecipe({ recipeID = id }, professionInfo.openRecipeID ~= nil)
end
function page:Reset() self.professionInfo = nil end
local ns = {}
local now = 1000
GetTime = function() return now end
local function Open(pid, link) now = now + 5; page:Init({ professionID = pid, openRecipeID = link }) end
local function Shut() page:Reset(); list.selected = nil; ProfessionsFrame:Show(); ProfessionsFrame:Hide() end
-- the player's pick: a row of the list pressed, then picked
local function Pick(id) now = now + 5; ns.RecipeMemoryClick(); list:SelectRecipe({ recipeID = id }, false) end

C_AddOns = C_AddOns or {}
local isLoaded = C_AddOns.IsAddOnLoaded
C_AddOns.IsAddOnLoaded = function(name) if name == "Blizzard_Professions" then return true, true end return isLoaded and isLoaded(name) end
S.class = "MAGE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
if not ns.RecipeMemoryRestore then out("(no recipe memory in this version)"); out(""); out("0 failure(s)"); return end

out("== the game alone: the first recipe")
Open(185)
check(list.selected == 2538, "opened: the first")
out("== a recipe picked, the window shut and opened again")
Pick(3370)
Shut(); Open(185)
check(list.selected == 3370, "the recipe picked: picked again (" .. tostring(list.selected) .. ")")
check(list.scrolledTo == 3370, "the list scrolled to it")
out("== per profession")
Shut(); Open(197)
check(list.selected == 2385, "another profession, nothing picked there yet: the game's first")
Pick(2387)
Shut(); Open(185)
check(list.selected == 3370, "back to the first: its own")
Shut(); Open(197)
check(list.selected == 2387, "and the other's: its own")
out("== the game's choices")
Shut(); Open(185, 2541)
check(list.selected == 2541, "a recipe from a link: the game's")
Shut(); Open(185)
check(list.selected == 2541, "(the link's recipe shown: the player's choice since)")
Pick(3371); hidden[3371] = true
Shut(); Open(185)
check(list.selected == 2538, "a recipe the list does not show: the game's first")
hidden[3371] = nil
out("== the window opened again by the profession's button: set up first with no recipes yet, then again")
Pick(3370)
Shut()
empty = true; Open(185)
check(list.selected ~= 3370, "(the list empty at first: nothing to pick)")
empty = false; Open(185) -- (the recipes come: the game sets its page up again, the same profession)
check(list.selected == 3370 and list.scrolledTo == 3370, "set up again with its recipes: picked again, scrolled to (" .. tostring(list.selected) .. ")")
Pick(2540); Open(185)
check(list.selected == 2540, "the player's pick since: theirs (not taken back)")
Pick(3371)

out("== through a reload")
M.Fire("PLAYER_ENTERING_WORLD", false, true)
local who
for k in pairs(ClaraComboPointsDB.recipeKept or {}) do who = k end
check(who and ClaraComboPointsDB.recipeKept[who][185] == 3371 and ClaraComboPointsDB.recipeKept[who][197] == 2387, "kept in the saved variables, the character's")
out("== the mouse report (/cl souris)")
local lines = ns:RecipeMemoryReport()
local text = table.concat(lines, "\n")
check(text:find("hooked true", 1, true) and text:find("kept:", 1, true) and text:find("set its page up anew", 1, true)
  and text:find("picked again", 1, true), "what it did, step by step:\n" .. text)
out("")
out(fails .. " failure(s)")
