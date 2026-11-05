-- Clara Combo Points - Reverse Engineering in the game's own professions window (ClassicUI's calls
-- CraftUI.lua itself): the panel under the reagents (scrolling when it runs long), a chest on the
-- reagents the bank holds, the search (by name or reagent, "Name" in quotes for that recipe alone) and
-- the filter on what is in reach (its menu's last entries). The list is the game's: what does not
-- match is taken out of it each time the game makes it.

local ADDON, ns = ...
local C = ns.Craft
if not C then return end

local issecret = issecretvalue or function() return false end
local BASIC = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic

local page, form, list
local scroll, panel
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

local function Draw()
  if not (form and form:IsVisible()) then return end
  Chests()
  local id = Recipe()
  scroll:ClearAllPoints()
  scroll:SetPoint("TOPLEFT", Lowest(), "BOTTOMLEFT", 0, -10)
  scroll:SetPoint("BOTTOMRIGHT", form, "BOTTOMRIGHT", -30, 40)
  local width = math.max(150, (scroll:GetWidth() or 0) > 0 and scroll:GetWidth() or (form:GetWidth() or 480) - 60)
  local height = panel:Update(id, width)
  scroll:SetShown(height > 0)
  if scroll.ScrollBar then scroll:UpdateScrollChildRect() end
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

  scroll = CreateFrame("ScrollFrame", nil, form, "UIPanelScrollFrameTemplate")
  scroll:SetFrameLevel(form:GetFrameLevel() + 5)
  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(1, 1)
  scroll:SetScrollChild(child)
  panel = C.NewPanel(child, Draw)
  panel.frame:SetPoint("TOPLEFT")
  scroll:Hide()

  hooksecurefunc(form, "Init", function() C_Timer.After(0, Draw) end)
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
