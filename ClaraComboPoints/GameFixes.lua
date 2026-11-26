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
-- And a loot window left empty closed (a corpse clicked again and again while its items were on their way).
-- And the minimap's tracking (Find Herbs, Find Minerals, a hunter's tracking) given back after a death.
-- And the quest tracker folded again as the player left it (the whole tracker and each of its sections).
-- And the group role the player picks kept for each character, set again in the next groups.
-- And the windows the game refused in a fight, in the mouse report, with the protected ones and why.
-- And /played always answered in the chat (in a fight it showed nothing).
-- And the bags above AtlasLoot's window while it is open.
-- And the stopwatch kept for each character through reloads and logouts, its time going on meanwhile.
-- And the world map left open when a quest window opens (it stands beside the map instead of replacing it).
-- And a right-click on the minimap's tracking button turns the tracking spell off.

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
  -- (not in combat: the game's menu as it is, nothing of an addon's in it then)
  if InCombatLockdown() or not (Leader() and root and root.EnumerateElementDescriptions) then return end
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

-- Each value's spot (font string -> { unit, bar, x }): put back there when something else moves it (the game
-- re-lays its frame), never while ClassicUI's frames hold the unit (they keep their own).
local barTextSpots = setmetatable({}, { __mode = "k" })
local placingBarText = false
local barTextMoves, barTextFrameAt = 0, 0
local function PutBarText(fs)
  local spot = barTextSpots[fs]
  if not spot or ClassicFrames(spot.unit) then return end
  local frame = _G[TEXT_FRAMES[spot.unit]]
  if InCombatLockdown and InCombatLockdown() and frame and frame:IsProtected() then return end
  -- (never a tug of war with another keeper: a few moves a frame at most)
  local now = GetTime()
  if now ~= barTextFrameAt then barTextFrameAt, barTextMoves = now, 0 end
  barTextMoves = barTextMoves + 1
  if barTextMoves > 12 then return end
  placingBarText = true
  fs:ClearAllPoints()
  fs:SetPoint("RIGHT", spot.bar, "RIGHT", spot.x, 0)
  placingBarText = false
end
-- (run inside the game's own calls too, a secure click's target change: its answers can be secret there, never
-- compared; the text is then simply put back)
local secretText = issecretvalue or function() return false end
local function BarTextMoved(fs)
  if placingBarText then return end
  local spot = barTextSpots[fs]
  if not spot or ClassicFrames(spot.unit) then return end
  local okN, n = pcall(fs.GetNumPoints, fs)
  local ok, point, rel = pcall(fs.GetPoint, fs, 1)
  if okN and ok and not (secretText(n) or secretText(point) or secretText(rel))
    and n == 1 and point == "RIGHT" and rel == spot.bar then return end
  PutBarText(fs)
end
local function KeepBarText(fs, unit, bar, x)
  if type(fs) ~= "table" or type(fs.SetPoint) ~= "function" then return false end
  local known = barTextSpots[fs]
  barTextSpots[fs] = { unit = unit, bar = bar, x = x }
  if not known then hooksecurefunc(fs, "SetPoint", BarTextMoved) end
  PutBarText(fs)
  return true
end

