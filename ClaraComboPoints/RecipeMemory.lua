-- Clara Combo Points - the professions window opened again on the recipe picked last: the game forgets it as the window
-- shuts (its page reset: the first recipe of the list picked as it opens again, the list at its top). The recipe the
-- player picks is kept for each profession (the character's; through a reload, not a new login); the window opened
-- again on that profession, it is picked again and the list scrolled to it. The game sets its page up several times as
-- the window opens (the first time often before its recipes have come: an empty list): tried again each time until the
-- recipe is found, or the player picks one; meanwhile the game's own picks (its first recipe) are not the player's: only
-- a pick that follows a click on a row of the list is. A recipe opened from a link: the game's choice (and the one kept).
-- A recipe the list no longer shows (filtered out, folded away, unlearned): the game's choice.

local ADDON, ns = ...

local owner = {} -- (its callback's, in the game's EventRegistry)
local restoring -- the game's page setting a profession up (its first recipe about to be picked: not the player's)
local pending -- the page set up anew (opened again, another profession): the recipe kept still to be picked again
local clicked -- when a row of the list was last pressed (the player's pick follows)
local rowsWatched = setmetatable({}, { __mode = "k" })

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
  if not page or list ~= page.RecipeList then return end
  local byPlayer = clicked and GetTime() - clicked < 0.5
  clicked = nil
  if pending and not byPlayer then return end -- (the game's own pick while it sets its page up)
  if restoring and not byPlayer then return end
  local id, profession = recipeInfo and recipeInfo.recipeID, ProfessionOf(page)
  local kept = Kept()
  if kept and id and profession then
    kept[profession] = id
    pending = nil -- (the player's choice now)
  end
end

-- The page set up for a profession (each time): the recipe kept picked again, the list scrolled to it, once found
local function Restore(page, professionInfo)
  restoring = nil
  local kept, profession = Kept(), ProfessionOf(page)
  local link = professionInfo and professionInfo.openRecipeID
  if link then -- (opened from a link: the game shows it, the last one shown)
    if kept and profession then kept[profession] = link end
    pending = nil
    return
  end
  if not pending then return end
  local id = kept and profession and kept[profession]
  local list = page.RecipeList
  if not id then pending = nil return end -- (nothing kept for it: the game's choice)
  if not (list and list.SelectRecipe and C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo) then return end
  local info = C_TradeSkillUI.GetRecipeInfo(id)
  if not info then return end
  local data = list:SelectRecipe(info, false)
  if not data then return end -- (not in the list yet: tried again at the next set-up)
  pending = nil
  if list.ScrollBox and list.ScrollBox.ScrollToElementData then
    list.ScrollBox:ScrollToElementData(data, ScrollBoxConstants and ScrollBoxConstants.AlignCenter or nil)
  end
end
ns.RecipeMemoryRestore, ns.RecipeMemoryPicked = Restore, Picked -- (for its test)
ns.RecipeMemoryClick = function() clicked = GetTime() end

local function Setup()
  local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
  local list = page and page.RecipeList
  if not (list and type(list.ProfessionChanged) == "function" and type(page.Init) == "function") then return end
  hooksecurefunc(list, "ProfessionChanged", function() restoring, pending = true, true end)
  hooksecurefunc(page, "Init", Restore)
  ProfessionsFrame:HookScript("OnHide", function() pending, restoring = nil, nil end)
  -- a row pressed: the pick that follows is the player's
  if ScrollUtil and ScrollUtil.AddInitializedFrameCallback and list.ScrollBox then
    ScrollUtil.AddInitializedFrameCallback(list.ScrollBox, function(_, row)
      if rowsWatched[row] or not row.HookScript then return end
      rowsWatched[row] = true
      row:HookScript("OnMouseDown", ns.RecipeMemoryClick)
    end, owner)
  end
  if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("ProfessionsRecipeListMixin.Event.OnRecipeSelected", function(_, recipeInfo, from)
      Picked(page, recipeInfo, from)
    end, owner)
  end
end
if EventUtil and EventUtil.ContinueOnAddOnLoaded then
  EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", Setup)
end

-- A new login (not a reload): this character's recipes forgotten
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self, _, isInitialLogin)
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")
  if isInitialLogin then
    local kept = Kept()
    if kept then wipe(kept) end
  end
end)
