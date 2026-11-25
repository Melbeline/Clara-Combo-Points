-- The recipe list's craftable counts (RecipeCounts.lua) on a copy of the game's row (Blizzard_ProfessionsRecipeList.lua:
-- Init, SetCraftableCount, SetLabelFontColors), C_TradeSkillUI.GetCraftableCount answering 0 as on WoW Forever: the
-- bags' count before the name ("[6] ", after the skill-up chance; after it with Reverse Engineering's box unticked), in the recipe's difficulty colour (orange, yellow, green, grey), kept when
-- hovered; updated when the bags change; none for a recipe not learned, one without reagents, one free, nor on a list
-- that hides counts; a count the game gives itself kept (only recoloured); the name shortened to leave it room.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function near(a, b) return math.abs((a or -9) - b) < 0.01 end

Enum = Enum or {}
Enum.TradeskillRelativeDifficulty = { Optimal = 0, Medium = 1, Easy = 2, Trivial = 3 }
Enum.CraftingReagentType = Enum.CraftingReagentType or { Basic = 0, Modifying = 1 }
ORANGE_FONT_COLOR = { GetRGB = function() return 1, 0.5, 0.25 end }
YELLOW_FONT_COLOR = { GetRGB = function() return 1, 1, 0 end }
GREEN_FONT_COLOR = { GetRGB = function() return 0.25, 0.75, 0.25 end }
GRAY_FONT_COLOR = { GetRGB = function() return 0.6, 0.6, 0.6 end }
local WHITE = { GetRGB = function() return 1, 1, 1 end }
HIGHLIGHT_FONT_COLOR = WHITE
local bags = { [2672] = 13, [2678] = 7, [6889] = 97, [2678.5] = 0, [2318] = 18 }
C_Item = C_Item or {}
C_Item.GetItemCount = function(id) return bags[id] or 0 end
local gameCount = {}
local schematics = {
  [2538] = { { quantityRequired = 2, reagentType = 0, reagents = { { itemID = 2672 } } }, { quantityRequired = 1, reagentType = 0, reagents = { { itemID = 2678 } } } }, -- 13/2, 7/1: 6
  [8604] = { { quantityRequired = 1, reagentType = 0, reagents = { { itemID = 6889 } } }, { quantityRequired = 1, reagentType = 1, required = false, reagents = { { itemID = 1 } } } }, -- 97 (an optional slot aside)
  [9999] = {},
  -- Camp Tent as WoW Forever gives it: its basic slot not marked required (the game counts it all the same)
  [6704] = { { quantityRequired = 5, reagentType = 0, required = false, reagents = { { itemID = 2318 } } } },
}
C_TradeSkillUI = {
  GetCraftableCount = function(id) return gameCount[id] or 0 end, -- (WoW Forever: 0)
  GetRecipeSchematic = function(id) return { reagentSlotSchematics = schematics[id] or {} } end,
  HasNoReagentCost = function(id) return id == 7777 end,
}

-- the game's row (its own code, Blizzard_ProfessionsRecipeList.lua:255-375, what matters here)
ProfessionsRecipeListRecipeMixin = {}
local Mixin_ = ProfessionsRecipeListRecipeMixin
function Mixin_:GetLabelColor() return WHITE end
function Mixin_:Init(node, hideCraftableCount)
  local recipeInfo = node:GetData().recipeInfo
  self.Label:SetText(recipeInfo.name)
  self:SetLabelFontColors(self:GetLabelColor())
  self:SetCraftableCount(hideCraftableCount)
  local width = self:GetWidth() - (0 + 0 + 10 + self.SkillUps:GetWidth()) -- (its hasCount: nil, the count forgotten)
  self.Label:SetWidth(self:GetWidth())
  self.Label:SetWidth(math.min(width, self.Label:GetStringWidth()))
end
function Mixin_:SetCraftableCount(hideCraftableCount)
  local count = C_TradeSkillUI.GetCraftableCount(self:GetElementData().data.recipeInfo.recipeID)
  if count > 0 and not hideCraftableCount then
    self.Count:SetFormattedText(" [%d] ", count)
    self.Count:Show()
  else
    self.Count:Hide()
  end
