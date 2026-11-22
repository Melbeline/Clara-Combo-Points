-- Clara Combo Points - a recipe on the action bars. The made item's icon at the top of a recipe in the professions
-- window (and, with ClassicUI, the icon of its old trade skill window), dragged, puts the recipe's own spell on the
-- cursor, as Classic 1.15.9's macro does it (/run C_Spell.PickupSpell(<recipe>)): dropped on a bar, it is the game's
-- own button for that spell (its icon, its tooltip, its cooldown), and a click casts it: the item made, as the
-- game does. Not in a fight (the game gives no spell to an addon's cursor then). Recipes that work on an item picked
-- (salvage, recraft) or make nothing (gathering) stay off the bars.
-- The macros the first version made instead (/run ClaraCraft(<recipe>), whose click did nothing) are deleted at login,
-- once out of a fight; a line in the chat says how many, the recipes to drag again.

local ADDON, ns = ...
local L = ns.L

local OLD = "^/run if ClaraCraft then ClaraCraft%(%d+%) end%s*$" -- (the first version's macros)

local function Say(text)
  if not text then return end
  if UIErrorsFrame and UIErrorsFrame.AddMessage then
    UIErrorsFrame:AddMessage(text, 1, 0.82, 0)
  elseif DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("Clara: " .. text)
  end
end

-- Recipes that cannot run from a bar: they work on an item picked (salvage, recraft) or make nothing
local function Barred(info)
  return info.isSalvageRecipe or info.isRecraft or info.isGatheringRecipe or info.isDummyRecipe
end

local function Held()
  return GetCursorInfo and GetCursorInfo() or nil
end

-- The recipe's spell on the cursor, to be dropped on a bar
function ns.CraftShortcut(recipeID)
  recipeID = tonumber(recipeID)
  local api = C_TradeSkillUI
  local pickup = (C_Spell and C_Spell.PickupSpell) or PickupSpell
  if not (recipeID and api and pickup) then return end
  local info = api.GetRecipeInfo and api.GetRecipeInfo(recipeID)
  if type(info) ~= "table" then return end
  if Barred(info) then return Say(L.CRAFT_SHORTCUT_BARRED) end
  if info.learned == false then return Say(L.CRAFT_SHORTCUT_UNLEARNED) end
  if InCombatLockdown() then return Say(L.CRAFT_SHORTCUT_COMBAT) end
  if Held() and ClearCursor then ClearCursor() end
  local ok = pcall(pickup, recipeID)
  if not ok or not Held() then return Say(L.CRAFT_SHORTCUT_REFUSED) end
  return true
end

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

---------------------------------------------------------------------------
-- The first version's macros, deleted
---------------------------------------------------------------------------

local function MaxAccount()
  return (Constants and Constants.MacroConsts and Constants.MacroConsts.MAX_ACCOUNT_MACROS) or MAX_ACCOUNT_MACROS or 120
end

local function Old(i)
  local body = GetMacroBody(i)
  return type(body) == "string" and not (issecretvalue and issecretvalue(body)) and body:match(OLD) ~= nil
end

local function Cleanup()
  if not (GetNumMacros and GetMacroBody and DeleteMacro) then return true end
  if InCombatLockdown() then return false end
  local account, character = GetNumMacros()
  local base, gone = MaxAccount(), 0
  -- (from the last: the ones after a deleted macro move down one)
  for i = base + (character or 0), base + 1, -1 do
    if Old(i) then DeleteMacro(i); gone = gone + 1 end
  end
  for i = account or 0, 1, -1 do
    if Old(i) then DeleteMacro(i); gone = gone + 1 end
  end
  if gone > 0 and DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Clara|r: " .. L.CRAFT_SHORTCUT_OLD_GONE:format(gone))
  end
  return true
end
ns.CraftShortcutCleanup = Cleanup

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_ENTERING_WORLD" then
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    -- (a moment after, the macros loaded)
    C_Timer.After(3, function()
      if not Cleanup() then self:RegisterEvent("PLAYER_REGEN_ENABLED") end
    end)
  elseif event == "PLAYER_REGEN_ENABLED" then
    if Cleanup() then self:UnregisterEvent("PLAYER_REGEN_ENABLED") end
  end
end)
