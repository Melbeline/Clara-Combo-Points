-- Clara Combo Points - Reverse Engineering in the game's own professions window (ClassicUI's calls
-- CraftUI.lua itself): the panel under the reagents, a chest on the reagents the bank holds, the search
-- (by name or reagent, "Name" in quotes for that recipe alone) and the filter on what is in reach (its
-- menu's last entries). The list is the game's: what does not match is taken out of it each time the
-- game makes it.
-- The whole recipe pane on the right scrolls as one (the wheel anywhere on it, a bar at its right edge
-- when there is more below): the game's recipe form is put in a scroll frame of its own size and place
-- (placed again as the game moves it: the window maximized or minimized), made as tall as what it holds.
-- With the addon ForeverRecipes (its code left as it is): its panels (Difficulty and its estimates,
-- Source) lie under the reagents too; they are put in the same scroll frame, the panel under them.

local ADDON, ns = ...
local C = ns.Craft
if not C then return end

local issecret = issecretvalue or function() return false end
local BASIC = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic

local page, form, list
local pane, holder, panel -- the scroll frame, what it scrolls (the game's form in it), the panel
local baseHeight          -- the form's own height: the pane's
local query = ""      -- the search text, when ours does the search

local function Recipe()
  local info = form and form.GetRecipeInfo and form:GetRecipeInfo()
  return info and info.recipeID
end

-- The chests on the reagents' buttons
local function Chests()
  -- (no slots before the form has shown a recipe: a gathering profession's page, Herbalism's, has none)
  local made = rawget(form, "reagentSlots")
  if type(made) ~= "table" then return end
  local slots = form.GetSlotsByReagentType and form:GetSlotsByReagentType(BASIC) or made[BASIC]
  for _, slot in ipairs(slots or {}) do
    local schematic = slot.GetReagentSlotSchematic and slot:GetReagentSlotSchematic()
    local reagent = schematic and schematic.reagents and schematic.reagents[1]
    local button = slot.Button
    if button then C.MarkChest(button, reagent and reagent.itemID, button) end
  end
end

-- The lowest of the reagent boxes shown: the panel goes under it
local function Lowest()
  local low, bottom
  for _, key in ipairs({ "Reagents", "OptionalReagents", "FinishingReagents" }) do
    local box = form[key]
    if box and box:IsShown() then
      local b = box:GetBottom()
      if b and not issecret(b) and (not bottom or b < bottom) then low, bottom = box, b end
    end
  end
  return low or form.Reagents
end

-- ForeverRecipes' panels, under the reagents: its Difficulty (the bar and its estimates) and its
-- Source under that (frames of its own on the page, without names: known by what they hold). Their
-- showing or hiding (another recipe, its options) places the panel again.
local frDifficulty, frSource
local Draw
local function Watch(frame)
  local function Again() C_Timer.After(0, function() if Draw then Draw() end end) end
  frame:HookScript("OnShow", Again)
  frame:HookScript("OnHide", Again)
  -- (in the pane: scrolled and cut with the rest of the recipe)
  if holder and frame.SetParent then
    local level = frame:GetFrameLevel()
    frame:SetParent(holder)
    frame:SetFrameLevel(level)
  end
end
local function ForeverRecipesBottom()
  if not (_G.ForeverRecipes and page and page.GetChildren) then return nil end
  if not (frDifficulty and frSource) then
    for _, child in ipairs({ page:GetChildren() }) do
      if not frDifficulty and type(rawget(child, "estimateRows")) == "table" and rawget(child, "bar") and rawget(child, "req") then
        frDifficulty = child
        Watch(child)
      elseif not frSource and type(rawget(child, "rows")) == "table" and rawget(child, "content") == child then
        frSource = child
        Watch(child)
      end
    end
  end
  if frSource and frSource:IsShown() then return frSource end
  if frDifficulty and frDifficulty:IsShown() then return frDifficulty end
  return nil
end

---------------------------------------------------------------------------
-- The pane: the game's form in a scroll frame of its size and place
---------------------------------------------------------------------------
local BELOW = 44 -- room under the panel (the form's Track Recipe box)

-- Its height: the form's own, or what it holds
local function Fit(height)
  if not (pane and form) then return end
  height = math.max(baseHeight, height or baseHeight)
  if math.abs((form:GetHeight() or 0) - height) > 0.5 then form:SetHeight(height) end
  holder:SetHeight(height)
  local more = height > baseHeight + 1
  if pane.ScrollBar then pane.ScrollBar:SetShown(more) end
  if pane.UpdateScrollChildRect then pane:UpdateScrollChildRect() end
  if not more then pane:SetVerticalScroll(0) end
end

-- Where the game puts the form (its first anchor), the pane goes; the form in the pane
local function Place()
  if not (pane and form) then return end
  local point, rel, relPoint, x, y = form:GetPoint(1)
  if rel and rel ~= holder then
    pane:ClearAllPoints()
    pane:SetPoint(point, rel, relPoint, x, y)
    form:ClearAllPoints()
    form:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
  end
  local width = form:GetWidth() or 0
  if width > 0 then
    pane:SetSize(width, baseHeight)
    holder:SetWidth(width)
  end
end

local function Wrap()
  baseHeight = form:GetHeight() or 0
  if baseHeight < 100 then baseHeight = 484 end -- (its template's)
  pane = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
  holder = CreateFrame("Frame", nil, pane)
  holder:SetSize(math.max(1, form:GetWidth() or 493), baseHeight)
  pane:SetScrollChild(holder)
  if pane.EnableMouseWheel then pane:EnableMouseWheel(true) end
  local bar = pane.ScrollBar
  if bar then -- (inside its right edge, shown when there is more below)
    bar:ClearAllPoints()
    bar:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -4, -20)
    bar:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -4, 20)
    bar:Hide()
  end
  Place()
  local level = form:GetFrameLevel()
  form:SetParent(holder)
  form:SetFrameLevel(level)
  form:ClearAllPoints()
  form:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
  for _, name in ipairs({ "SetMaximized", "SetMinimized" }) do
    if type(page[name]) == "function" then hooksecurefunc(page, name, Place) end
  end
  hooksecurefunc(form, "SetWidth", Place)
  -- (another recipe: from its top; ForeverRecipes' own pane in its place: the form's own height)
  form:HookScript("OnHide", function() Fit(baseHeight) end)
end
ns.CraftGamePane = function() return pane, holder, panel and panel.frame end -- (for the tests)

function Draw()
  if not (form and form:IsVisible()) then return end
  Chests()
  local id = Recipe()
  local f = panel.frame
  f:ClearAllPoints()
  local under = ForeverRecipesBottom() or Lowest()
  f:SetPoint("TOPLEFT", under, "BOTTOMLEFT", 0, -10)
  local left = under:GetLeft()
  local right = form:GetRight()
  local width = (left and right and right - left - 30) or ((form:GetWidth() or 480) - 60)
  local height = panel:Update(id, math.max(150, width))
  local need = baseHeight
  if height > 0 then
    local top, bottom = holder:GetTop(), f:GetBottom()
    if top and bottom then need = top - bottom + BELOW end
  end
  Fit(math.min(need, baseHeight * 4)) -- (never past four times its own: the panel can hold no more)
end

---------------------------------------------------------------------------
-- The list: what does not match taken out
---------------------------------------------------------------------------
local function Prune(node)
  local kept = 0
  local children = node.GetNodes and node:GetNodes() or node.nodes or {}
  for i = #children, 1, -1 do
    local child = children[i]
    local data = child.GetData and child:GetData() or child.data or {}
    if data.recipeInfo then
      local info = data.recipeInfo
      if C.Match(info.recipeID, info.name, query) and C.Shown(info.recipeID) then
        kept = kept + 1
      else
        node:Remove(child, true)
      end
    elseif data.categoryInfo then
      if Prune(child) == 0 then node:Remove(child, true) else kept = kept + 1 end
    end
  end
  -- what is left of an emptied category: its padding; of the whole list: the divider
  if kept == 0 then
    for i = #children, 1, -1 do node:Remove(children[i], true) end
  end
  return kept
end

local function Pruned(_, provider)
  if not provider or not provider.GetRootNode then return end
  local searching = query ~= "" and C.Option("search")
  if not searching and not C.FilterOn() then return end
  Prune(provider:GetRootNode())
  if provider.Invalidate then provider:Invalidate() end
  if list.NoResultsText then list.NoResultsText:SetShown(provider:IsEmpty()) end
end

-- The list made again (a filter changed, a search ours)
local relisting
function C.Relist()
  if relisting then return end
  relisting = true
  C_Timer.After(0, function()
    relisting = nil
    local frame = ProfessionsFrame
    if frame and frame:IsShown() and frame.Refresh then frame:Refresh() end
    if ns.ClassicTradeRefresh then ns.ClassicTradeRefresh() end
  end)
end

-- The search box: ours reads the text; the game's own filter on names is left empty so that a recipe
-- found by a reagent is in the list (the game's level search, "~30" or "10-20", stays the game's)
local function OnSearch(box)
  local text = box:GetText() or ""
  if not C.Option("search") or text:match("^~%d") or text:match("^%d+%s*%-*%s*%d*$") then
    query = ""
    return
  end
  local was = query
  query = text
  local api = C_TradeSkillUI
  if text ~= "" and api.GetRecipeItemNameFilter and (api.GetRecipeItemNameFilter() or "") ~= "" then
    api.SetRecipeItemNameFilter(nil)
  end
  if was ~= query then C.Relist() end
end

---------------------------------------------------------------------------
-- The filter menu: its last entries
---------------------------------------------------------------------------
local function FilterMenu(_, root)
  if not (root and root.CreateCheckbox) then return end
  root:CreateDivider()
  if root.CreateTitle then root:CreateTitle("Reverse Engineering") end
  for _, e in ipairs(C.FilterEntries()) do
    root:CreateCheckbox(e.label, function() return C.Filter()[e.key] == true end, function() C.ToggleFilter(e.key) end)
  end
end

---------------------------------------------------------------------------
local function Setup()
  page = ProfessionsFrame and ProfessionsFrame.CraftingPage
  form = page and page.SchematicForm
  list = page and page.RecipeList
  if not (form and list) or form.claraCraft then return end
  form.claraCraft = true

  Wrap()
  panel = C.NewPanel(holder, Draw)
  panel.frame:SetFrameLevel(form:GetFrameLevel() + 5)
  panel.frame:Hide()

  hooksecurefunc(form, "Init", function()
    pane:SetVerticalScroll(0)
    C_Timer.After(0, Draw)
  end)
  if form.Refresh then hooksecurefunc(form, "Refresh", Draw) end
  form:HookScript("OnShow", Draw)
  C.Redraws[#C.Redraws + 1] = Draw

  if list.ScrollBox and list.ScrollBox.SetDataProvider then hooksecurefunc(list.ScrollBox, "SetDataProvider", Pruned) end
  if list.SearchBox then list.SearchBox:HookScript("OnTextChanged", OnSearch) end
  if Menu and Menu.ModifyMenu then Menu.ModifyMenu("MENU_PROFESSIONS_FILTER", FilterMenu) end
end

if EventUtil and EventUtil.ContinueOnAddOnLoaded then
  EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", Setup)
end

-- (for the tests)
C.GamePrune = function(provider, text)
  query = text or ""
  Pruned(nil, provider)
end
