-- Clara Combo Points - the professions window opened again on the recipe picked last: the game forgets it as the window
-- shuts (its page reset: the first recipe of the list picked as it opens again, the list at its top). The recipe the
-- player picks is kept for each profession (the character's, through a reload); the window opened again on that
-- profession, it is picked again and the list scrolled to it. A recipe opened from a link: the game's choice (and the
-- one kept). A recipe the list no longer shows (filtered out, folded away, unlearned): the game's choice.

local ADDON, ns = ...

local owner = {} -- (its callback's, in the game's EventRegistry)
local restoring -- the game's page setting a profession up (its first recipe about to be picked: not the player's)

local function Kept()
  local sv = ns.sv
  if not sv then return nil end
  local who = (ns.FullName and ns:FullName("player")) or (UnitName and UnitName("player")) or "?"
  sv.recipeKept = type(sv.recipeKept) == "table" and sv.recipeKept or {}
  sv.recipeKept[who] = type(sv.recipeKept[who]) == "table" and sv.recipeKept[who] or {}
  return sv.recipeKept[who]
end

local function ProfessionOf(page)
  local info = page and page.professionInfo
  return info and info.professionID
end

-- A recipe picked in the list (by the player): kept for its profession
local function Picked(page, recipeInfo, list)
  if restoring or not page or list ~= page.RecipeList then return end
  local id, profession = recipeInfo and recipeInfo.recipeID, ProfessionOf(page)
  local kept = Kept()
  if kept and id and profession then kept[profession] = id end
end

-- The page set up for a profession: the recipe kept picked again, the list scrolled to it
local function Restore(page, professionInfo)
  local was = restoring
  restoring = nil
  local kept, profession = Kept(), ProfessionOf(page)
  local link = professionInfo and professionInfo.openRecipeID
  if link then -- (opened from a link: the game shows it, the last one shown)
    if kept and profession then kept[profession] = link end
    return
  end
  if not was then return end
  local id = kept and profession and kept[profession]
  local list = page.RecipeList
  if not (id and list and list.SelectRecipe and C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo) then return end
  local info = C_TradeSkillUI.GetRecipeInfo(id)
  if not info then return end
  local data = list:SelectRecipe(info, false)
  if not data then return end -- (not in the list as it is: the game's choice)
  if list.ScrollBox and list.ScrollBox.ScrollToElementData then
    list.ScrollBox:ScrollToElementData(data, ScrollBoxConstants and ScrollBoxConstants.AlignCenter or nil)
  end
end
ns.RecipeMemoryRestore, ns.RecipeMemoryPicked = Restore, Picked -- (for its test)

local function Setup()
  local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
  local list = page and page.RecipeList
  if not (list and type(list.ProfessionChanged) == "function" and type(page.Init) == "function") then return end
  hooksecurefunc(list, "ProfessionChanged", function() restoring = true end)
  hooksecurefunc(page, "Init", Restore)
  if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("ProfessionsRecipeListMixin.Event.OnRecipeSelected", function(_, recipeInfo, from)
      Picked(page, recipeInfo, from)
    end, owner)
  end
end
if EventUtil and EventUtil.ContinueOnAddOnLoaded then
  EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", Setup)
end
