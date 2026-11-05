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

---------------------------------------------------------------------------
-- Unit frames: the unit's tooltip over the whole frame (portrait, name, level, edges and bars) for
-- the player, target, focus and pet frames and the party and raid frames; and the portrait and the
-- name clickable (target, menu) even where another frame of the low layer (the chat) lies over them.
-- The tooltip's owner is a frame of ours: the unit frame's own refresh had left it empty.
---------------------------------------------------------------------------
local issecretTip = issecretvalue or function() return false end
local TIP_FRAMES = { "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame" }
local tipOwner = CreateFrame("Frame", nil, UIParent)
tipOwner:SetSize(1, 1)
tipOwner:SetPoint("CENTER")
local tipFor -- the frame the tooltip of ours is shown for

local function TipUnit(frame)
  local unit = frame.displayedUnit or frame.unit or (frame.GetAttribute and frame:GetAttribute("unit"))
  if type(unit) ~= "string" or issecretTip(unit) or unit == "" then return nil end
  local exists = UnitExists(unit)
  if issecretTip(exists) or not exists then return nil end
  return unit
end

local function ShowUnitTip(frame, unit, compact)
  if not (GameTooltip and GameTooltip_SetDefaultAnchor) then return end
  GameTooltip_SetDefaultAnchor(GameTooltip, tipOwner)
  if not GameTooltip:SetUnit(unit) then return end
  if not compact and UNIT_POPUP_RIGHT_CLICK and GameTooltip_AddInstructionLine then
    if GameTooltip_AddBlankLineToTooltip then GameTooltip_AddBlankLineToTooltip(GameTooltip) end
    GameTooltip_AddInstructionLine(GameTooltip, UNIT_POPUP_RIGHT_CLICK)
  end
  GameTooltip:Show()
  tipFor = frame
end
ns.ShowUnitTip = ShowUnitTip

local function HideUnitTip()
  if GameTooltip and GameTooltip:IsOwned(tipOwner) then GameTooltip:Hide() end
  tipFor = nil
end

-- the frame under the mouse: a unit frame (its portrait too, where the game's art lies outside it), or
-- a party or raid frame
local function Portrait(frame)
  local container = frame.PlayerFrameContainer or frame.TargetFrameContainer
  if type(container) ~= "table" then return nil end
  local portrait = container.PlayerPortrait or container.Portrait
  if type(portrait) == "table" and portrait.IsMouseOver then return portrait end
end
local function Usable(f) return type(f) == "table" and f.IsVisible and f.IsMouseOver and f:IsVisible() end
local function UnderMouse()
  for _, name in ipairs(TIP_FRAMES) do
    local f = _G[name]
    if Usable(f) then
      local portrait = Portrait(f)
      if f:IsMouseOver() or (portrait and portrait:IsVisible() and portrait:IsMouseOver()) then return f, false end
    end
  end
  for i = 1, 5 do
    local f = _G["CompactPartyFrameMember" .. i]
    if Usable(f) and f:IsMouseOver() then return f, true end
  end
  for i = 1, 40 do
    local f = _G["CompactRaidFrame" .. i]
    if Usable(f) and f:IsMouseOver() then return f, true end
  end
end

-- the mouse on the frame itself, on one of its parts, on nothing, or on a frame of the low layer lying
-- over it (the chat): not on a window over it
local function Free(frame)
  local foci = GetMouseFoci and GetMouseFoci()
  local focus = foci and foci[1] or (GetMouseFocus and GetMouseFocus())
  if not focus or focus == WorldFrame then return true end
  local p = focus
  for _ = 1, 12 do
    if not p then break end
    if p == frame then return true end
    p = p.GetParent and p:GetParent()
  end
  local strata = focus.GetFrameStrata and focus:GetFrameStrata()
  return strata == "LOW" or strata == "BACKGROUND"
end

-- no tooltip, or an empty one (a buff's, a bar's numbers: theirs, left alone)
local function TipEmpty()
  if not GameTooltip:IsShown() then return true end
  local line = GameTooltipTextLeft1
  local text = line and line:GetText()
  if issecretTip(text) then return false end
  return text == nil or text == ""
end

local watch = CreateFrame("Frame")
local tipWait = 0
watch:SetScript("OnUpdate", function(_, elapsed)
  tipWait = tipWait + elapsed
  if tipWait < .1 then return end
  tipWait = 0
  if not GameTooltip then return end
  local frame, compact = UnderMouse()
  if frame then
    local unit = TipUnit(frame)
    if unit and Free(frame) and ((GameTooltip:IsOwned(tipOwner) and tipFor ~= frame) or TipEmpty()) then
      ShowUnitTip(frame, unit, compact)
    end
  elseif tipFor then
    HideUnitTip()
  end
end)

-- Over the portrait and the name: a button of ours (the game's secure one: target, menu), above the
-- low layer, so a chat lying over the frame takes neither the click nor the mouse.
local CATCH_PAD = 2
local function Catch(frame, region, pad)
  if not (frame and region) then return end
  local b = CreateFrame("Button", nil, frame, "SecureUnitButtonTemplate")
  b:SetPoint("TOPLEFT", region, "TOPLEFT", -pad, pad)
  b:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", pad, -pad)
  b:SetAttribute("unit", frame.unit or (frame.GetAttribute and frame:GetAttribute("unit")))
  b:SetAttribute("*type1", "target")
  b:SetAttribute("*type2", "togglemenu")
  b:RegisterForClicks("AnyUp")
  b:SetFrameLevel(frame:GetFrameLevel() + 30)
  b:SetScript("OnEnter", function()
    local unit = TipUnit(frame)
    if unit then ShowUnitTip(frame, unit) end
  end)
  b:SetScript("OnLeave", HideUnitTip)
  return b
end

local function CatchAll()
  if ns.unitCatchers then return true end
  if InCombatLockdown and InCombatLockdown() then return false end
  ns.unitCatchers = {}
  for _, name in ipairs({ "PlayerFrame", "TargetFrame", "FocusFrame" }) do
    local f = _G[name]
    if type(f) == "table" then
      pcall(function()
        local portrait = Portrait(f)
        local content = f.PlayerFrameContent or f.TargetFrameContent
        local main = type(content) == "table" and (content.PlayerFrameContentMain or content.TargetFrameContentMain) or nil
        local label = (name == "PlayerFrame" and _G.PlayerName) or (type(main) == "table" and main.Name) or nil
        for _, spot in ipairs({ { portrait, CATCH_PAD + 4 }, { label, CATCH_PAD } }) do
          if type(spot[1]) == "table" then
            local ok, b = pcall(Catch, f, spot[1], spot[2])
            if ok and b then ns.unitCatchers[#ns.unitCatchers + 1] = b end
          end
        end
      end)
    end
  end
  return true
end

local catchEvents = CreateFrame("Frame")
catchEvents:RegisterEvent("PLAYER_LOGIN")
catchEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
catchEvents:SetScript("OnEvent", function(self)
  if CatchAll() then self:UnregisterAllEvents() end
end)
