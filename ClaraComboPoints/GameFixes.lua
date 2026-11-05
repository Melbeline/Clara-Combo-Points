-- Clara Combo Points - two of the game's own behaviours set right, for every class.
--   The raid frames kept where they are. After a raid update (a member or a pet coming or going,
--   a group change...) the game sizes their container 3000 x 3000 for a frame, then to its frames'
--   bounds, measured on the frames shown; Edit Mode keeps it on the screen, so meanwhile it stands
--   at the screen's top. With the interface hidden (Alt-Z) no frame of it is shown: its size stays
--   wrong, and the raid frames come back at the top of the screen. It is sized again from its
--   frames once they are shown (the interface back, out of combat), if its size is still wrong.
--   The game's icon in the taskbar does not flash (EnableBlinkApplicationIcon 0), unless the box in
--   the game's options (Esc > Options > AddOns > Clara Combo Points) is unticked.
-- And some of the game's own options set once, as Clara's defaults (then the player's own): Sticky
-- Targeting off, Auto Loot on, NPC Names on None, the bags separate (not combined). Those the game
-- keeps for each character, once for each character; those of the whole account, once.
-- And the unit menu's loot method line (the group's leader): a left-click on it, Free for All.
-- And the target and focus frames' health and power values at the right end of their bars.

local ADDON, ns = ...

