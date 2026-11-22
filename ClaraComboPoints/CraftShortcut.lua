-- Clara Combo Points - a recipe on the action bars. The made item's icon at the top of a recipe in the professions
-- window (and, with ClassicUI, the icon of its old trade skill window) is dragged onto a bar like a spell; a click on
-- the shortcut makes the item: one, or with Shift as many as the bags' reagents allow (the game's Create All).
-- The game puts nothing of a recipe on a bar, so the shortcut is a macro of this character (the account's once the
-- character's thirty are taken), named after the recipe, with the made item's icon, its one line asking Clara:
-- /run ClaraCraft(<recipe>). Made once per recipe, found again by that line the next times (moved, renamed, its icon
-- changed in /macro: still found). Not in a fight (the game makes no macro then); one already made is taken.
-- The click crafts at once while the recipe's profession is open (the game's own C_TradeSkillUI.CraftRecipe, as its
-- Create button); otherwise it opens that profession (the game crafts only with it open) and crafts once its list is
-- ready. Over the shortcut, the made item's tooltip, with a line saying what a click does. Recipes that work on an item
-- (salvage, recraft) or make nothing (gathering) stay off the bars.

local ADDON, ns = ...
local L = ns.L

local MARK = "ClaraCraft%((%d+)%)"
local NAME_MAX = 16  -- (a macro's name, as the game's macro window takes it)
local FALLBACK_ICON = 134400 -- (the question mark)
local WAIT = 10      -- a craft waiting for its profession to open, at most this long
local BASIC = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic

local function Api() return C_TradeSkillUI end
local function Secret(v) return issecretvalue and issecretvalue(v) end

local function Say(text)
  if not text then return end
  if UIErrorsFrame and UIErrorsFrame.AddMessage then
    UIErrorsFrame:AddMessage(text, 1, 0.82, 0)
  elseif DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("Clara: " .. text)
  end
end