end
function Mixin_:SetLabelFontColors(color)
  self.Label._vc = { color:GetRGB() }
  self.Count:SetVertexColor(color:GetRGB())
end
function Mixin_:OnEnter() self:SetLabelFontColors(HIGHLIGHT_FONT_COLOR) end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end -- (WoW Forever: its modules on)
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, mail = false, classicui = false, tullarange = false,
  names = false, tooltipanchor = false } } -- (as test58: Reverse Engineering on, its boxes)
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
M.Fire("ADDON_LOADED", "Blizzard_ProfessionsTemplates")

-- a row made after (the game's template: the mixin's functions copied onto it)
local function Row()
  local row = CreateFrame("Button", nil, UIParent)
  row:SetWidth(260)
  for k, v in pairs(ProfessionsRecipeListRecipeMixin) do row[k] = v end
  row.Label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.Count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.Count.SetVertexColor = function(self, r, g, b) self._vc = { r, g, b } end
  row.SkillUps = CreateFrame("Frame", nil, row); row.SkillUps:SetWidth(20)
  return row
end
local function Node(info) return { data = { recipeInfo = info }, GetData = function(self) return self.data end } end
local function Draw(row, info, hide)
  local node = Node(info)
  row.GetElementData = function() return node end
  row:Init(node, hide)
  return row
end
local function Text(row) return row.Count:IsShown() and row.Count:GetText() or nil end
local function RGB(row) local c = row.Count._vc or {} return c[1], c[2], c[3] end

out("== the bags' count after the name, in the recipe's difficulty colour")
local row = Draw(Row(), { recipeID = 2538, name = "Charred Wolf Meat", learned = true, relativeDifficulty = 0 })
check(Text(row) == "[6] ", "13 meat over 2, 7 spices over 1: [6] (" .. tostring(Text(row)) .. ")")
local function Anchor(fs) local p = fs._points and fs._points[1] return p and p[2] end
check(Anchor(row.Count) == row.SkillUps and Anchor(row.Label) == row.Count, "before the name: after the skill-up chance, the name after it")
local r, g, b = RGB(row)
check(near(r, 1) and near(g, 0.5) and near(b, 0.25), "orange (optimal)")
row:OnEnter()
r, g, b = RGB(row)
check(near(g, 0.5), "hovered: still orange")
check(row.Label:GetWidth() <= 260 - row.Count:GetStringWidth() - 10 - 20 + 0.5, "the name shortened to leave it room")
row = Draw(Row(), { recipeID = 8604, name = "Herb Baked Egg", learned = true, relativeDifficulty = 1 })
r, g, b = RGB(row)
check(Text(row) == "[97] " and near(r, 1) and near(g, 1) and near(b, 0), "an optional slot aside: [97], yellow")
row = Draw(Row(), { recipeID = 2538, name = "Charred Wolf Meat", learned = true, relativeDifficulty = 2 })
r, g, b = RGB(row)
check(near(r, 0.25) and near(g, 0.75), "green (easy)")
row = Draw(Row(), { recipeID = 2538, name = "Charred Wolf Meat", learned = true, relativeDifficulty = 3 })
r, g, b = RGB(row)
check(near(r, 0.6) and near(g, 0.6), "grey (trivial)")

out("== the bags change")
bags[2678] = 2
row:SetCraftableCount(false)
check(Text(row) == "[2] ", "2 spices left: [2]")
bags[2678] = 0
row:SetCraftableCount(false)
check(Text(row) == nil and Anchor(row.Label) == row.SkillUps and Anchor(row.Count) == row.Label, "none left: no count, the game's anchors back")
bags[2678] = 7

out("== none")
check(Text(Draw(Row(), { recipeID = 2538, name = "x", learned = false, relativeDifficulty = 0 })) == nil, "a recipe not learned")
check(Text(Draw(Row(), { recipeID = 9999, name = "x", learned = true, relativeDifficulty = 0 })) == nil, "no reagents")
check(Text(Draw(Row(), { recipeID = 7777, name = "x", learned = true, relativeDifficulty = 0 })) == nil, "a free recipe")
check(Text(Draw(Row(), { recipeID = 2538, name = "x", learned = true, relativeDifficulty = 0 }, true)) == nil, "a list that hides counts")
local gone = Row()
gone.GetElementData = function() error("released") end
check((pcall(ns.RecipeCountRow, gone, false)), "a row the list let go: Clara's count, no error")