---------------------------------------------------------------------------
-- The raid frames' container
---------------------------------------------------------------------------
local PLACEHOLDER = 2500 -- (bigger: the game's 3000 x 3000 while it lays the frames out)
local container = CompactRaidFrameContainer
local settler = CreateFrame("Frame")
local waiting = false -- sized once the interface is shown again

local function WrongSize()
  local w, h = container:GetSize()
  if type(w) ~= "number" or type(h) ~= "number" then return false end
  return w > PLACEHOLDER or h > PLACEHOLDER or w < 0 or h < 0
end

local function Settle()
  waiting = false
  settler:UnregisterEvent("PLAYER_REGEN_ENABLED")
  if not (container:IsShown() and WrongSize()) then return end
  if not UIParent:IsVisible() then
    waiting = true
    return
  end
  if InCombatLockdown() then -- (its frames are the game's protected ones: out of combat only)
    settler:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  container:RefreshSize()
end
settler:SetScript("OnEvent", Settle)

-- after the game's own sizing (the next frame)
local function Soon()
  C_Timer.After(0, Settle)
end

if container and container.LayoutFrames and container.RefreshSize then
  hooksecurefunc(container, "LayoutFrames", Soon)
  UIParent:HookScript("OnShow", function() if waiting or container:IsShown() then Soon() end end)
end
ns.SettleRaidFrames = container and Settle -- (for the tests)

---------------------------------------------------------------------------
-- The taskbar icon
---------------------------------------------------------------------------
local BLINK = "EnableBlinkApplicationIcon"

function ns:NoBlink() return not self.sv or self.sv.noBlink ~= false end

-- ticked: not flashing, set at each login; unticked: flashing again, once (then the player's own)
local function SetBlink(value)
  local cvar = C_CVar
  if not (cvar and cvar.GetCVar and cvar.SetCVar) then return end
  local now = cvar.GetCVar(BLINK)
  if now ~= nil and now ~= value then cvar.SetCVar(BLINK, value) end
end

function ns:SetNoBlink(on)
  if on then self.sv.noBlink = nil else self.sv.noBlink = false end
  SetBlink(on and "0" or "1")
end

---------------------------------------------------------------------------
-- The game's options set once (Clara's defaults)
---------------------------------------------------------------------------
local GAME_DEFAULTS_VERSION = 1 -- (a new option here: a new version, its options set once more)
local GAME_DEFAULTS = {
  { "deselectOnClick", "1" },                -- Sticky Targeting off (its box shows the value negated)
  { "autoLootDefault", "1" },                -- Auto Loot on
  { "combinedBags", "0" },                   -- the bags separate, not one combined bag
  { "UnitNameFriendlySpecialNPCName", "0" }, -- NPC Names: None (the game's own five values for it)
  { "UnitNameHostleNPC", "0" },
  { "UnitNameInteractiveNPC", "0" },
  { "UnitNameNPC", "0" },
  { "ShowQuestUnitCircles", "1" },
}

-- Whether the game keeps an option for each character (else for the whole account or computer)
local function PerCharacter(name)
  if not (C_CVar and C_CVar.GetCVarInfo) then return false end
  local _, _, _, perCharacter = C_CVar.GetCVarInfo(name)
  return perCharacter and true or false
end

function ns:ApplyGameDefaults()
  local sv = self.sv
  local cvar = C_CVar
  if not (sv and cvar and cvar.GetCVar and cvar.SetCVar) then return 0 end
  local me = UnitGUID and UnitGUID("player")
  sv.gameDefaultsChars = type(sv.gameDefaultsChars) == "table" and sv.gameDefaultsChars or {}
  local accountDone = (tonumber(sv.gameDefaults) or 0) >= GAME_DEFAULTS_VERSION
  local charDone = not me or (tonumber(sv.gameDefaultsChars[me]) or 0) >= GAME_DEFAULTS_VERSION
  local set = 0
  for _, d in ipairs(GAME_DEFAULTS) do
    local name, value = d[1], d[2]
    local now = cvar.GetCVar(name)
    local done = PerCharacter(name) and charDone or (not PerCharacter(name) and accountDone)
    if now ~= nil and not done and now ~= value then
      cvar.SetCVar(name, value)
      set = set + 1
    end
  end
  sv.gameDefaults = GAME_DEFAULTS_VERSION
  if me then sv.gameDefaultsChars[me] = GAME_DEFAULTS_VERSION end
  return set
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_LOGIN")
  if ns:NoBlink() then SetBlink("0") end
  ns:ApplyGameDefaults()
end)

---------------------------------------------------------------------------
-- The unit menu's loot method line ("Loot: Group Loot", the method in use): a left-click on it sets
-- Free for All at once (its list still opens under the mouse, for the others). The group's leader
-- only, as the game. The line is found by its text once shown (the game gives no other mark of it),
-- and only its own click is changed: the menu's other lines are left to the game.
---------------------------------------------------------------------------
local LOOT_NAMES = { "LOOT_FREE_FOR_ALL", "LOOT_ROUND_ROBIN", "MASTER_LOOTER", "LOOT_GROUP_LOOT",
  "LOOT_NEED_BEFORE_GREED", "PERSONAL_LOOT" }

function ns:IsLootMethodLine(text)
  if type(text) ~= "string" then return false end
  for _, key in ipairs(LOOT_NAMES) do
    local name = _G[key]
    if type(name) == "string" and name ~= "" and #text >= #name and text:sub(-#name) == name then return true end
  end
  return false
end

local function Leader() return IsInGroup and IsInGroup() and UnitIsGroupLeader and UnitIsGroupLeader("player") end

local function FreeForAll(_, input)
  local button = type(input) == "table" and input.buttonName or nil
  if button and button ~= "LeftButton" then return end
  if not (Leader() and C_PartyInfo and C_PartyInfo.SetLootMethod and Enum and Enum.LootMethod) then return end
  local ffa = Enum.LootMethod.Freeforall
  if ffa ~= nil and (not C_PartyInfo.GetLootMethod or C_PartyInfo.GetLootMethod() ~= ffa) then C_PartyInfo.SetLootMethod(ffa) end
end

local changed = setmetatable({}, { __mode = "k" })
local function LootLine(_, root)
  if not (Leader() and root and root.EnumerateElementDescriptions) then return end
  for _, description in root:EnumerateElementDescriptions() do
    local list = description.HasElements and select(2, pcall(description.HasElements, description))
    if list and description.AddInitializer and description.SetResponder then
      description:AddInitializer(function(button, d)
        local fs = button and (button.fontString or (button.GetFontString and button:GetFontString()))
        local text = fs and fs.GetText and fs:GetText()
        if changed[d] or not ns:IsLootMethodLine(text) then return end
        changed[d] = true
        d:SetResponder(FreeForAll)
      end)
    end
  end
end

if Menu and Menu.ModifyMenu then
  for _, tag in ipairs({ "MENU_UNIT_SELF", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER" }) do Menu.ModifyMenu(tag, LootLine) end
end

---------------------------------------------------------------------------
-- The target and focus frames' numbers: the health's and the power's right one (the value) at the
-- right end of its own bar, rather than out by the portrait. Not on ClassicUI's frames (its own).
---------------------------------------------------------------------------
local TEXT_FRAMES = { target = "TargetFrame", focus = "FocusFrame" }

local function ClassicFrames(unit)
  local cui = ns.ClassicUIPrivate
  local uf = cui and cui.UF
  return uf and uf.active and uf.On and uf.On(unit) and true or false
end

function ns:PlaceBarTexts(unit)
  local frame = _G[TEXT_FRAMES[unit]]
  local main = frame and frame.TargetFrameContent and frame.TargetFrameContent.TargetFrameContentMain
  local container = main and main.HealthBarsContainer
  local health = container and container.HealthBar
  if not (health and container.RightText) or ClassicFrames(unit) then return false end
  if InCombatLockdown and InCombatLockdown() and frame:IsProtected() then return false end
  container.RightText:ClearAllPoints()
  container.RightText:SetPoint("RIGHT", health, "RIGHT", -2, 0)
  local mana = main.ManaBar
  if mana and mana.RightText then
    -- its right end under the health's: the power bar runs a little further right, under the frame's art
    local hr, mr = health:GetRight(), mana:GetRight()
    local x = (hr and mr) and (hr - mr - 2) or -10
    mana.RightText:ClearAllPoints()
    mana.RightText:SetPoint("RIGHT", mana, "RIGHT", x, 0)
  end
  return true
end

local texts = CreateFrame("Frame")
texts:RegisterEvent("PLAYER_ENTERING_WORLD")
texts:RegisterEvent("PLAYER_TARGET_CHANGED")
texts:RegisterEvent("PLAYER_FOCUS_CHANGED")
texts:SetScript("OnEvent", function(_, event)
  if event ~= "PLAYER_FOCUS_CHANGED" then ns:PlaceBarTexts("target") end
  if event ~= "PLAYER_TARGET_CHANGED" then ns:PlaceBarTexts("focus") end
end)
