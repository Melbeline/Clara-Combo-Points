-- Clara Combo Points - the professions window opened again on the recipe picked last: the game forgets it as the window
-- shuts (its page reset: the first recipe of the list picked as it opens again, the list at its top). The recipe the
-- player picks is kept for each profession (the character's; through a reload, not a new login); the window opened
-- again on that profession, it is picked again and the list scrolled to it. The game sets its page up several times as
-- the window opens (the first time often before its recipes have come: an empty list): tried again each time until the
-- recipe is found, or the player picks one; meanwhile the game's own picks (its first recipe) are not the player's: only
-- a pick that follows a click in the list is (the game's rows, or an addon's own list over them: ForeverRecipes'). Every
-- recipe the page shows is seen (its SelectRecipe), whichever list picked it. A recipe opened from a link: the game's
-- choice (and the one kept). A recipe the list no longer shows (filtered out, folded away, unlearned): the game's choice.

local ADDON, ns = ...

local owner = {} -- (its callback's, in the game's EventRegistry)
local restoring -- the game's page setting a profession up (its first recipe about to be picked: not the player's)
local pending -- the page set up anew (opened again, another profession): the recipe kept still to be picked again
local clicked -- when the list was last pressed (the player's pick follows)
local selecting -- (its own pick, the recipe kept picked again)
local CLICK_WINDOW = 1.5 -- seconds from the press to the pick
local rowsWatched = setmetatable({}, { __mode = "k" })
local trace, setup = {}, {} -- (the mouse report, /cl souris: what happened lately, and what got hooked)
local function Note(text)
  trace[#trace + 1] = { at = GetTime(), text = text }
  if #trace > 14 then table.remove(trace, 1) end
end
local function NameOf(id)
  local info = id and C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo and C_TradeSkillUI.GetRecipeInfo(id)
  return ("%s (%s)"):format(tostring(info and info.name or "?"), tostring(id))
end

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
  if not page or list ~= page.RecipeList or selecting then return end
  local id = recipeInfo and recipeInfo.recipeID
  if not id then return end
  local byPlayer = clicked and GetTime() - clicked < CLICK_WINDOW
  clicked = nil
  if (pending or restoring) and not byPlayer then -- (the game's own pick while it sets its page up)
    Note("the game picked " .. NameOf(id) .. ": not kept")
    return
  end
  Note((byPlayer and "the player picked " or "picked ") .. NameOf(id) .. ": kept")
  local profession = ProfessionOf(page)
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
    Note("opened from a link: " .. NameOf(link))
    return
  end
  if not pending then return end
  local id = kept and profession and kept[profession]
  local list = page.RecipeList
  if not id then pending = nil Note("set up: nothing kept for profession " .. tostring(profession)) return end
  if not (list and list.SelectRecipe and C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo) then return end
  local info = C_TradeSkillUI.GetRecipeInfo(id)
  if not info then Note("set up: no recipe info for " .. tostring(id) .. " yet") return end
  selecting = true
  local ok, data = pcall(list.SelectRecipe, list, info, false)
  selecting = nil
  if not ok then data = nil end
  if not data then Note("set up: " .. NameOf(id) .. " not in the list yet, tried again at the next set-up") return end
  pending = nil
  Note("set up: " .. NameOf(id) .. " picked again")
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
  hooksecurefunc(list, "ProfessionChanged", function()
    restoring, pending = true, true
    Note("the game set its page up anew (profession " .. tostring(ProfessionOf(page)) .. ")")
  end)
  hooksecurefunc(page, "Init", Restore)
  ProfessionsFrame:HookScript("OnHide", function() pending, restoring = nil, nil Note("the window shut") end)
  setup.hooked = true
  -- a row pressed: the pick that follows is the player's
  if ScrollUtil and ScrollUtil.AddInitializedFrameCallback and list.ScrollBox then
    ScrollUtil.AddInitializedFrameCallback(list.ScrollBox, function(_, row)
      if rowsWatched[row] or not row.HookScript then return end
      rowsWatched[row] = true
      row:HookScript("OnMouseDown", ns.RecipeMemoryClick)
    end, owner)
    setup.rows = true
  end
  -- every recipe the page shows, whichever list picked it (the game's sends its event, then shows it here)
  if type(page.SelectRecipe) == "function" then
    hooksecurefunc(page, "SelectRecipe", function(self, recipeInfo) Picked(self, recipeInfo, self.RecipeList) end)
    setup.page = true
  elseif EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("ProfessionsRecipeListMixin.Event.OnRecipeSelected", function(_, recipeInfo, from)
      Picked(page, recipeInfo, from)
    end, owner)
  end
  -- a press anywhere in the list (an addon's rows over the game's too), its search box and filter aside
  local presses = CreateFrame("Frame")
  presses:RegisterEvent("GLOBAL_MOUSE_DOWN")
  presses:SetScript("OnEvent", function()
    if not (ProfessionsFrame:IsShown() and list:IsVisible() and list:IsMouseOver()) then return end
    for _, f in ipairs({ list.SearchBox, list.FilterDropdown, list.FilterButton }) do
      if f and f.IsMouseOver and f:IsVisible() and f:IsMouseOver() then return end
    end
    clicked = GetTime()
    setup.presses = (setup.presses or 0) + 1
  end)
end
if EventUtil and EventUtil.ContinueOnAddOnLoaded then
  EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", Setup)
end

-- What it did lately, for the mouse report (/cl souris)
function ns:RecipeMemoryReport()
  local out = { ("recipe memory: hooked %s, rows watched %s, page watched %s, presses in the list %d, waiting to pick again %s"):format(
    tostring(setup.hooked or false), tostring(setup.rows or false), tostring(setup.page or false), setup.presses or 0,
    tostring(pending or false)) }
  local kept = Kept()
  local list = {}
  for profession, id in pairs(kept or {}) do list[#list + 1] = tostring(profession) .. " = " .. NameOf(id) end
  out[#out + 1] = "    kept: " .. (#list > 0 and table.concat(list, ", ") or "nothing")
  local now = GetTime()
  for _, e in ipairs(trace) do out[#out + 1] = ("    %.1f s ago: %s"):format(now - e.at, e.text) end
  return out
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