out("== the game's own count, when it gives one")
gameCount[2538] = 4
row = Draw(Row(), { recipeID = 2538, name = "Charred Wolf Meat", learned = true, relativeDifficulty = 0 })
r, g, b = RGB(row)
check(Text(row) == "[4] " and near(g, 0.5), "kept ([4]), recoloured, before the name")
gameCount[2538] = nil
out("== Reverse Engineering's two boxes")
local C = ns.Craft
if C and C.SetOption then
  C.SetOption("countLeft", false)
  row = Draw(Row(), { recipeID = 2538, name = "Charred Wolf Meat", learned = true, relativeDifficulty = 0 })
  check(Text(row) == " [6] " and Anchor(row.Label) == row.SkillUps and Anchor(row.Count) == row.Label, "unticked: after the name (the game's place)")
  C.SetOption("countLeft", true)
  ns.RecipeCountRow(row, false)
  check(Text(row) == "[6] " and Anchor(row.Count) == row.SkillUps, "ticked again: before it")
  C.SetOption("recipeCount", false)
  ns.RecipeCountRow(row, false)
  check(Text(row) == nil and Anchor(row.Label) == row.SkillUps, "the count off: none, the name back in its place")
  C.SetOption("recipeCount", true)
else
  out("  (no Reverse Engineering here: always on, before the name)")
end
out("== a basic slot not marked required (WoW Forever's Camp Tent): counted, as the game counts it")
row = Draw(Row(), { recipeID = 6704, name = "Camp Tent", learned = true, relativeDifficulty = 3 })
r, g, b = RGB(row)
check(Text(row) == "[3] " and near(r, 0.6) and near(g, 0.6), "18 Light Leather over 5: [3], grey (trivial) (" .. tostring(Text(row)) .. ")")

out("== each row as the window's list shows it (whatever wraps the rows' functions), and as the bags change")
local inits = {}
ScrollUtil = { AddInitializedFrameCallback = function(box, fn, owner) inits[#inits + 1] = fn end }
local shown = {}
ProfessionsFrame = CreateFrame("Frame", "ProfessionsFrame", UIParent)
local listFrame = CreateFrame("Frame", nil, ProfessionsFrame)
ProfessionsFrame.CraftingPage = { RecipeList = listFrame }
listFrame.ScrollBox = { ForEachFrame = function(_, fn) for _, f in ipairs(shown) do fn(f) end end }
M.Fire("ADDON_LOADED", "Blizzard_Professions")
check(#inits == 1, "the list's own callback taken")
-- a row whose count function another addon wrapped before Clara's hook (the game's own, unhooked, underneath)
local bare = Row()
bare.SetCraftableCount = function(self, hide) self.Count:Hide() end
local node = Node({ recipeID = 6704, name = "Camp Tent", learned = true, relativeDifficulty = 3 })
bare.GetElementData = function() return node end
bare:SetCraftableCount(false)
check(Text(bare) == nil, "(the wrapped function alone: no count)")
inits[1](nil, bare, node)
check(Text(bare) == "[3] ", "the list's callback: the count there")
shown[1] = bare
bags[2318] = 10
ProfessionsFrame:Show()
M.Fire("BAG_UPDATE_DELAYED")
check(Text(bare) == "[2] ", "the bags change: counted again ([2])")
check(ns:RecipeCountsReport():find("counts shown", 1, true), "in the mouse report: " .. ns:RecipeCountsReport())

out("== the game's own count of a reagent (what its Create All counts), when it has one")
ProfessionsUtil = { GetReagentQuantityInPossession = function(reagent) return (bags[reagent.itemID] or 0) + 10 end } -- (its bank too, say)
ns.RecipeCountRow(bare, false)
check(Text(bare) == "[4] ", "10 + 10 Light Leather over 5: [4], the game's number (" .. tostring(Text(bare)) .. ")")
ProfessionsUtil = nil
out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
