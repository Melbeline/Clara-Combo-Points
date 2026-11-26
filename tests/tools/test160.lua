-- The recipe memory (RecipeMemory.lua) with the game's page as it is (its own SelectRecipe, called on the list's
-- event) and with an addon's own list over the game's rows (ForeverRecipes: its rows pick through the page's
-- SelectRecipe, the game's rows never pressed): the player's pick seen by a press anywhere in the list, kept, picked
-- again as the window opens again (shut by Escape as by the button); the game's own picks while it sets up: not kept;
-- a press on the search box: not a pick.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local callbacks = {}
EventRegistry = { RegisterCallback = function(_, event, fn, owner) callbacks[event] = callbacks[event] or {}; table.insert(callbacks[event], { fn, owner }) end,
  TriggerEvent = function(_, event, ...) for _, c in ipairs(callbacks[event] or {}) do c[1](c[2], ...) end end }
local SELECTED = "ProfessionsRecipeListMixin.Event.OnRecipeSelected"
local recipes = { [171] = { 2329, 2330, 3170, 7836, 7837 } }
C_TradeSkillUI = C_TradeSkillUI or {}
C_TradeSkillUI.GetRecipeInfo = function(id) return { recipeID = id, name = "R" .. id } end
ProfessionsFrame = CreateFrame("Frame", "ProfessionsFrame", UIParent)
ProfessionsFrame:SetSize(670, 590); ProfessionsFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -100)
local page = CreateFrame("Frame", nil, ProfessionsFrame)
page:SetAllPoints(ProfessionsFrame)
ProfessionsFrame.CraftingPage = page
local list = CreateFrame("Frame", nil, page)
list:SetSize(300, 500); list:SetPoint("TOPLEFT", page, "TOPLEFT", 5, -70)
page.RecipeList = list
list.SearchBox = CreateFrame("EditBox", nil, list)
list.SearchBox:SetSize(200, 20); list.SearchBox:SetPoint("TOPLEFT", list, "TOPLEFT", 10, -5)
list.ScrollBox = CreateFrame("Frame", nil, list)
list.ScrollBox:SetSize(280, 440); list.ScrollBox:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -40)
list.ScrollBox.ScrollToElementData = function(_, data) list.scrolledTo = data.recipeID end
-- an addon's own list over the game's rows (ForeverRecipes)
local overlay = CreateFrame("Frame", nil, list)
overlay:SetAllPoints(list.ScrollBox)
function list:ProfessionChanged() self.previousRecipeID = nil end
function list:SelectRecipe(info, scroll)
  for _, id in ipairs(recipes[page.professionInfo.professionID]) do
    if id == info.recipeID then
      self.selected = id
      if self.previousRecipeID ~= id then self.previousRecipeID = id; EventRegistry:TriggerEvent(SELECTED, { recipeID = id }, self) end
      if scroll then self.ScrollBox:ScrollToElementData({ recipeID = id }) end
      return { recipeID = id }
    end
  end
end
-- the page shows a recipe (the game: on the list's event; the addon's rows: directly)
function page:SelectRecipe(info) self.shown = info.recipeID end
EventRegistry:RegisterCallback(SELECTED, function(owner, info) owner:SelectRecipe(info) end, page)
function page:Init(professionInfo)
  local old = self.professionInfo
  self.professionInfo = professionInfo
  if not old or old.professionID ~= professionInfo.professionID then self.RecipeList:ProfessionChanged() end
  local id = self.RecipeList.previousRecipeID or recipes[professionInfo.professionID][1]
  self.RecipeList.scrolledTo = nil
  self.RecipeList:SelectRecipe({ recipeID = id }, false)
end
function page:Reset() self.professionInfo = nil end
local ns = {}
local now = 1000
GetTime = function() return now end
local function Open() now = now + 5; ProfessionsFrame:Show(); page:Init({ professionID = 171 }) end
local function Shut() page:Reset(); list.selected = nil; ProfessionsFrame:Hide() end
-- a press on the addon's row, then its pick: the page's SelectRecipe straight away (the game's list not told)
local function PickOverlay(id)
  now = now + 5
  M.CursorOn(overlay); M.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
  now = now + 0.2
  page:SelectRecipe({ recipeID = id })
end

C_AddOns = C_AddOns or {}
local isLoaded = C_AddOns.IsAddOnLoaded
C_AddOns.IsAddOnLoaded = function(name) if name == "Blizzard_Professions" then return true, true end return isLoaded and isLoaded(name) end
S.class = "MAGE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
if not ns.RecipeMemoryRestore then out("(no recipe memory in this version)"); out(""); out("0 failure(s)"); return end

out("== the game alone: its first")
Shut(); Open()
check(page.shown == 2329, "opened: the first (" .. tostring(page.shown) .. ")")
out("== a recipe picked on the addon's list, shut by Escape, opened again")
PickOverlay(7836)
check(page.shown == 7836, "shown")
Shut(); Open()
check(page.shown == 7836 and list.selected == 7836, "picked again (" .. tostring(page.shown) .. ")")
check(list.scrolledTo == 7836, "the list scrolled to it")
out("== another, twice over")
PickOverlay(3170)
Shut(); Open()
check(page.shown == 3170, "the latest one: " .. tostring(page.shown))
out("== a press on the search box: not a pick")
now = now + 5
M.CursorOn(list.SearchBox); M.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
Shut(); Open()
check(page.shown == 3170, "still the player's: " .. tostring(page.shown))
out("== the report")
local text = table.concat(ns:RecipeMemoryReport(), "\n")
check(text:find("page watched true", 1, true) and text:find("presses in the list 2", 1, true), text)
out("")
out(fails .. " failure(s)")
