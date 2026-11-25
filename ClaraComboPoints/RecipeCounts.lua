-- Clara Combo Points - the professions window's recipe list: how many each recipe makes from the bags, after its name
-- ("Charred Wolf Meat [6]"), as Classic's trade skill window shows it. The game's row has that count (its Count,
-- " [%d] ") but asks C_TradeSkillUI.GetCraftableCount, which answers 0 on WoW Forever: it never shows. Counted here
-- from the recipe's reagents in the bags (each basic slot: what the bags hold of it, all its tiers together, over
-- what one craft takes; the smallest of them), right after the game's own count of each row (its first drawing, and
-- each refresh as the bags change); a count the game gives itself is kept. Its colour is the recipe's difficulty,
-- as the skill-up chance beside it (ForeverRecipes' colours): orange, yellow, green, grey; kept when the row is
-- hovered. The name is shortened to leave it room (the game forgets the count there). Not for a recipe not learned,
-- one that costs no reagents, nor on the crafting orders' list (the game hides the count there).

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
    if need > 0 and slot.required ~= false and (BASIC == nil or slot.reagentType == nil or slot.reagentType == BASIC) then
      local items = {}
      for _, reagent in ipairs(slot.reagents or {}) do
        if reagent.itemID then items[#items + 1] = reagent.itemID end
      end
      if #items > 0 then slots[#slots + 1] = { items = items, need = need } end
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
  for _, slot in ipairs(slots) do
    local have = 0
    for _, itemID in ipairs(slot.items) do
      local n = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(itemID, false, false, false) or 0
      if not Secret(n) then have = have + (tonumber(n) or 0) end
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

-- After the game's count of a row: ours when it gave none
local function Count(row, hideCraftableCount)
  local count = row.Count
  if not count or hideCraftableCount then return end
  local info = RecipeOf(row)
  if not info then return end
  if not count:IsShown() then
    if info.learned == false then return end
    local n = Craftable(info.recipeID)
    if n <= 0 then return end
    count:SetFormattedText(" [%d] ", n)
    count:Show()
  end
  Recolor(row)
end
ns.RecipeCountRow = Count

-- After the game's own drawing of a row: the name shortened to leave the count its room (the game counts the count's
-- width only when it shows its own). ForeverRecipes lays out its rows itself, the count counted.
local function FitLabel(row)
  local count, label = row.Count, row.Label
  if not (count and label and count:IsShown()) or row.frEstimateText then return end
  local width = row:GetWidth() - count:GetStringWidth() - 10
  if row.SkillUps then width = width - (row.SkillUps:GetWidth() or 0) end
  if row.LockedIcon and row.LockedIcon:IsShown() then width = width - (row.LockedIcon:GetWidth() or 0) end
  label:SetWidth(row:GetWidth())
  label:SetWidth(math.max(1, math.min(width, label:GetStringWidth())))
end
ns.RecipeCountFit = FitLabel

local hooked = false
local function Setup()
  local mixin = ProfessionsRecipeListRecipeMixin
  if hooked or type(mixin) ~= "table" or not mixin.SetCraftableCount then return end
  hooked = true
  hooksecurefunc(mixin, "SetCraftableCount", Count)
  if mixin.Init then hooksecurefunc(mixin, "Init", FitLabel) end
  if mixin.SetLabelFontColors then hooksecurefunc(mixin, "SetLabelFontColors", Recolor) end
end
if EventUtil and EventUtil.ContinueOnAddOnLoaded then
  EventUtil.ContinueOnAddOnLoaded("Blizzard_ProfessionsTemplates", Setup)
end
