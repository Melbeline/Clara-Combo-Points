-- The professions window's recipe kept (RecipeMemory.lua) forgotten at a new login (not a reload): the game's first
-- recipe as the window opens again.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local callbacks = {}
EventRegistry = { RegisterCallback = function(_, event, fn, owner) callbacks[event] = callbacks[event] or {}; table.insert(callbacks[event], { fn, owner }) end,
  TriggerEvent = function(_, event, ...) for _, c in ipairs(callbacks[event] or {}) do c[1](c[2], ...) end end }
local SELECTED = "ProfessionsRecipeListMixin.Event.OnRecipeSelected"
local recipes = { 2538, 2540, 3370 }
C_TradeSkillUI = C_TradeSkillUI or {}
C_TradeSkillUI.GetRecipeInfo = function(id) return { recipeID = id } end
ProfessionsFrame = CreateFrame("Frame", "ProfessionsFrame", UIParent)
local page = CreateFrame("Frame", nil, ProfessionsFrame)
ProfessionsFrame.CraftingPage = page
local list = CreateFrame("Frame", nil, page)
page.RecipeList = list
list.ScrollBox = { ScrollToElementData = function() end }
function list:ProfessionChanged() self.previousRecipeID = nil end
function list:SelectRecipe(info)
  for _, id in ipairs(recipes) do
    if id == info.recipeID then
      self.selected = id
      if self.previousRecipeID ~= id then self.previousRecipeID = id; EventRegistry:TriggerEvent(SELECTED, { recipeID = id }, self) end
      return { recipeID = id }
    end
  end
end
function page:Init(info)
  local old = self.professionInfo
  self.professionInfo = info
  if not old then self.RecipeList:ProfessionChanged() end
  self.RecipeList:SelectRecipe({ recipeID = self.RecipeList.previousRecipeID or recipes[1] })
end
C_AddOns = C_AddOns or {}
local isLoaded = C_AddOns.IsAddOnLoaded
C_AddOns.IsAddOnLoaded = function(name) if name == "Blizzard_Professions" then return true, true end return isLoaded and isLoaded(name) end
local ns = {}
S.class = "MAGE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
if not ns.RecipeMemoryRestore then out("(no recipe memory in this version)"); out(""); out("0 failure(s)"); return end
page:Init({ professionID = 171 })
list:SelectRecipe({ recipeID = 3370 })
local who
for k in pairs(ClaraComboPointsDB.recipeKept or {}) do who = k end
check(who and ClaraComboPointsDB.recipeKept[who][171] == 3370, "a recipe kept")
M.Fire("PLAYER_ENTERING_WORLD", true, false) -- (a new login)
check(next(ClaraComboPointsDB.recipeKept[who]) == nil, "a new login: forgotten")
page.professionInfo = nil; ProfessionsFrame:Hide()
page:Init({ professionID = 171 })
check(list.selected == 2538, "opened again: the game's first")
out("")
out(fails .. " failure(s)")
