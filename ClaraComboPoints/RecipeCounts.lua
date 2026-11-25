-- Clara Combo Points - the professions window's recipe list: how many each recipe makes from the bags, beside its name
-- ("[6] Charred Wolf Meat"), as Classic's trade skill window counts it. The game's row has that count (its Count,
-- " [%d] ") but asks C_TradeSkillUI.GetCraftableCount, which answers 0 on WoW Forever: it never shows. Counted here
-- as the game counts its Create All for the recipe picked (ProfessionsCraftingPageMixin:GetCraftableCount: each basic
-- slot, required or not, what the game says the player holds of its reagents, all tiers together, over what one craft
-- takes; the smallest of them), with the game's own count of a reagent (ProfessionsUtil.GetReagentQuantityInPossession;
-- the bags' when it is missing), right after the game's own count of each row (its first drawing, and each refresh as
-- the bags change), and as the list shows each row; a count the game gives itself is kept. Its colour is the recipe's difficulty,
-- as the skill-up chance beside it (ForeverRecipes' colours): orange, yellow, green, grey; kept when the row is
-- hovered. Before the name by default (after the skill-up chance: always in sight, even beside a long name), or after
-- it (the game's own place): two boxes on Reverse Engineering's page (both on; without that module, on). The name is
-- shortened to leave it room. Not for a recipe not learned, one that costs no reagents, nor on the crafting orders'
-- list (the game hides the count there).

local ADDON, ns = ...

local BASIC = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
local slotsOf = {} -- recipeID → { { items = { itemID, ... }, need = n }, ... } (a recipe's reagents never change)

local function Secret(v) return issecretvalue and issecretvalue(v) end

local function Slots(recipeID)
  local known = slotsOf[recipeID]
  if known then return known end
  local api = C_TradeSkillUI
  if not (api and api.GetRecipeSchematic) then return nil end
  local ok, schematic = pcall(api.GetRecipeSchematic, recipeID, false)
  if not ok or type(schematic) ~= "table" or type(schematic.reagentSlotSchematics) ~= "table" then return nil end
  local slots = {}
  for _, slot in ipairs(schematic.reagentSlotSchematics) do
    local need = tonumber(slot.quantityRequired) or 0
    -- (each basic slot, as the game's own count takes them: required or not; ProfessionsCraftingPageMixin:GetCraftableCount)
    if need > 0 and (BASIC == nil or slot.reagentType == nil or slot.reagentType == BASIC) then
      local reagents = {}
      for _, reagent in ipairs(slot.reagents or {}) do
        if reagent.itemID or reagent.currencyID then reagents[#reagents + 1] = reagent end
      end
      if #reagents > 0 then slots[#slots + 1] = { reagents = reagents, need = need } end
    end
  end
  slotsOf[recipeID] = slots
  return slots
end

local function Free(recipeID)
  local api = C_TradeSkillUI
  if not (api and api.HasNoReagentCost) then return false end
  local ok, yes = pcall(api.HasNoReagentCost, recipeID)
  return ok and not Secret(yes) and yes == true
end

-- How many the bags make (0: none, or nothing to count)
local function Craftable(recipeID)
  if not recipeID or Free(recipeID) then return 0 end
  local slots = Slots(recipeID)
  if not slots or #slots == 0 then return 0 end
  local most
  local util = ProfessionsUtil
  for _, slot in ipairs(slots) do
    local have = 0
    for _, reagent in ipairs(slot.reagents) do
      -- the game's own count of a reagent (what its Create All counts: ProfessionsUtil), else the bags'
      local n
      if util and util.GetReagentQuantityInPossession then
        local ok, v = pcall(util.GetReagentQuantityInPossession, reagent, false)
        if ok then n = v end
      end
      if n == nil and reagent.itemID and C_Item and C_Item.GetItemCount then n = C_Item.GetItemCount(reagent.itemID, false, false, false) end
      if n ~= nil and not Secret(n) then have = have + (tonumber(n) or 0) end
    end
    local makes = math.floor(have / slot.need)
    if not most or makes < most then most = makes end
  end
  return most or 0
end
ns.RecipeCraftable = Craftable

-- The recipe's difficulty colour (ForeverRecipes' own: its skill-up chance beside the name)
local function DifficultyRGB(relative)
  local E = Enum and Enum.TradeskillRelativeDifficulty
  if not E or relative == nil or Secret(relative) then return nil end
  local name, r, g, b
  if relative == E.Optimal then name, r, g, b = "ORANGE_FONT_COLOR", 1, 0.5, 0.25
  elseif relative == E.Medium then name, r, g, b = "YELLOW_FONT_COLOR", 1, 1, 0
  elseif relative == E.Easy then name, r, g, b = "GREEN_FONT_COLOR", 0.25, 0.75, 0.25
  else name, r, g, b = "GRAY_FONT_COLOR", 0.6, 0.6, 0.6 end
  local color = _G[name]
  if color and color.GetRGB then return color:GetRGB() end
  return r, g, b
end
ns.RecipeDifficultyRGB = DifficultyRGB

-- The row's recipe (nil once the list let the row go)
local function RecipeOf(row)
  if not row.GetElementData then return nil end
  local ok, node = pcall(row.GetElementData, row)
  local data = ok and type(node) == "table" and node.data
  local info = type(data) == "table" and data.recipeInfo
  return type(info) == "table" and info or nil
end

local function Recolor(row)
  local count = row.Count
  if not (count and count:IsShown()) then return end
  local info = RecipeOf(row)
  local r, g, b = DifficultyRGB(info and info.relativeDifficulty)
  if r then count:SetVertexColor(r, g, b) end
end

-- Reverse Engineering's two boxes (its page): the count shown, before the name; both on by default, and without it
local function Opt(key)
  local C = ns.Craft
  if not (C and C.Option) then return true end
  return C.Option(key)
end

-- The count before the name (after the skill-up chance, where the name began) or after it (the game's own place)
local function Place(row, before)
  local count, label, skill = row.Count, row.Label, row.SkillUps
  if not (count and label and skill) then return end
  count:ClearAllPoints()
  label:ClearAllPoints()
  if before then
    count:SetPoint("LEFT", skill, "RIGHT", 4, 0)
    label:SetPoint("LEFT", count, "RIGHT", 0, 0)
  else
    label:SetPoint("LEFT", skill, "RIGHT", 4, 0) -- (the game's anchors: Blizzard_ProfessionsRecipeList.xml)
    count:SetPoint("LEFT", label, "RIGHT", 0, 0)
  end
end

-- The name as wide as the row leaves it: the count, the skill-up chance, the lock, ForeverRecipes' price (the game
-- counts the count's width only when it shows its own)
local function FitLabel(row)
  local count, label = row.Count, row.Label
  if not (count and label and count:IsShown()) then return end
  local width = row:GetWidth() - count:GetStringWidth() - 13 - ((row.SkillUps and row.SkillUps:GetWidth() or 0) + 4)
  if row.LockedIcon and row.LockedIcon:IsShown() then width = width - (row.LockedIcon:GetWidth() or 0) end
  local price = row.frEstimateText
  if price and price:IsShown() then width = width - (price:GetStringWidth() or 0) end
  label:SetWidth(row:GetWidth())
  label:SetWidth(math.max(1, math.min(width, label:GetStringWidth())))
end
ns.RecipeCountFit = FitLabel

local ours = setmetatable({}, { __mode = "k" }) -- the rows whose count is Clara's
local seen = { rows = 0 } -- (the mouse report: rows counted, the last one)

-- After the game's count of a row (its drawing, each refresh as the bags change): ours when it gave none
local function Count(row, hideCraftableCount)
  local count = row.Count
  if not count then return end
  local info = RecipeOf(row)
  local gameShown = count:IsShown() and not ours[row]
  local n
  if not hideCraftableCount and info and Opt("recipeCount") then
    if gameShown then
      n = tonumber(tostring(count:GetText() or ""):match("%d+"))
    elseif info.learned ~= false then
      local made = Craftable(info.recipeID)
      if made > 0 then n = made end
    end
  end
  ours[row] = nil
  if not n then
    if not gameShown then count:Hide() end
    Place(row, false)
    return
  end
  seen.rows, seen.last, seen.made = seen.rows + 1, info and (info.name or info.recipeID), n
  local before = Opt("countLeft")
  count:SetText((before and "[%d] " or " [%d] "):format(n))
  count:Show()
  if not gameShown then ours[row] = true end
  Place(row, before)
  Recolor(row)
  FitLabel(row)
end
ns.RecipeCountRow = Count

-- Every row shown counted again (Reverse Engineering's boxes changed)
function ns.RecipeCountsRefresh()
  local list = ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.RecipeList
  local box = list and list.ScrollBox
  if not (box and box.ForEachFrame) then return end
  box:ForEachFrame(function(row)
    if row.Count then Count(row, list.hideCraftableCount) end
  end)
end

-- What the counts did, for the mouse report (/cl souris)
function ns:RecipeCountsReport()
  -- the recipe shown: the game's own count for its row (C_TradeSkillUI.GetCraftableCount) and Clara's
  local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
  local form = page and page.SchematicForm
  local ok, info = pcall(function() return form and form.GetRecipeInfo and form:GetRecipeInfo() end)
  local shown = ""
  if ok and type(info) == "table" and info.recipeID then
    local okGame, game = pcall(C_TradeSkillUI.GetCraftableCount, info.recipeID)
    shown = ("; %s: the game's row count %s, Clara's %s"):format(tostring(info.name or info.recipeID),
      okGame and tostring(game) or "?", tostring(Craftable(info.recipeID)))
  end
  return ("recipe counts: the game's row hooked %s, the list watched %s, counts shown %d (the last: %s [%s]), shown %s%s"):format(
    tostring(seen.hooked or false), tostring(seen.watched or false), seen.rows, tostring(seen.last), tostring(seen.made),
    tostring(Opt("recipeCount")), shown)
end

local hooked = false
local function Setup()
  local mixin = ProfessionsRecipeListRecipeMixin
  if hooked or type(mixin) ~= "table" or not mixin.SetCraftableCount then return end
  hooked = true
  seen.hooked = true
  hooksecurefunc(mixin, "SetCraftableCount", Count)
  if mixin.Init then hooksecurefunc(mixin, "Init", FitLabel) end
  if mixin.SetLabelFontColors then hooksecurefunc(mixin, "SetLabelFontColors", Recolor) end
end
if EventUtil and EventUtil.ContinueOnAddOnLoaded then
  EventUtil.ContinueOnAddOnLoaded("Blizzard_ProfessionsTemplates", Setup)
end

-- And each row as the professions window's list shows it (the game's own callback, as ForeverRecipes uses it), and
-- every row shown as the bags change: the counts there whatever else wraps the rows' functions
local owner = {}
local function Watch()
  local list = ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.RecipeList
  local box = list and list.ScrollBox
  if seen.watched or not (box and ScrollUtil and ScrollUtil.AddInitializedFrameCallback) then return end
  seen.watched = true
  ScrollUtil.AddInitializedFrameCallback(box, function(_, row)
    if row and row.Count and row.Label then Count(row, list.hideCraftableCount) end
  end, owner)
  local events = CreateFrame("Frame")
  events:RegisterEvent("BAG_UPDATE_DELAYED")
  events:SetScript("OnEvent", function()
    if ProfessionsFrame:IsShown() then ns.RecipeCountsRefresh() end
  end)
end
if EventUtil and EventUtil.ContinueOnAddOnLoaded then
  EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", Watch)
end