function ns:PlaceBarTexts(unit)
  local frame = _G[TEXT_FRAMES[unit]]
  local main = frame and frame.TargetFrameContent and frame.TargetFrameContent.TargetFrameContentMain
  local container = main and main.HealthBarsContainer
  local health = container and container.HealthBar
  if type(health) ~= "table" or ClassicFrames(unit) then return false end
  if InCombatLockdown and InCombatLockdown() and frame:IsProtected() then return false end
  -- the value the game writes: the bar's own string and the container's (whichever it uses), both at the bar's end
  local done = false
  if KeepBarText(health.RightText, unit, health, -2) then done = true end
  if container.RightText ~= health.RightText and KeepBarText(container.RightText, unit, health, -2) then done = true end
  local mana = main.ManaBar
  if type(mana) == "table" and type(mana.RightText) == "table" then
    -- its right end under the health's: the power bar runs a little further right, under the frame's art
    local hr, mr = health:GetRight(), mana:GetRight()
    -- (secret while the game hides the frame's geometry: the usual spot then)
    local known = hr and mr and not secretText(hr) and not secretText(mr)
    local x = known and (hr - mr - 2) or -10
    KeepBarText(mana.RightText, unit, mana, x)
  end
  return done
end

-- Where each of the target's and focus's texts stands (for /cl souris): which one shows the value
function ns:BarTextsReport(Line)
  local out = {}
  for _, unit in ipairs({ "target", "focus" }) do
    local frame = _G[TEXT_FRAMES[unit]]
    local main = frame and frame.TargetFrameContent and frame.TargetFrameContent.TargetFrameContentMain
    local container = main and main.HealthBarsContainer
    local health = container and container.HealthBar
    local mana = main and main.ManaBar
    out[#out + 1] = ("%s frame texts (ClassicUI's frames: %s)"):format(unit, tostring(ClassicFrames(unit)))
    if type(health) == "table" then
      for _, pair in ipairs({ { "bar.TextString", health.TextString }, { "bar.LeftText", health.LeftText },
        { "bar.RightText", health.RightText }, { "container.HealthBarText", container.HealthBarText },
        { "container.LeftText", container.LeftText }, { "container.RightText", container.RightText },
        { "mana.RightText", type(mana) == "table" and mana.RightText or nil } }) do
        out[#out + 1] = "    " .. Line(pair[1], pair[2])
      end
    end
  end
  return out
end

local texts = CreateFrame("Frame")
texts:RegisterEvent("PLAYER_ENTERING_WORLD")
texts:RegisterEvent("PLAYER_TARGET_CHANGED")
texts:RegisterEvent("PLAYER_FOCUS_CHANGED")
texts:RegisterEvent("PLAYER_REGEN_ENABLED") -- (moved by the game in a fight: put back after it)
texts:SetScript("OnEvent", function(_, event)
  if event ~= "PLAYER_FOCUS_CHANGED" then ns:PlaceBarTexts("target") end
  if event ~= "PLAYER_TARGET_CHANGED" then ns:PlaceBarTexts("focus") end
end)

---------------------------------------------------------------------------
-- An empty loot window closed. With some lag (or a corpse clicked again and again) the corpse is opened
-- a second time while the items of the first opening are still on their way to the bags: they leave
-- this one too, the server has closed the loot already, and the game, which closes the window as its
-- last item is taken or as one walks away, keeps it open with nothing in it. Looked at a moment after it
-- opens and after each item taken: nothing left, closed.

local lootOpen, lootLook

local function LootEmpty()
  local n = type(GetNumLootItems) == "function" and GetNumLootItems() or 0
  if type(n) ~= "number" or (issecretvalue and issecretvalue(n)) then return false end
  for i = 1, n do
    local kind = type(GetLootSlotType) == "function" and GetLootSlotType(i)
    if kind == nil or (issecretvalue and issecretvalue(kind)) or kind ~= 0 then return false end
  end
  return true
end

local function LootShown()
  local frame = _G.LootFrame
  return type(frame) == "table" and type(frame.IsShown) == "function" and frame:IsShown() == true
end

local function LootLook()
  lootLook = nil
  if not (lootOpen or LootShown()) or not LootEmpty() then return end
  lootOpen = nil
  if type(CloseLoot) == "function" then CloseLoot() end
  -- (the loot closed by the server already: the game's window, still waiting for word of it a moment later,
  -- hidden here)
  C_Timer.After(0.5, function()
    if LootShown() and LootEmpty() then _G.LootFrame:Hide() end
  end)
end

local loot = CreateFrame("Frame")
loot:RegisterEvent("LOOT_OPENED")
loot:RegisterEvent("LOOT_SLOT_CLEARED")
loot:RegisterEvent("LOOT_CLOSED")
loot:SetScript("OnEvent", function(_, event)
  if event == "LOOT_CLOSED" then lootOpen = nil return end
  if event == "LOOT_OPENED" then lootOpen = true end
  if (lootOpen or LootShown()) and not lootLook then
    lootLook = true
    C_Timer.After(0.3, LootLook)
  end
end)

---------------------------------------------------------------------------
-- A player's tooltip: its title with the whole name, "First Surname" (WoW Forever's names), whatever
-- the game's name settings hide; a title (rank) kept. Over a unit frame, the unit from the frame
-- (the tooltip's own can be secret).
---------------------------------------------------------------------------
do
  local secret = issecretvalue or function() return false end
  local function Token(unit)
    if type(unit) == "string" and not secret(unit) and unit ~= "" then return unit end
  end
  local function WholeTitle(tip)
    if not (ns.UnitWholeName and tip and tip.GetName and tip.GetUnit) then return end
    local unit = Token(select(2, tip:GetUnit()))
    if not unit and tip.GetOwner then
      local owner = tip:GetOwner()
      if owner and not (owner.IsForbidden and owner:IsForbidden()) then unit = Token(owner.unit) end
    end
    if not unit then return end
    local player = UnitIsPlayer(unit)
    if secret(player) or not player then return end
    local name = tip:GetName()
    local line = name and _G[name .. "TextLeft1"]
    if not (line and line.GetText) then return end
    local text = line:GetText()
    local whole = ns.UnitWholeName(unit, text)
    if whole == nil then return end
    if secret(whole) or secret(text) or whole ~= text then line:SetText(whole) end
  end
  ns.TooltipWholeTitle = WholeTitle -- (for the tests)
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tip) pcall(WholeTitle, tip) end)
  end
end

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
  local ok, exists = pcall(UnitExists, unit)
  if not ok or issecretTip(exists) or not exists then return nil end
  return unit
end

local function ShowUnitTip(frame, unit, compact)
  if not (GameTooltip and GameTooltip_SetDefaultAnchor) then return end
  GameTooltip_SetDefaultAnchor(GameTooltip, tipOwner)
  local ok, set = pcall(GameTooltip.SetUnit, GameTooltip, unit)
  if not ok or (not issecretTip(set) and set == false) then return end
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
-- (a secret answer counts as no: this client refuses to compare or test one)
local function Yes(f, method, ...)
  local fn = type(f) == "table" and f[method]
  if type(fn) ~= "function" then return false end
  local ok, v = pcall(fn, f, ...)
  if not ok or issecretTip(v) then return false end
  return v == true
end
local function Usable(f) return Yes(f, "IsVisible") end
local function UnderMouse()
  for _, name in ipairs(TIP_FRAMES) do
    local f = _G[name]
    if Usable(f) then
      local portrait = Portrait(f)
      if Yes(f, "IsMouseOver") or (portrait and Yes(portrait, "IsVisible") and Yes(portrait, "IsMouseOver")) then return f, false end
    end
  end
  for i = 1, 5 do
    local f = _G["CompactPartyFrameMember" .. i]
    if Usable(f) and Yes(f, "IsMouseOver") then return f, true end
  end
  for i = 1, 40 do
    local f = _G["CompactRaidFrame" .. i]
    if Usable(f) and Yes(f, "IsMouseOver") then return f, true end
  end
end

-- the mouse on the frame itself, on one of its parts, on nothing, or on a frame of the low layer lying
-- over it (the chat): not on a window over it
local function Free(frame)
  local foci = GetMouseFoci and GetMouseFoci()
  local focus = foci and foci[1] or (GetMouseFocus and GetMouseFocus())
  if not focus or focus == WorldFrame then return true end
  if focus.IsForbidden and focus:IsForbidden() then return false end -- (the game's secure dialogs: a window over it)
  local p = focus
  for _ = 1, 12 do
    if not p or (p.IsForbidden and p:IsForbidden()) then break end
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

---------------------------------------------------------------------------
-- /cl souris (/cl mouse): every frame under the mouse, as /fstack lists them, with what /fstack shows
-- only for one (where it was made: its source), in a window whose text is all selected, to copy
-- (Ctrl+C). Taken 3 seconds after the command, the time to put the mouse on the spot.
---------------------------------------------------------------------------
local L = ns.L
local STRATA_ORDER = { WORLD = 0, BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6,
  FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local secretR = issecretvalue or function() return false end
local function Plain(v)
  if secretR(v) then return "?" end
  return v
end
local function Call(f, method, ...)
  local fn = f[method]
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d, e = pcall(fn, f, ...)
  if not ok then return nil end
  return a, b, c, d, e
end
local function NameOf(f)
  if not f then return "nil" end
  local name = Call(f, "GetDebugName")
  if secretR(name) then return "(secret)" end
  if type(name) ~= "string" or name == "" then name = Call(f, "GetName") end
  if secretR(name) then return "(secret)" end
  if type(name) ~= "string" or name == "" then return tostring(f) end
  return name
end
local function Num(v) v = Plain(v) return type(v) == "number" and ("%.0f"):format(v) or tostring(v) end

local function Describe(f, focus)
  local lines = {}
  local mouse = Call(f, "IsMouseEnabled")
  local click, motion = Call(f, "IsMouseClickEnabled"), Call(f, "IsMouseMotionEnabled")
  local w, h = Call(f, "GetSize")
  local left, bottom = Call(f, "GetLeft"), Call(f, "GetBottom")
  local takes = (Plain(click) == true and "click" or "") .. (Plain(motion) == true and "+hover" or "")
  if takes == "" and Plain(mouse) == true then takes = "mouse" end
  lines[1] = ("%s<%s> %s %s  [%s]  %sx%s at %s,%s"):format(focus and "--> " or "    ", Num(Call(f, "GetFrameLevel")),
    tostring(Plain(Call(f, "GetFrameStrata"))), NameOf(f), takes ~= "" and takes or "no mouse", Num(w), Num(h),
    Num(left), Num(bottom))
  local point, rel, relPoint, x, y = Call(f, "GetPoint", 1)
  if not secretR(point) and point then
    lines[#lines + 1] = ("        point: %s %s %s %s %s"):format(tostring(Plain(point)), NameOf((not secretR(rel) and type(rel) == "table") and rel or nil),
      tostring(Plain(relPoint)), Num(x), Num(y))
  end
  local source = Call(f, "GetSourceLocation")
  if not secretR(source) and source then lines[#lines + 1] = "        source: " .. tostring(source) end
  local parent = Call(f, "GetParent")
  if parent then lines[#lines + 1] = "        parent: " .. NameOf(parent) end
  return table.concat(lines, "\n")
end

local reportBox
local function ReportBox()
  if reportBox then return reportBox end
  local f = CreateFrame("Frame", "ClaraMouseReport", UIParent, "BackdropTemplate")
  f:SetSize(760, 520)
  f:SetPoint("CENTER")
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if f.SetBackdrop then
    f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    f:SetBackdropColor(0, 0, 0, .92)
    f:SetBackdropBorderColor(.72, .58, .34, 1)
  end
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.title:SetPoint("TOPLEFT", 14, -12)
  f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.hint:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
  f.hint:SetPoint("RIGHT", -40, 0)
  f.hint:SetJustifyH("LEFT")
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -2)
  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -48)
  scroll:SetPoint("BOTTOMRIGHT", -32, 12)
  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
  edit:SetWidth(700)
  edit:SetScript("OnEscapePressed", function() f:Hide() end)
  edit:SetScript("OnTextChanged", function(self, user) if user then self:SetText(f.text or "") self:HighlightText() end end)
  edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  scroll:SetScrollChild(edit)
  f.edit = edit
  f:SetScript("OnMouseUp", function() edit:SetFocus() edit:HighlightText() end)
  if UISpecialFrames then table.insert(UISpecialFrames, "ClaraMouseReport") end
  if ns.DressDialog then ns:DressDialog(f, { close = close }) end
  reportBox = f
  return f
end

function ns:MouseReport()
  local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
  local isFocus = {}
  for _, f in ipairs(foci or {}) do if f then isFocus[f] = true end end
  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  local list, keys = {}, {}
  local f = EnumerateFrames and EnumerateFrames()
  local guard = 0
  while f and guard < 200000 do
    guard = guard + 1
    if f ~= reportBox and Plain(Call(f, "IsVisible")) == true and Plain(Call(f, "IsMouseOver")) == true then
      list[#list + 1] = f
      local level = Plain(Call(f, "GetFrameLevel"))
      keys[f] = (STRATA_ORDER[Plain(Call(f, "GetFrameStrata"))] or 0) * 100000 + (type(level) == "number" and level or 0)
    end
    local ok, nextFrame = pcall(EnumerateFrames, f)
    f = ok and nextFrame or nil
  end
  table.sort(list, function(a, b) return keys[a] > keys[b] end)
  local out = {}
  out[#out + 1] = ("Clara %s  ·  cursor %.0f, %.0f  ·  %d frames under it"):format(ns.VERSION or "", x / scale, y / scale, #list)
  out[#out + 1] = "mouse focus: " .. (foci and foci[1] and NameOf(foci[1]) or "none (the world)")
  out[#out + 1] = ""
  for _, frame in ipairs(list) do out[#out + 1] = Describe(frame, isFocus[frame]) end
  out[#out + 1] = ""
  local function TextLine(label, fs)
    if type(fs) ~= "table" or type(fs.GetText) ~= "function" then return label .. ": none" end
    local text = Call(fs, "GetText")
    local point, rel, relPoint, x, y = Call(fs, "GetPoint", 1)
    return ("%s: %s, shown %s, %s %s %s %s,%s, left %s"):format(label, secretR(text) and "(secret)" or tostring(text),
      tostring(Plain(Call(fs, "IsShown"))), tostring(Plain(point)), NameOf((not secretR(rel) and type(rel) == "table") and rel or nil),
      tostring(Plain(relPoint)), Num(x), Num(y), Num(Call(fs, "GetLeft")))
  end
  for _, line in ipairs(ns.BarTextsReport and ns:BarTextsReport(TextLine) or {}) do out[#out + 1] = line end
  if ns.HudIconsReport then
    local ok, lines = pcall(ns.HudIconsReport, ns)
    if ok and type(lines) == "table" then for _, line in ipairs(lines) do out[#out + 1] = line end end
  end
  if ns.TrackerFoldsReport then
    local ok, lines = pcall(ns.TrackerFoldsReport, ns)
    if ok and type(lines) == "table" then for _, line in ipairs(lines) do out[#out + 1] = line end end
  end
  if ns.AltFriends and ns.AltFriends.BnetReport then
    local ok, lines = pcall(ns.AltFriends.BnetReport)
    if ok and type(lines) == "table" then for _, line in ipairs(lines) do out[#out + 1] = line end end
  end
  if ns.FightWindowsReport then
    local ok, lines = pcall(ns.FightWindowsReport, ns)
    if ok and type(lines) == "table" then for _, line in ipairs(lines) do out[#out + 1] = line end end
  end
  if ns.BagClickTaintReport then
    local ok, lines = pcall(ns.BagClickTaintReport, ns)
    if ok and type(lines) == "table" then for _, line in ipairs(lines) do out[#out + 1] = line end end
  end
  if ns.DisenchantReport then
    local ok, line = pcall(ns.DisenchantReport, ns)
    if ok and line then out[#out + 1] = line end
  end
  if ns.RecipeCountsReport then
    local ok, line = pcall(ns.RecipeCountsReport, ns)
    if ok and line then out[#out + 1] = line end
  end
  if ns.RecipeMemoryReport then
    local ok, lines = pcall(ns.RecipeMemoryReport, ns)
    if ok and type(lines) == "table" then for _, line in ipairs(lines) do out[#out + 1] = line end end
  end
  if ns.CommunityChatReport then
    local ok, line = pcall(ns.CommunityChatReport, ns)
    if ok and line then out[#out + 1] = line end
  end
  if ns.QuestShareReport then
    local ok, line = pcall(ns.QuestShareReport, ns)
    if ok and line then out[#out + 1] = line end
  end
  if ns.CraftListReport then
    local ok, lines = pcall(ns.CraftListReport, ns)
    if ok and type(lines) == "table" then for _, line in ipairs(lines) do out[#out + 1] = line end
    elseif not ok then out[#out + 1] = "professions list: " .. tostring(lines) end
  end
  local text = table.concat(out, "\n")
  -- kept in the saved file too (SavedVariables\ClaraComboPoints.lua, written at the next /reload or logout)
  if ns.sv then ns.sv.mouseReport = text end
  local box = ReportBox()
  box.text = text
  box.title:SetText(L.MOUSE_REPORT_TITLE)
  box.hint:SetText(L.MOUSE_REPORT_HINT)
  box.edit:SetText(box.text)
  box:Show()
  box.edit:SetFocus()
  box.edit:HighlightText()
  return box.text
end

local function Say(text, r, g, b)
  if UIErrorsFrame and UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage(text, r or 1, g or .82, b or 0, 1, 1.5) end
end
-- /cl chat: each chat window, its tab and its typing bar as they stand (shown, alpha, parent, DynamicCam's fade marks),
-- in the same window to copy: what makes a chat vanish.
function ns:ChatReport()
  local out = { ("Clara %s  ·  chat"):format(ns.VERSION or "") }
  local function Pct(v)
    v = Plain(v)
    return type(v) == "number" and ("%.0f%%"):format(v * 100) or tostring(v)
  end
  local function Line(label, f)
    if type(f) ~= "table" or type(f.GetAlpha) ~= "function" then return label .. ": none" end
    local parent = Call(f, "GetParent")
    local point, rel, relPoint, x, y = Call(f, "GetPoint", 1)
    return ("%s: shown %s visible %s alpha %s eff %s ignoreParent %s parent %s [%s %s] %s %s %s %s,%s  dc fade %s after %s on %s"):format(label,
      tostring(Plain(Call(f, "IsShown"))), tostring(Plain(Call(f, "IsVisible"))), Pct(Call(f, "GetAlpha")),
      Pct(Call(f, "GetEffectiveAlpha")), tostring(Plain(Call(f, "IsIgnoringParentAlpha"))),
      NameOf(parent), tostring(Plain(Call(f, "GetFrameStrata"))), Num(Call(f, "GetFrameLevel")), tostring(Plain(point)),
      NameOf((not secretR(rel) and type(rel) == "table") and rel or nil), tostring(Plain(relPoint)), Num(x), Num(y),
      tostring(rawget(f, "ludius_fadeout")), tostring(rawget(f, "ludius_alphaAfterFadeOut")), tostring(rawget(f, "ludius_alreadyOnIt")))
  end
  out[#out + 1] = Line("UIParent", UIParent)
  out[#out + 1] = Line("GeneralDockManager", _G.GeneralDockManager)
  local selected = _G.SELECTED_CHAT_FRAME or _G.SELECTED_DOCK_FRAME
  out[#out + 1] = "selected: " .. NameOf(selected) .. "  ·  combat log: " .. NameOf(_G.COMBATLOG)
  for i = 1, math.max(NUM_CHAT_WINDOWS or 0, 20) do
    local chat = _G["ChatFrame" .. i]
    if chat then
      out[#out + 1] = ""
      out[#out + 1] = Line("ChatFrame" .. i, chat) .. ("  docked %s faded %s"):format(tostring(rawget(chat, "isDocked")),
        tostring(rawget(chat, "hasBeenFaded")))
      out[#out + 1] = "    " .. Line("tab", _G["ChatFrame" .. i .. "Tab"])
      out[#out + 1] = "    " .. Line("editBox", _G["ChatFrame" .. i .. "EditBox"])
      out[#out + 1] = "    " .. Line("background", rawget(chat, "Background"))
      out[#out + 1] = "    " .. Line("buttonFrame", rawget(chat, "buttonFrame"))
    end
  end
  out[#out + 1] = ""
  out[#out + 1] = Line("CombatLogQuickButtonFrame_Custom", _G.CombatLogQuickButtonFrame_Custom)
  -- the game's chat functions replaced by an addon (its name): their code then runs in the middle of the game's
  local replaced = {}
  if type(issecurevariable) == "function" then
    for _, name in ipairs({ "FCF_StartAlertFlash", "FCF_StopAlertFlash", "FCFManager_StopFlashOnDedicatedWindows",
      "FCF_FadeInChatFrame", "FCF_FadeOutChatFrame", "FCFTab_UpdateAlpha", "FCF_OnUpdate", "FCF_Tab_OnClick",
      "FCF_SelectDockFrame", "FCFDock_UpdateTabs", "UIFrameFade", "UIFrameFadeIn", "UIFrameFadeOut",
      "UIFrameFade_OnUpdate", "UIFrameFadeRemoveFrame" }) do
      local ok, secure, by = pcall(issecurevariable, name)
      if ok and secure == false then replaced[#replaced + 1] = ("%s (%s)"):format(name, tostring(by)) end
    end
  end
  out[#out + 1] = "replaced chat functions: " .. (#replaced > 0 and table.concat(replaced, ", ") or "none")
  local dc = LibStub and LibStub("AceAddon-3.0", true)
  dc = dc and dc:GetAddon("DynamicCam", true)
  out[#out + 1] = ("DynamicCam: %s, situation %s"):format(dc and (dc.IsEnabled and tostring(dc:IsEnabled()) or "yes") or "none",
    tostring(dc and dc.currentSituationID))
  local text = table.concat(out, "\n")
  if ns.sv then ns.sv.chatReport = text end
  local box = ReportBox()
  box.text = text
  box.title:SetText(L.CHAT_REPORT_TITLE)
  box.hint:SetText(L.MOUSE_REPORT_HINT)
  box.edit:SetText(text)
  box:Show()
  box.edit:SetFocus()
  box.edit:HighlightText()
  return text
end

function ns:MouseReportSoon()
  print("|cffffd200Clara|r: " .. L.MOUSE_REPORT_SOON)
  -- the count on the middle of the screen: 3, 2, 1, then taken
  for i = 3, 1, -1 do C_Timer.After(3 - i, function() Say(tostring(i)) end) end
  C_Timer.After(3, function()
    local ok, result = xpcall(function() return ns:MouseReport() end, function(e) return tostring(e) end)
    if ok then
      local n = 0
      for _ in tostring(result):gmatch("\n    ") do n = n + 1 end
      Say(L.MOUSE_REPORT_DONE, .2, 1, .2)
      print("|cffffd200Clara|r: " .. L.MOUSE_REPORT_SAVED)
    else
      print("|cffff6060Clara|r: /cl souris: " .. tostring(result))
      Say("Clara: /cl souris: " .. tostring(result), 1, .3, .3)
    end
  end)
end

---------------------------------------------------------------------------
-- The minimap's tracking given back after a death. The game drops its tracking spells at death (Find Herbs,
-- Find Minerals, a hunter's Track Beasts...): the ones on just before are turned back on once the character
-- lives again. C_Minimap.SetTracking is not one of the game's protected functions (its documentation gives it
-- no restriction): tried at once. One the game does not take then (a spell it casts only on a key press or a
-- click) is turned on at the next movement key, unbound key or click in the world: one press, one tracking;
-- the key's own move, or the camera's, is left as it is. A key that does something else (a spell, an
-- interface key) is never used: its own action stays its own. One tracking a press (the game's global
-- cooldown between two); given up once the player picks another tracking, or after ten tries.
-- Kept in the saved settings for each character: a reload while dead gives them back too.
---------------------------------------------------------------------------
local MOVE_KEYS = { MOVEFORWARD = true, MOVEBACKWARD = true, TURNLEFT = true, TURNRIGHT = true, STRAFELEFT = true,
  STRAFERIGHT = true, JUMP = true, TOGGLEAUTORUN = true, MOVEANDSTEER = true, [""] = true }
local TRACK_GAP, TRACK_TRIES = 1.6, 10
local tracked = {}  -- the tracking spells on, as last seen alive (spell ID or name -> true)
local lost          -- the ones to give back (a list), or nil
local tries, lastTry = 0, 0
local trackCatch    -- the frame that hears the keys while some are still to give back

local function Alive() return not (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) end
local function TrackKey(info) return info.spellID or info.name end
-- The tracking spells on now: key -> its index in the game's list; and each one's index
local function TrackingNow()
  local on, index = {}, {}
  if not (C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then return on, index end
  for i = 1, C_Minimap.GetNumTrackingTypes() or 0 do
    local ok, info = pcall(C_Minimap.GetTrackingInfo, i)
    if ok and type(info) == "table" and info.type == "spell" and TrackKey(info) ~= nil then
      index[TrackKey(info)] = i
      if info.active then on[TrackKey(info)] = i end
    end
  end
  return on, index
end

local function Me() return ns.FullName and ns:FullName("player") or (UnitName and UnitName("player")) end
local function SaveLost()
  local sv = ns.sv
  if not sv then return end
  local me = Me()
  if not me then return end
  sv.trackingLost = type(sv.trackingLost) == "table" and sv.trackingLost or {}
  sv.trackingLost[me] = lost and #lost > 0 and lost or nil
  if not next(sv.trackingLost) then sv.trackingLost = nil end
end

-- Those still to give back: the ones the game has, not on now
local function Missing()
  if not lost then return {} end
  local on, index = TrackingNow()
  local missing = {}
  for _, key in ipairs(lost) do
    if not on[key] and index[key] then missing[#missing + 1] = { key = key, index = index[key] } end
  end
  return missing, on
end

local function Done()
  lost, tries = nil, 0
  SaveLost()
  if trackCatch then trackCatch:Hide() end
end

local GiveOne
local function Check()
  if not lost then return end
  if not Alive() then return end
  local missing = Missing()
  if #missing == 0 or tries >= TRACK_TRIES then Done() return end
  -- still some: the next press (the game took nothing without one), or at once if the last one went through
  if trackCatch then trackCatch:Show() end
end

-- One tracking turned on (the first one missing); looked at again after the global cooldown
function GiveOne(byKey)
  if not lost or not Alive() then return end
  local now = GetTime and GetTime() or 0
  if now - lastTry < TRACK_GAP then return end
  local missing = Missing()
  if #missing == 0 then Done() return end
  lastTry, tries = now, tries + 1
  pcall(C_Minimap.SetTracking, missing[1].index, true)
  C_Timer.After(TRACK_GAP, function()
    if not lost then return end
    local left = Missing()
    if #left == 0 or tries >= TRACK_TRIES then Done()
    elseif #left < #missing and not byKey then GiveOne(false) -- (taken without a press: the next one the same way)
    else Check() end
  end)
end

local function MakeCatch()
  if trackCatch or InCombatLockdown() then return end -- (its keys passed on: set out of combat)
  local f = CreateFrame("Frame", nil, UIParent)
  f:Hide()
  f:EnableKeyboard(true)
  if f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(true) end -- (every key goes on to the game)
  f:SetScript("OnKeyDown", function(_, key)
    if not lost then f:Hide() return end
    local chord = CreateKeyChordStringUsingMetaKeyState and CreateKeyChordStringUsingMetaKeyState(key) or key
    local action = GetBindingAction and GetBindingAction(chord, true) or ""
    if MOVE_KEYS[action or ""] then GiveOne(true) end
  end)
  trackCatch = f
  if WorldFrame and WorldFrame.HookScript then
    WorldFrame:HookScript("OnMouseDown", function() if lost and trackCatch:IsShown() then GiveOne(true) end end)
  end
end

local tracking = CreateFrame("Frame")
tracking:RegisterEvent("PLAYER_LOGIN")
tracking:RegisterEvent("PLAYER_DEAD")
tracking:RegisterEvent("PLAYER_ALIVE")
tracking:RegisterEvent("PLAYER_UNGHOST")
tracking:RegisterEvent("MINIMAP_UPDATE_TRACKING")
tracking:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" then
    MakeCatch()
    local me, sv = Me(), ns.sv
    local kept = me and sv and type(sv.trackingLost) == "table" and sv.trackingLost[me]
    if type(kept) == "table" and #kept > 0 then lost = kept end
    if Alive() then
      tracked = TrackingNow()
      if lost then C_Timer.After(2, function() GiveOne(false) end) end
    end
  elseif event == "PLAYER_DEAD" then
    local list = {}
    for key in pairs(tracked) do list[#list + 1] = key end
    if #list > 0 then lost, tries, lastTry = list, 0, 0 SaveLost() end
  elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
    MakeCatch()
    if lost and Alive() then C_Timer.After(1, function() GiveOne(false) end) end -- (a release: still a ghost, nothing)
  elseif event == "MINIMAP_UPDATE_TRACKING" then
    -- what is on, a moment later and only alive (at death the game drops them before the character counts as dead)
    C_Timer.After(.5, function()
      if not Alive() then return end
      local on = TrackingNow()
      if lost then
        local mine = {}
        for _, key in ipairs(lost) do mine[key] = true end
        for key in pairs(on) do
          if not mine[key] then Done() break end -- (another one picked by the player: theirs)
        end
      end
      tracked = on
    end)
  end
end)

---------------------------------------------------------------------------
-- The quest tracker folded as the player left it. The game opens it whole at each login and reload. A click on
-- one of its fold buttons (All Objectives, or a section's: Quests, Achievements...) is kept at once, for each
-- character; only those clicks count, so a fold the game itself undoes (a quest popup opens the tracker) comes
-- back at the next login. Folded again by the game's own fold, out of combat: as the game adds each section to
-- the tracker (at login it does so only once its settings have come, which can be seconds after the world
-- shows), and over the first seconds after a login or reload, should something open it meanwhile; a click of
-- the player's ends that. Only what the player folded is ever folded: a section left open is never touched.
-- The tracker is not one of the game's protected frames (no fight check anywhere in it; its quest item buttons
-- keep their quest in attributes, which an addon's code does not taint). Its last folds and openings, and who
-- made them, go in the mouse report (/cl souris).
---------------------------------------------------------------------------
local FOLD_FOR = 12 -- seconds after a login or reload during which a kept fold is put back
local FOLD_AT = { 0, 1, 3, 6, 11 }
local foldUntil, foldClicked, foldWaits, foldSoon, folding, addHooked = 0, false, false, false, false, nil
local foldWatched, foldLog, loginAt = {}, {}, nil
local foldEvents = CreateFrame("Frame")

local function TrackerSections()
  local list, tracker = {}, ObjectiveTrackerFrame
  if tracker and type(tracker.modules) == "table" then
    for _, module in ipairs(tracker.modules) do
      local name = type(module) == "table" and module.GetName and module:GetName()
      if type(name) == "string" and module.IsCollapsed and module.SetCollapsed then
        list[#list + 1] = { name = name, module = module }
      end
    end
  end
  return list
end

-- This character's kept folds ({ all = true, QuestObjectiveTracker = true... }); made only when asked
local function Folds(make)
  local sv, me = ns.sv, Me()
  if not (sv and me) then return end
  if type(sv.trackerFolds) ~= "table" then
    if not make then return end
    sv.trackerFolds = {}
  end
  if type(sv.trackerFolds[me]) ~= "table" then
    if not make then return end
    sv.trackerFolds[me] = {}
  end
  return sv.trackerFolds[me], me
end

local function Keep(key, folded)
  local folds, me = Folds(folded)
  if not folds then return end
  folds[key] = folded or nil
  if not next(folds) then ns.sv.trackerFolds[me] = nil end
  if not next(ns.sv.trackerFolds) then ns.sv.trackerFolds = nil end
end

-- Who folded or opened it: the first file of the call that is not the tracker's own fold
local function FoldCaller()
  if folding then return "Clara" end
  local ok, stack = pcall(debugstack, 2, 12, 0)
  if not ok or type(stack) ~= "string" then return "?" end
  for line in stack:gmatch("[^\n]+") do
    local file, num = line:match("([%w_]+)%.lua[\"%]]*:(%d+)")
    if file and file ~= "Blizzard_ObjectiveTrackerModule" and file ~= "Blizzard_ObjectiveTrackerContainer"
      and file ~= "GameFixes" then
      return file .. ":" .. num
    end
  end
  return "?"
end

local function Watch(owner, key)
  if foldWatched[owner] then return end
  foldWatched[owner] = true
  if type(owner.SetCollapsed) == "function" then
    hooksecurefunc(owner, "SetCollapsed", function(_, folded)
      foldLog[#foldLog + 1] = { at = GetTime(), key = key, folded = folded == true, by = FoldCaller() }
      if #foldLog > 8 then table.remove(foldLog, 1) end
    end)
  end
  local button = owner.Header and owner.Header.MinimizeButton
  if button and button.HookScript then
    button:HookScript("OnClick", function()
      if type(owner.IsCollapsed) ~= "function" then return end
      local folded = owner:IsCollapsed() == true
      foldClicked = true -- the player's own choice from now on: nothing folded again this session
      Keep(key, folded)
      local last = foldLog[#foldLog]
      if last and last.key == key and last.at == GetTime() then last.by = "click" end
    end)
  end
end

local function FoldOne(owner, key, folds)
  if not folds[key] or owner:IsCollapsed() then return end
  folding = true
  local ok, err = pcall(owner.SetCollapsed, owner, true)
  folding = false
  if not ok then geterrorhandler()(err) end
end

local function FoldAll()
  local tracker = ObjectiveTrackerFrame
  if not (tracker and tracker.IsCollapsed and tracker.SetCollapsed) then return end
  local sections = TrackerSections()
  Watch(tracker, "all")
  for _, section in ipairs(sections) do Watch(section.module, section.name) end
  if foldClicked or GetTime() > foldUntil then return end
  local folds = Folds(false)
  if not folds then return end
  if InCombatLockdown() then
    if not foldWaits then foldWaits = true foldEvents:RegisterEvent("PLAYER_REGEN_ENABLED") end
    return
  end
  for _, section in ipairs(sections) do FoldOne(section.module, section.name, folds) end
  FoldOne(tracker, "all", folds)
end

-- A section added by the game: folded on the next frame, out of the game's own call
local function FoldSoon()
  if foldSoon then return end
  foldSoon = true
  C_Timer.After(0, function() foldSoon = false FoldAll() end)
end

local function HookTracker()
  local tracker = ObjectiveTrackerFrame
  if not tracker or addHooked == tracker or type(tracker.AddModule) ~= "function" then return end
  addHooked = tracker
  hooksecurefunc(tracker, "AddModule", FoldSoon)
end
HookTracker()

function ns:TrackerFoldsReport()
  local tracker = ObjectiveTrackerFrame
  if not (tracker and tracker.IsCollapsed) then return { "quest tracker: none" } end
  local kept = {}
  for key in pairs(Folds(false) or {}) do kept[#kept + 1] = key end
  table.sort(kept)
  local now = { "all " .. (tracker:IsCollapsed() and "folded" or "open") }
  for _, section in ipairs(TrackerSections()) do
    if section.module:IsCollapsed() then now[#now + 1] = section.name .. " folded" end
  end
  local out = { ("quest tracker folds: kept %s  ·  now %s"):format(#kept > 0 and table.concat(kept, ", ") or "none",
    table.concat(now, ", ")) }
  for _, entry in ipairs(foldLog) do
    out[#out + 1] = ("    %+.1fs after login: %s %s by %s"):format(entry.at - (loginAt or 0), entry.key,
      entry.folded and "folded" or "opened", entry.by)
  end
  return out
end

foldEvents:RegisterEvent("ADDON_LOADED")
foldEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
foldEvents:SetScript("OnEvent", function(self, event, arg1, arg2)
  if event == "ADDON_LOADED" then
    if arg1 == "Blizzard_ObjectiveTracker" then HookTracker() FoldSoon() end
  elseif event == "PLAYER_REGEN_ENABLED" then
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    foldWaits = false
    foldUntil = math.max(foldUntil, GetTime() + 2) -- (the fight took the first seconds)
    FoldAll()
  elseif arg1 or arg2 then -- a login or a reload (a zone change leaves the tracker as it is)
    loginAt = GetTime()
    foldUntil, foldClicked = GetTime() + FOLD_FOR, false
    HookTracker()
    for _, delay in ipairs(FOLD_AT) do C_Timer.After(delay, FoldAll) end
  end
end)

---------------------------------------------------------------------------
-- The group role chosen by the player kept for each character. The game forgets it with the group: in the next
-- one the character starts with no role. The role the player sets for themself (Set Role on their own frame's
-- menu, the group finder's role, the answer to a role check) is kept; "No Role" forgets it. Set again by the
-- game's own call, 2 seconds after joining a group and after a login or reload in a group (once the game has
-- the group's roles), out of combat, when the game allows a role to be picked (as its Set Role menu: not in a
-- group finder group or a scenario) and the class can take it. Only then: a role the leader gives afterwards
-- is left as it is.
---------------------------------------------------------------------------
local ROLE_DELAY = 2
local ROLE_NAMES = { [0] = "TANK", [1] = "HEALER", [2] = "DAMAGER" }
local roleSetting, roleWaits = false, false
local roleEvents = CreateFrame("Frame")

local function EnumRole(role)
  if Enum and Enum.LFGRole and type(role) == "number" then
    for name, value in pairs(Enum.LFGRole) do
      if value == role then return ({ Tank = "TANK", Healer = "HEALER", Damage = "DAMAGER" })[name] end
    end
  end
  return ROLE_NAMES[role]
end

local function IsPlayer(unit)
  if issecretvalue(unit) or type(unit) ~= "string" then return false end
  if unit == "player" then return true end
  local ok, same = pcall(UnitIsUnit, unit, "player")
  return ok and not issecretvalue(same) and same == true
end

local function KeepRole(unit, role)
  if roleSetting or not IsPlayer(unit) then return end
  local sv, me = ns.sv, Me()
  if not (sv and me) then return end
  if role ~= "TANK" and role ~= "HEALER" and role ~= "DAMAGER" then role = nil end -- (No Role: forgotten)
  if role then
    sv.groupRoles = type(sv.groupRoles) == "table" and sv.groupRoles or {}
    sv.groupRoles[me] = role
  elseif type(sv.groupRoles) == "table" then
    sv.groupRoles[me] = nil
    if not next(sv.groupRoles) then sv.groupRoles = nil end
  end
end

if type(UnitSetRoleEnum) == "function" then
  hooksecurefunc("UnitSetRoleEnum", function(unit, role) KeepRole(unit, EnumRole(role)) end)
end
if type(UnitSetRole) == "function" then
  hooksecurefunc("UnitSetRole", function(unit, role) KeepRole(unit, role) end)
end

-- What the game's Set Role menu asks before it shows (Blizzard_UnitPopupShared)
local function CanPickRole()
  if not IsInGroup() then return false end
  if CanShowSetRoleButton and not CanShowSetRoleButton() then return false end
  if C_Scenario and C_Scenario.IsInScenario and C_Scenario.IsInScenario() then return false end
  local override = OverrideLFGSetRoleRestriction and select(2, pcall(OverrideLFGSetRoleRestriction))
  if HasLFGRestrictions and HasLFGRestrictions() and override ~= true then return false end
  return true
end

local function ClassCanTake(role)
  if AreClassRolesSoftSuggestions and AreClassRolesSoftSuggestions() then return true end
  if not UnitGetAvailableRoles then return true end
  local tank, healer, damager = UnitGetAvailableRoles("player")
  return (role == "TANK" and tank) or (role == "HEALER" and healer) or (role == "DAMAGER" and damager) or false
end

local function SetRoleAgain()
  local sv, me = ns.sv, Me()
  local role = sv and me and type(sv.groupRoles) == "table" and sv.groupRoles[me]
  if not role or not CanPickRole() then return end
  if InCombatLockdown() then
    if not roleWaits then roleWaits = true roleEvents:RegisterEvent("PLAYER_REGEN_ENABLED") end
    return
  end
  local now = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
  if issecretvalue(now) or now == role or not ClassCanTake(role) then return end
  roleSetting = true
  local ok, err = pcall(UnitSetRole, "player", role)
  roleSetting = false
  if not ok then geterrorhandler()(err) end
end

roleEvents:RegisterEvent("GROUP_JOINED")
roleEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
roleEvents:SetScript("OnEvent", function(self, event, isLogin, isReload)
  if event == "PLAYER_REGEN_ENABLED" then
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    roleWaits = false
    SetRoleAgain()
  elseif event == "GROUP_JOINED" or isLogin or isReload then -- (a zone change keeps the group's roles)
    C_Timer.After(ROLE_DELAY, SetRoleAgain)
  end
end)

---------------------------------------------------------------------------
-- Windows in a fight, for the mouse report (/cl souris). What the game refused this session in a fight: a window its
-- panel manager did not show (and who asked), its "Interface action failed" message and who made it, Clara's own
-- "can't do that in combat" refusals and where they came from, and the blocked calls the game names (any addon). And,
-- read when the report is made, the game's windows that are protected now (the game refuses them to any touched path
-- in a fight), with the protected frames inside them that make them so. Only read and noted: nothing is changed.
---------------------------------------------------------------------------
local FIGHT_LOG_MAX = 12
local fightLog = {}
local function FightNote(text)
  fightLog[#fightLog + 1] = (date and date("%H:%M:%S") or "") .. "  " .. text
  if #fightLog > FIGHT_LOG_MAX then table.remove(fightLog, 1) end
end

-- The first file of the call outside the game's panel manager, its chat message, its error frame and this file
local SKIP_FILES = { UIParentPanelManager = true, ChatFrameUtil = true, GameFixes = true, Dialogs = true }
local function FightCaller(skipDialogs)
  local ok, stack = pcall(debugstack, 2, 14, 0)
  if not ok or type(stack) ~= "string" then return "?", false end
  local ours = stack:find("AddOns/ClaraComboPoints", 1, true) ~= nil
  for line in stack:gmatch("[^\n]+") do
    local file, num = line:match("([%w_]+)%.lua[\"%]]*:(%d+)")
    if file and not SKIP_FILES[file] then return file .. ":" .. num, ours end
  end
  return "the game's own key or button", ours
end

local function FrameName(frame)
  local ok, name = pcall(function() return frame:GetDebugName() end)
  if ok and type(name) == "string" and name ~= "" then return name end
  ok, name = pcall(frame.GetName, frame)
  return ok and type(name) == "string" and name or tostring(frame)
end

if type(ShowUIPanel) == "function" then
  hooksecurefunc("ShowUIPanel", function(frame)
    if not InCombatLockdown() or type(frame) ~= "table" or not frame.IsShown then return end
    local ok, shown = pcall(frame.IsShown, frame)
    if ok and shown == false then
      local by = FightCaller()
      local okP, protected = pcall(frame.IsProtected, frame)
      FightNote(("%s not shown (asked by %s%s)"):format(FrameName(frame), by,
        okP and protected and ", the window protected" or ""))
    end
  end)
end
if type(DisplayInterfaceActionBlockedMessage) == "function" then
  hooksecurefunc("DisplayInterfaceActionBlockedMessage", function()
    FightNote("\"Interface action failed\" (" .. FightCaller() .. ")")
  end)
end
if UIErrorsFrame and type(UIErrorsFrame.AddMessage) == "function" then
  hooksecurefunc(UIErrorsFrame, "AddMessage", function(_, text)
    if issecretvalue(text) or type(text) ~= "string" or text ~= ERR_NOT_IN_COMBAT then return end
    local by, ours = FightCaller()
    if ours then FightNote("\"" .. text .. "\" from " .. by) end
  end)
end
local blockedEvents = CreateFrame("Frame")
blockedEvents:RegisterEvent("ADDON_ACTION_BLOCKED")
blockedEvents:RegisterEvent("ADDON_ACTION_FORBIDDEN")
blockedEvents:SetScript("OnEvent", function(_, event, addon, func)
  FightNote(("%s: %s %s"):format(event == "ADDON_ACTION_FORBIDDEN" and "forbidden" or "blocked", tostring(addon), tostring(func)))
end)

-- The explicitly protected frames inside a window (its own, or ours hung in it), up to three
local function ProtectedInside(frame)
  local found, seen, queue, head = {}, 0, { frame }, 1
  while head <= #queue and seen < 600 and #found < 3 do
    local f = queue[head]
    head = head + 1
    local ok, kids = pcall(function() return { f:GetChildren() } end)
    if ok then
      for _, kid in ipairs(kids) do
        seen = seen + 1
        local okP, _, explicit = pcall(kid.IsProtected, kid)
        if okP and explicit and #found < 3 then found[#found + 1] = FrameName(kid) end
        queue[#queue + 1] = kid
      end
    end
  end
  return found
end

-- A bag item under the mouse: what its right-click reads (the game's ContainerFrameItemButton_OnClick and what it calls),
-- each value an addon wrote named with that addon (the game's own issecurevariable). One of them written by an addon:
-- the item's use is refused to that addon's name ("forbidden: <addon> UNKNOWN()"). Only read: nothing is changed.
local BAG_CLICK_GLOBALS = { "ContainerFrameItemButton_OnClick", "ContainerFrameItemButtonMixin", "MerchantFrame_ResetRefundItem",
  "MerchantFrame", "AuctionHouseFrame", "AzeriteRespecFrame", "RuneforgeFrame", "BankFrame", "BankPanel", "GuildBankFrame",
  "MailFrame", "AuctionFrame", "TradeFrame", "ItemUpgradeFrame", "ObliterumForgeFrame", "ChallengesKeystoneFrame",
  "ArtifactFrame", "C_ItemSocketInfo", "C_ArtifactUI", "C_MountJournal", "CollectionsJournal", "CollectionsJournal_LoadUI",
  "BankUtil_IsAccountBankDepositRefundable", "ItemButtonUtil", "StackSplitFrame", "C_Container", "C_Item", "C_Spell",
  "C_AuctionHouse", "C_NewItems", "ItemLocation", "ItemLocationMixin", "IsModifiedClick", "GetCursorInfo",
  "SpellCanTargetItem", "SpellCanTargetItemID", "SpellIsTargeting", "EventRegistry", "ContainerFrame_GetExtendedPriceString",
  "CreateFromMixins", "Mixin", "UIErrorsFrame", "GameTooltip", "ResetCursor", "SetCursorHoveredItem", "CanSellItems" }
local BAG_CLICK_TABLES = { "C_Container", "C_Item", "C_Spell", "C_AuctionHouse", "C_ItemSocketInfo", "C_ArtifactUI",
  "C_MountJournal", "ItemButtonUtil", "ItemLocation", "ItemLocationMixin", "MerchantFrame", "MailFrame", "BankFrame",
  "BankPanel", "TradeFrame", "ContainerFrameItemButtonMixin", "EventRegistry", "StackSplitFrame" }
local function BagButtonUnder()
  local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
  local f = foci and foci[1]
  if type(f) == "table" and type(f.GetBagID) == "function" and type(f.GetID) == "function" then return f end
end

-- Which of a table's fields an addon wrote: a list of "label.key (addon)"; a table all of whose fields one addon wrote
-- (made while that addon's code ran: a frame from the game's template, made in its name) in one line
local function TaintedFields(label, t, limit)
  local list, total, by1, same = {}, 0, nil, true
  if type(t) ~= "table" or type(issecurevariable) ~= "function" then return list, 0 end
  local n = 0
  for k in pairs(t) do
    n = n + 1
    if n > (limit or 600) then break end
    if type(k) == "string" and not (issecretvalue and issecretvalue(k)) then
      total = total + 1
      local ok, secure, by = pcall(issecurevariable, t, k)
      if ok and secure == false then
        list[#list + 1] = ("%s.%s (%s)"):format(label, k, tostring(by))
        if by1 == nil then by1 = by elseif by1 ~= by then same = false end
      else
        same = false
      end
    end
  end
  if total > 3 and same and #list == total then
    return { ("%s: all %d of its fields (made while %s's code ran)"):format(label, total, tostring(by1)) }, total
  end
  return list, total
end

-- The bag windows the game built in an addon's name this session (their item list, written anew at each build, an
-- addon's): when, which, in whose name, who opened it (the calls), and the first values an addon wrote among what
-- the build reads (the bag bar, the side action bars, the bag windows' manager)
local BAG_BUILD_TABLES = { "ContainerFrameSettingsManager", "ContainerFrameContainer", "MultiBarLeft", "MultiBarRight",
  "BagsBar", "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot",
  "CharacterBag3Slot", "CharacterReagentBag0Slot", "BankFrame", "EditModeUtil" }
local bagBuilds, BAG_BUILDS_MAX = {}, 6
local function Calls()
  local ok, stack = pcall(debugstack, 3, 14, 0)
  if not ok or type(stack) ~= "string" then return "?" end
  local calls = {}
  for line in stack:gmatch("[^\n]+") do
    local file, num = line:match("([%w_]+)%.lua[\"%]]*:(%d+)")
    local fn = line:match("in function [`'<]([^'>]+)")
    if file then calls[#calls + 1] = file .. ":" .. num .. (fn and (" " .. fn) or "") end
    if #calls >= 8 then break end
  end
  return #calls > 0 and table.concat(calls, " < ") or "?"
end
local function WatchBagBuilds()
  if type(ContainerFrame_GenerateFrame) ~= "function" or type(issecurevariable) ~= "function" then return end
  hooksecurefunc("ContainerFrame_GenerateFrame", function(frame, size, id)
    local ok, secure, by = pcall(issecurevariable, frame, "Items")
    if not ok or secure ~= false then return end
    local seen = {}
    for _, name in ipairs(BAG_BUILD_TABLES) do
      local list = TaintedFields(name, _G[name], 300)
      for _, line in ipairs(list) do if #seen < 5 then seen[#seen + 1] = line end end
    end
    bagBuilds[#bagBuilds + 1] = ("%s  bag %s (%s) built in %s's name; opened by: %s%s"):format(
      date and date("%H:%M:%S") or "", tostring(id), NameOf(frame), tostring(by), Calls(),
      #seen > 0 and ("; written by an addon among what it reads: " .. table.concat(seen, ", ")) or "")
    if #bagBuilds > BAG_BUILDS_MAX then table.remove(bagBuilds, 1) end
  end)
end
local watchBags = CreateFrame("Frame")
watchBags:RegisterEvent("PLAYER_LOGIN")
watchBags:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  pcall(WatchBagBuilds)
end)
ns.BagBuildsLog = bagBuilds -- (for the tests)

function ns:BagClickTaintReport(button)
  button = button or BagButtonUnder()
  local out = {}
  if button then
    if type(issecurevariable) ~= "function" then return { "bag item click: the game's issecurevariable is missing" } end
    local tainted, seen = {}, 0
    local function Add(list, total) seen = seen + total for _, line in ipairs(list) do tainted[#tainted + 1] = line end end
    for _, name in ipairs(BAG_CLICK_GLOBALS) do
      seen = seen + 1
      local ok, secure, by = pcall(issecurevariable, name)
      if ok and secure == false then tainted[#tainted + 1] = ("%s (%s)"):format(name, tostring(by)) end
    end
    for _, name in ipairs(BAG_CLICK_TABLES) do Add(TaintedFields(name, _G[name])) end
    Add(TaintedFields(NameOf(button), button)) -- (the item's button: its own fields, its methods)
    local okParent, bag = pcall(button.GetParent, button)
    if okParent and type(bag) == "table" then Add(TaintedFields(NameOf(bag), bag)) end -- (its bag window)
    out[1] = ("bag item click (%s): what its right-click reads, %d values: %s"):format(NameOf(button), seen,
      #tainted > 0 and "written by an addon:" or "none written by an addon")
    table.sort(tainted)
    for i = 1, math.min(#tainted, 40) do out[#out + 1] = "    " .. tainted[i] end
    if #tainted > 40 then out[#out + 1] = ("    ... and %d more"):format(#tainted - 40) end
  end
  if #bagBuilds > 0 then
    out[#out + 1] = "bag windows built in an addon's name this session:"
    for _, line in ipairs(bagBuilds) do out[#out + 1] = "    " .. line end
  end
  return out
end

local EXTRA_WINDOWS = { "WorldMapFrame", "LFGParentFrame", "RaidParentFrame", "CooldownViewerSettings", "SocialUIFrame" }
function ns:FightWindowsReport()
  local out = { "windows in a fight (" .. (#fightLog > 0 and "refused this session:" or "nothing refused this session") .. ")" }
  for _, line in ipairs(fightLog) do out[#out + 1] = "    " .. line end
  local names, listed = {}, {}
  for name in pairs(type(UIPanelWindows) == "table" and UIPanelWindows or {}) do
    if type(name) == "string" then names[#names + 1] = name listed[name] = true end
  end
  for _, name in ipairs(EXTRA_WINDOWS) do if not listed[name] then names[#names + 1] = name end end
  table.sort(names)
  local protected = {}
  for _, name in ipairs(names) do
    local frame = _G[name]
    if type(frame) == "table" and frame.IsProtected then
      local ok, isProtected = pcall(frame.IsProtected, frame)
      if ok and isProtected then
        local inside = ProtectedInside(frame)
        protected[#protected + 1] = "    " .. name .. ": " .. (#inside > 0 and table.concat(inside, ", ") or "itself or by an anchor")
      end
    end
  end
  out[#out + 1] = "game windows protected now (refused in a fight to a touched path): " .. (#protected > 0 and "" or "none")
  for _, line in ipairs(protected) do out[#out + 1] = line end
  return out
end

---------------------------------------------------------------------------
-- /played always answered. In a fight the game's answer (TIME_PLAYED_MSG) came, and no chat window showed it.
-- Looked at the next frame: a line with the game's own "Total time played" text written meanwhile in a chat
-- window means it was shown; else written in the main chat window by the game's own function, as it writes it.
---------------------------------------------------------------------------
local playedSeen = 0 -- lines of the game's /played text written in the chat windows
local playedPrefix = type(TIME_PLAYED_TOTAL) == "string" and TIME_PLAYED_TOTAL:match("^(.-)%%") or nil
local watchedChats = {}
local function WatchChat(frame)
  if not frame or watchedChats[frame] or not frame.AddMessage or not playedPrefix or playedPrefix == "" then return end
  watchedChats[frame] = true
  hooksecurefunc(frame, "AddMessage", function(_, text)
    if type(text) == "string" and not issecretvalue(text) and text:find(playedPrefix, 1, true) then
      playedSeen = playedSeen + 1
    end
  end)
end

local played = CreateFrame("Frame")
played:RegisterEvent("PLAYER_LOGIN")
played:RegisterEvent("TIME_PLAYED_MSG")
played:SetScript("OnEvent", function(_, event, total, level)
  if event == "PLAYER_LOGIN" then
    for i = 1, NUM_CHAT_WINDOWS or 10 do WatchChat(_G["ChatFrame" .. i]) end
    return
  end
  if not playedPrefix then return end
  local before = playedSeen
  C_Timer.After(0, function()
    if playedSeen > before then return end -- (shown by the game)
    if issecretvalue(total) or issecretvalue(level) or type(total) ~= "number" or type(level) ~= "number" then return end
    local Display = ChatFrameUtil and ChatFrameUtil.DisplayTimePlayed or ChatFrame_DisplayTimePlayed
    if DEFAULT_CHAT_FRAME and Display then pcall(Display, DEFAULT_CHAT_FRAME, total, level) end
  end)
end)

---------------------------------------------------------------------------
-- The bags above AtlasLoot. Its window stands in a strata above the bags' (the game's: MEDIUM), so a bag opened
-- while it is open went under it. While its window is shown, the bags take the strata just above its own; it
-- closed, they get their own back. Whatever strata AtlasLoot's version uses (read from its window each time).
-- Never on a frame the game protects in a fight (none of the game's bags is; then after the fight).
---------------------------------------------------------------------------
local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
local STRATA_RANK = {}
for i, name in ipairs(STRATA) do STRATA_RANK[name] = i end
local ATLASLOOT_FRAMES = { "AtlasLoot_GUI-Frame", "AtlasLootDefaultFrame", "AtlasLoot_Frame" }
local bagStrata = setmetatable({}, { __mode = "k" }) -- each bag's own strata, while lifted
local liftEvents = CreateFrame("Frame")

local function AtlasLootShown()
  for _, name in ipairs(ATLASLOOT_FRAMES) do
    local f = _G[name]
    if type(f) == "table" and f.IsShown and f:IsShown() then return f end
  end
end
-- The game's bag windows, read by their names. Never by the game's own ContainerFrameUtil_EnumerateContainerFrames: it
-- makes its list the first time it is called and keeps it, so called from Clara the list was made in Clara's name, and
-- every bag window the game built from it then (its item buttons too) was Clara's: the items' right-click (their use)
-- refused ("forbidden: ClaraComboPoints UNKNOWN()") until a reload.
function ns.ContainerFrames()
  local list = {}
  local count = tonumber(NUM_CONTAINER_FRAMES) or 13
  for i = 1, math.min(count, 20) do
    local frame = _G["ContainerFrame" .. i]
    if type(frame) == "table" then list[#list + 1] = frame end
  end
  if type(ContainerFrameCombinedBags) == "table" then list[#list + 1] = ContainerFrameCombinedBags end
  return list
end
local function Bags() return ns.ContainerFrames() end

local function LiftBags()
  local atlas = AtlasLootShown()
  local want = atlas and STRATA[math.min(#STRATA - 1, (STRATA_RANK[atlas:GetFrameStrata()] or 3) + 1)]
  for _, bag in ipairs(Bags()) do
    if bag.SetFrameStrata and not (InCombatLockdown() and bag:IsProtected()) then
      if want then
        if not bagStrata[bag] then bagStrata[bag] = bag:GetFrameStrata() end
        if (STRATA_RANK[bag:GetFrameStrata()] or 0) < STRATA_RANK[want] then bag:SetFrameStrata(want) end
      elseif bagStrata[bag] then
        bag:SetFrameStrata(bagStrata[bag])
        bagStrata[bag] = nil
      end
    elseif InCombatLockdown() then
      liftEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
  end
end

-- Hooked as each is there: the bags (their own show), AtlasLoot's window (made on its first opening)
local hookedLift = setmetatable({}, { __mode = "k" })
local function HookLift(frame)
  if type(frame) ~= "table" or not frame.HookScript or hookedLift[frame] then return end
  hookedLift[frame] = true
  frame:HookScript("OnShow", LiftBags)
  frame:HookScript("OnHide", LiftBags)
end
local function HookAll()
  for _, bag in ipairs(Bags()) do HookLift(bag) end
  for _, name in ipairs(ATLASLOOT_FRAMES) do HookLift(_G[name]) end
end

-- AtlasLoot makes its window on its first opening: looked for every 2 s once AtlasLoot is loaded, until found
local lookTicker
local function Look()
  if lookTicker or not C_Timer.NewTicker then return end
  lookTicker = C_Timer.NewTicker(2, function()
    HookAll()
    for _, name in ipairs(ATLASLOOT_FRAMES) do
      if _G[name] then lookTicker:Cancel() LiftBags() return end
    end
  end)
end
local function AtlasLootLoaded()
  local A = C_AddOns
  for _, name in ipairs({ "AtlasLootClassic", "AtlasLoot" }) do
    if A and A.IsAddOnLoaded and A.IsAddOnLoaded(name) then return true end
  end
end

liftEvents:RegisterEvent("PLAYER_LOGIN")
liftEvents:RegisterEvent("ADDON_LOADED")
liftEvents:SetScript("OnEvent", function(self, event, name)
  if event == "PLAYER_REGEN_ENABLED" then self:UnregisterEvent(event) LiftBags() return end
  if event == "ADDON_LOADED" and not (type(name) == "string" and name:find("^AtlasLoot")) then return end
  if event == "PLAYER_LOGIN" and not AtlasLootLoaded() then return end -- (nothing to do without AtlasLoot)
  HookAll()
  Look()
  LiftBags()
end)

---------------------------------------------------------------------------
-- The stopwatch kept. The game's own stopwatch (/stopwatch, the clock's menu) is cleared and shut by a reload or
-- a logout. Kept for each character: shown, running or paused, its time, and when it was left; back at the
-- character's next login (or after the reload), the time spent away added while it was running (the computer's
-- clock: a logout, another character played meanwhile, the game closed), as if it had never stopped; a paused
-- one comes back as it was; a countdown that ran out meanwhile is not shown again. Another character has its own.
---------------------------------------------------------------------------
local function WatchKey() return UnitGUID and UnitGUID("player") or nil end

local function KeepStopwatch()
  local sv, key = ns.sv, WatchKey()
  if not (sv and key) then return end
  local frame, ticker = _G.StopwatchFrame, _G.StopwatchTicker
  local entry
  if frame and ticker then
    local playing = Stopwatch_IsPlaying and Stopwatch_IsPlaying() and true or false
    local timer = tonumber(ticker.timer) or 0
    if frame:IsShown() or playing or timer > 0 then
      entry = { shown = frame:IsShown() and true or false, playing = playing, timer = timer,
        reverse = ticker.reverse and true or false, at = time(), gt = GetTime() }
    end
  end
  sv.stopwatch = type(sv.stopwatch) == "table" and sv.stopwatch or {}
  sv.stopwatch[key] = entry
  if not next(sv.stopwatch) then sv.stopwatch = nil end
end

local function BringStopwatch(isReload)
  local sv, key = ns.sv, WatchKey()
  local entry = key and sv and type(sv.stopwatch) == "table" and sv.stopwatch[key]
  if type(entry) ~= "table" then return end
  if C_AddOns and C_AddOns.IsAddOnLoaded and not C_AddOns.IsAddOnLoaded("Blizzard_TimeManager") and C_AddOns.LoadAddOn then
    pcall(C_AddOns.LoadAddOn, "Blizzard_TimeManager")
  end
  local frame, ticker = _G.StopwatchFrame, _G.StopwatchTicker
  if not (frame and ticker and StopwatchTicker_Update) then return end
  local timer = tonumber(entry.timer) or 0
  if entry.playing then
    -- the time away: a reload measured to the millisecond (the computer's uptime goes on), else to the second
    local away = time() - (tonumber(entry.at) or time())
    local gone = GetTime() - (tonumber(entry.gt) or 0)
    if isReload and entry.gt and gone >= 0 and gone < away + 2 then away = gone end
    away = math.max(0, away)
    timer = entry.reverse and timer - away or timer + away
    if entry.reverse and timer <= 0 then -- (a countdown ended while away: over)
      sv.stopwatch[key] = nil
      return
    end
  end
  ticker.timer = math.max(0, timer)
  ticker.reverse = entry.reverse and true or false
  StopwatchTicker_Update()
  if entry.shown and not frame:IsShown() then frame:Show() end
  if entry.playing and Stopwatch_Play then Stopwatch_Play() end
end

local watchEvents = CreateFrame("Frame")
watchEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
watchEvents:RegisterEvent("PLAYER_LOGOUT")
watchEvents:SetScript("OnEvent", function(_, event, isLogin, isReload)
  if event == "PLAYER_LOGOUT" then KeepStopwatch() return end
  if not (isLogin or isReload) then return end
  C_Timer.After(1, function() BringStopwatch(isReload) end) -- (the game's own stopwatch cleared at its load first)
end)

---------------------------------------------------------------------------
-- A system message the game repeats word for word while you do nothing: shown once. WoW Forever sends "You have been
-- inactive for some time and will be logged out of the game..." again and again until the idle logout, filling the
-- chat. Read by its repeat, not by its words (any language): the same text again, with nothing done since it first
-- showed, is not shown again. Anything done (moving, a click, a cast, a new target, a fight) or ten minutes ends that
-- quiet spell. The same line in several chat windows shows in each.
---------------------------------------------------------------------------
do
  local AddFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
  local issecretRepeat = issecretvalue or function() return false end
  local QUIET_FOR = 600
  local seen = {} -- text -> { line = its line ID, at = when it first showed }, while nothing is done
  if AddFilter then
    -- ("No player named ..." left to the friends list (AltFriends.lua): it holds such a line back and shows it again;
    -- taken here for a repeat, it never came back)
    local notFound = type(ERR_CHAT_PLAYER_NOT_FOUND_S) == "string"
      and ("^" .. ERR_CHAT_PLAYER_NOT_FOUND_S:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", ".+") .. "$") or nil
    AddFilter("CHAT_MSG_SYSTEM", function(_, _, text, ...)
      if type(text) ~= "string" or issecretRepeat(text) or text == "" then return false end
      if notFound and text:find(notFound) then return false end
      local line = select(10, ...)
      if issecretRepeat(line) then line = nil end
      local now = GetTime()
      local first = seen[text]
      if not first or now - first.at > QUIET_FOR then
        seen[text] = { line = line, at = now }
        return false
      end
      if line ~= nil and line == first.line then return false end -- (the first one, in another chat window)
      return true
    end)
  end
  local active = CreateFrame("Frame")
  for _, e in ipairs({ "PLAYER_STARTED_MOVING", "GLOBAL_MOUSE_DOWN", "UNIT_SPELLCAST_SENT", "PLAYER_TARGET_CHANGED",
    "PLAYER_REGEN_DISABLED" }) do
    active:RegisterEvent(e)
  end
  active:SetScript("OnEvent", function() if next(seen) then wipe(seen) end end)
end

---------------------------------------------------------------------------
-- The target's (and focus's) level beside the skull: since WoW Forever's build 70840 the game's battle pet check, run
-- after its level check on every update, shows the level text again for any unit that is not a battle pet, so a
-- target too high to tell (the skull) or a corpse shows the last level read beside the skull. Hidden again, as the
-- game's own level check left it.
---------------------------------------------------------------------------
do
  local issecretLevel = issecretvalue or function() return false end
  local function Yes(fn, unit)
    if type(fn) ~= "function" then return false end
    local ok, v = pcall(fn, unit)
    return ok and not issecretLevel(v) and v and true or false
  end
  local function KeepLevel(frame)
    local unit = frame and frame.unit
    local main = frame and frame.TargetFrameContent and frame.TargetFrameContent.TargetFrameContentMain
    local text = main and main.LevelText
    if not (unit and frame.showLevel and text and text.Hide) then return end
    if Yes(UnitIsWildBattlePet, unit) or Yes(UnitIsBattlePetCompanion, unit) then return end
    local okL, level = pcall(UnitEffectiveLevel, unit)
    if not okL or issecretLevel(level) then return end
    if Yes(UnitIsCorpse, unit) or (type(level) == "number" and level <= 0) then text:Hide() end
  end
  for _, name in ipairs({ "TargetFrame", "FocusFrame" }) do
    local frame = _G[name]
    if type(frame) == "table" and type(frame.CheckBattlePet) == "function" then hooksecurefunc(frame, "CheckBattlePet", KeepLevel) end
  end
end

---------------------------------------------------------------------------
-- The world map left open when a quest window opens (a quest shared in the group, one offered). The game's window
-- manager puts both on the left, neither giving way, so the quest window replaced the map and closed it (an addon
-- accepting the quest at once left the map shut). While the map is open, the quest window may stand beside it
-- (its "pushable" layout setting at 1, as the character sheet's): it opens next to the map, which stays; back to the
-- game's own setting as the map shuts. The map's own settings and its opening are left untouched (an addon's touch
-- there would follow its pins into later fights).
---------------------------------------------------------------------------
local questPushable -- (the quest window's own setting, read before the first change)
local function QuestBesideMap(beside)
  local quest = QuestFrame
  if not (quest and SetUIPanelAttribute and type(UIPanelWindows) == "table" and UIPanelWindows.QuestFrame) then return end
  if questPushable == nil then
    local own = quest.GetAttribute and quest:GetAttribute("UIPanelLayout-pushable")
    if own == nil then own = UIPanelWindows.QuestFrame.pushable end
    questPushable = tonumber(own) or 0
  end
  local want = beside and math.max(1, questPushable) or questPushable
  local now = quest.GetAttribute and quest:GetAttribute("UIPanelLayout-pushable")
  if now ~= want then pcall(SetUIPanelAttribute, quest, "pushable", want) end
end
ns.QuestBesideMap = QuestBesideMap
local function WatchQuestOverMap()
  local map = WorldMapFrame
  if not (map and map.HookScript) or ns.questOverMapWatched then return end
  ns.questOverMapWatched = true
  map:HookScript("OnShow", function() QuestBesideMap(true) end)
  map:HookScript("OnHide", function() QuestBesideMap(false) end)
  if map:IsShown() then QuestBesideMap(true) end
end
WatchQuestOverMap()
local questMapEvents = CreateFrame("Frame")
questMapEvents:RegisterEvent("PLAYER_LOGIN")
questMapEvents:RegisterEvent("ADDON_LOADED")
questMapEvents:SetScript("OnEvent", function(self)
  WatchQuestOverMap()
  if ns.questOverMapWatched then self:UnregisterAllEvents() end
end)

---------------------------------------------------------------------------
-- The minimap's tracking button: a right-click turns the tracking spell off (Find Herbs, Track Beasts...) by the
-- game's own tracking call, in a fight too, as a right-click on its buff did in 1.x. The game's button hears the
-- left button only (its menu): the right one's release is added, and its tooltip says so while a spell tracks.
---------------------------------------------------------------------------
local function ActiveTrackingSpell()
  if not (C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then return nil end
  local ok, count = pcall(C_Minimap.GetNumTrackingTypes)
  if not ok or issecretvalue(count) or type(count) ~= "number" then return nil end
  for i = 1, count do
    local okInfo, info = pcall(C_Minimap.GetTrackingInfo, i)
    if okInfo and type(info) == "table" and not issecretvalue(info.active) and not issecretvalue(info.type)
      and info.active and info.type == "spell" then
      return i, info
    end
  end
end
ns.ActiveTrackingSpell = ActiveTrackingSpell

function ns.StopTracking()
  local index = ActiveTrackingSpell()
  if index and C_Minimap.SetTracking then pcall(C_Minimap.SetTracking, index, false) end
  return index ~= nil
end

local function TakeTrackingRightClick()
  local tracking = MinimapCluster and MinimapCluster.Tracking
  local button = tracking and tracking.Button
  if ns.trackingRightClick or not (button and button.RegisterForMouse and button.HookScript) then return end
  ns.trackingRightClick = true
  button:RegisterForMouse("LeftButtonDown", "LeftButtonUp", "RightButtonUp")
  button:HookScript("OnMouseUp", function(_, which) if which == "RightButton" then ns.StopTracking() end end)
  button:HookScript("OnEnter", function(self)
    local _, info = ActiveTrackingSpell()
    local name = info and info.name
    if type(name) ~= "string" or issecretvalue(name) or not GameTooltip:IsOwned(self) then return end
    GameTooltip:AddLine(L.TRACKING_STOP:format(name), 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
  end)
end
TakeTrackingRightClick()
local trackingClickEvents = CreateFrame("Frame")
trackingClickEvents:RegisterEvent("PLAYER_LOGIN")
trackingClickEvents:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  TakeTrackingRightClick()
end)