-- The first `max` letters of a name (UTF-8: an accented letter never cut in two)
local function Cut(name, max)
  local out, n = {}, 0
  for ch in tostring(name or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    n = n + 1
    if n > max then break end
    out[n] = ch
  end
  return (table.concat(out):gsub("%s+$", ""))
end

local function Body(recipeID) return ("/run if ClaraCraft then ClaraCraft(%d) end"):format(recipeID) end
ns.CraftShortcutBody = Body

local function RecipeOf(body)
  return type(body) == "string" and not Secret(body) and tonumber(body:match(MARK)) or nil
end
ns.CraftShortcutRecipeOf = RecipeOf

-- The macro already made for this recipe (the account's, then the character's), or nil
local function MaxAccount()
  return (Constants and Constants.MacroConsts and Constants.MacroConsts.MAX_ACCOUNT_MACROS) or MAX_ACCOUNT_MACROS or 120
end
local function FindMacro(recipeID)
  if not (GetNumMacros and GetMacroBody) then return nil end
  local account, character = GetNumMacros()
  for i = 1, account or 0 do
    if RecipeOf(GetMacroBody(i)) == recipeID then return i end
  end
  local base = MaxAccount()
  for i = base + 1, base + (character or 0) do
    if RecipeOf(GetMacroBody(i)) == recipeID then return i end
  end
end

-- Recipes that cannot run from a bar: they work on an item picked (salvage, recraft) or make nothing
local function Barred(info)
  return info.isSalvageRecipe or info.isRecraft or info.isGatheringRecipe or info.isDummyRecipe
end

-- The recipe's shortcut on the cursor, to be dropped on a bar (made first if it is not yet)
function ns.CraftShortcut(recipeID)
  recipeID = tonumber(recipeID)
  local api = Api()
  if not (recipeID and api and CreateMacro and PickupMacro) then return end
  local info = api.GetRecipeInfo and api.GetRecipeInfo(recipeID)
  if type(info) ~= "table" then return end
  if Barred(info) then return Say(L.CRAFT_SHORTCUT_BARRED) end
  if info.learned == false then return Say(L.CRAFT_SHORTCUT_UNLEARNED) end
  local index = FindMacro(recipeID)
  if not index then
    if InCombatLockdown() then return Say(L.CRAFT_SHORTCUT_COMBAT) end
    local output = api.GetRecipeOutputItemData and select(2, pcall(api.GetRecipeOutputItemData, recipeID))
    local icon = type(output) == "table" and output.icon or info.icon or FALLBACK_ICON
    local name = Cut(info.name, NAME_MAX)
    if name == "" then name = tostring(recipeID) end
    local ok, made = pcall(CreateMacro, name, icon, Body(recipeID), true)
    if not (ok and made) then ok, made = pcall(CreateMacro, name, icon, Body(recipeID), false) end -- (the character's full)
    if not (ok and made) then return Say(L.CRAFT_SHORTCUT_FULL) end
    index = made
  end
  if ClearCursor and GetCursorInfo and GetCursorInfo() then ClearCursor() end
  PickupMacro(index)
  return index
end

---------------------------------------------------------------------------
-- The click
---------------------------------------------------------------------------

-- Its profession open, ready, the player's own (not a linked or guild list), and holding the recipe
local function Ready(recipeID)
  local api = Api()
  if not (api and api.IsTradeSkillReady and api.IsTradeSkillReady()) then return false end
  if (api.IsTradeSkillLinked and api.IsTradeSkillLinked()) or (api.IsTradeSkillGuild and api.IsTradeSkillGuild()) then return false end
  local child = api.GetChildProfessionInfo and api.GetChildProfessionInfo()
  if type(child) == "table" and child.professionID and api.IsRecipeInSkillLine then
    local ok, yes = pcall(api.IsRecipeInSkillLine, recipeID, child.professionID)
    if ok and yes == true then return true end
  end
  local base = api.GetBaseProfessionInfo and api.GetBaseProfessionInfo()
  local line, parent
  if api.GetTradeSkillLineForRecipe then
    local ok, a, _, c = pcall(api.GetTradeSkillLineForRecipe, recipeID)
    if ok then line, parent = a, c end
  end
  return type(base) == "table" and base.professionID ~= nil and base.professionID == (parent or line) or false
end
ns.CraftShortcutReady = Ready

local function Free(recipeID)
  local api = Api()
  if not (api and api.HasNoReagentCost) then return false end
  local ok, yes = pcall(api.HasNoReagentCost, recipeID)
  return ok and not Secret(yes) and yes == true
end

-- How many: one; with Shift, as many as the bags' reagents allow (its basic reagents, each slot's tiers together)
local function Count(recipeID, all)
  if not all or Free(recipeID) then return 1 end
  local api = Api()
  local ok, schematic = pcall(api.GetRecipeSchematic, recipeID, false)
  if not ok or type(schematic) ~= "table" then return 1 end
  local most
  for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
    local need = tonumber(slot.quantityRequired) or 0
    if need > 0 and (BASIC == nil or slot.reagentType == BASIC) and slot.required ~= false then
      local have = 0
      for _, reagent in ipairs(slot.reagents or {}) do
        if reagent.itemID then have = have + (C_Item.GetItemCount(reagent.itemID, false, false, false) or 0) end
      end
      local makes = math.floor(have / need)
      if not most or makes < most then most = makes end
    end
  end
  return math.max(1, most or 1)
end
ns.CraftShortcutCount = Count

local pending -- { recipe, all, at }: a craft waiting for its profession to open

local function Make(recipeID, all)
  Api().CraftRecipe(recipeID, Count(recipeID, all))
end

function ns:CraftFromShortcut(recipeID, all)
  recipeID = tonumber(recipeID)
  local api = Api()
  if not (recipeID and api and api.CraftRecipe) then return end
  if Ready(recipeID) then
    pending = nil
    return Make(recipeID, all)
  end
  local line, parent
  if api.GetTradeSkillLineForRecipe then
    local ok, a, _, c = pcall(api.GetTradeSkillLineForRecipe, recipeID)
    if ok then line, parent = a, c end
  end
  if not line then return Say(L.CRAFT_SHORTCUT_UNKNOWN) end
  pending = { recipe = recipeID, all = all, at = GetTime() }
  local opened = api.OpenTradeSkill and api.OpenTradeSkill(parent or line)
  if opened == false then
    pending = nil
    Say(L.CRAFT_SHORTCUT_UNKNOWN)
  end
end

-- The macro's line (global: a macro reaches only globals)
function ClaraCraft(recipeID)
  ns:CraftFromShortcut(recipeID, IsShiftKeyDown and IsShiftKeyDown() or false)
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED",
  "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do
  pcall(events.RegisterEvent, events, e)
end
local lastMade
events:SetScript("OnEvent", function(_, event, who, what)
  if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
    -- (the game wanted a click for the craft its profession's opening made: the window is open now)
    if who == ADDON and lastMade and GetTime() - lastMade < 2 and tostring(what):find("CraftRecipe", 1, true) then
      lastMade = nil
      Say(L.CRAFT_SHORTCUT_AGAIN)
    end
    return
  end
  if not pending then return end
  if GetTime() - pending.at > WAIT then pending = nil return end
  if Ready(pending.recipe) then
    local p = pending
    pending = nil
    lastMade = GetTime()
    Make(p.recipe, p.all)
  end
end)

---------------------------------------------------------------------------
-- The shortcut's tooltip: the made item, and what a click does
---------------------------------------------------------------------------

local function ShortcutRecipe(slot)
  if not (GetActionInfo and GetMacroBody) then return nil end
  local kind, id = GetActionInfo(slot)
  if kind ~= "macro" or not id then return nil end
  return RecipeOf(GetMacroBody(id))
end

local function Tip(tip, slot)
  local recipeID = ShortcutRecipe(slot)
  if not recipeID then return end
  local api = Api()
  local output = api and api.GetRecipeOutputItemData and select(2, pcall(api.GetRecipeOutputItemData, recipeID))
  local itemID = type(output) == "table" and output.itemID
  if itemID and tip.SetItemByID then
    tip:SetItemByID(itemID)
  end
  tip:AddLine(L.CRAFT_SHORTCUT_TIP, 0.5, 0.8, 1, true)
  tip:Show()
end
ns.CraftShortcutTip = Tip
if GameTooltip and GameTooltip.SetAction then hooksecurefunc(GameTooltip, "SetAction", Tip) end

---------------------------------------------------------------------------
-- The icon dragged: the professions window's recipe (its made item's icon)
---------------------------------------------------------------------------

local function DragFrom(icon, recipe)
  if not icon or icon.claraCraftDrag then return end
  icon.claraCraftDrag = true
  icon:RegisterForDrag("LeftButton")
  icon:HookScript("OnDragStart", function()
    local recipeID = recipe()
    if recipeID then ns.CraftShortcut(recipeID) end
  end)
end
ns.CraftShortcutDragFrom = DragFrom

local function Setup()
  local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
  local form = page and page.SchematicForm
  if not (form and form.OutputIcon) then return end
  DragFrom(form.OutputIcon, function()
    local info = form.GetRecipeInfo and form:GetRecipeInfo()
    return type(info) == "table" and info.recipeID or nil
  end)
end
if EventUtil and EventUtil.ContinueOnAddOnLoaded then
  EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", Setup)
end
