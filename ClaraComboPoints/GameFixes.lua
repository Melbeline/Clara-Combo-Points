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
-- And the quest tracker folded again as it was left (the whole tracker and each of its sections).
-- And /played always answered in the chat (in a fight it showed nothing).

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
    local x = (hr and mr) and (hr - mr - 2) or -10
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
-- The quest tracker folded as it was left. The game opens it whole at each login and reload: the tracker and
-- each of its sections (Quests, Achievements...) folded then are folded again, for each character. Read at
-- logout (reading the game's tracker changes nothing in it); folded again by the game's own fold (as its
-- header's button does), out of combat, and only what was folded: a tracker left open is never touched. The
-- tracker is not one of the game's protected frames (no fight check anywhere in it; its quest item buttons
-- keep their quest in attributes, which an addon's code does not taint).
---------------------------------------------------------------------------
local function TrackerSections()
  local list, tracker = {}, ObjectiveTrackerFrame
  if tracker and type(tracker.modules) == "table" then
    for _, module in ipairs(tracker.modules) do
      local name = module.GetName and module:GetName()
      if name and module.IsCollapsed and module.SetCollapsed then list[#list + 1] = { name = name, module = module } end
    end
  end
  return list
end

local function SaveFolds()
  local tracker, sv, me = ObjectiveTrackerFrame, ns.sv, Me()
  if not (tracker and tracker.IsCollapsed and sv and me) then return end
  local folds = {}
  if tracker:IsCollapsed() then folds.all = true end
  for _, section in ipairs(TrackerSections()) do
    if section.module:IsCollapsed() then folds[section.name] = true end
  end
  sv.trackerFolds = type(sv.trackerFolds) == "table" and sv.trackerFolds or {}
  sv.trackerFolds[me] = next(folds) and folds or nil
  if not next(sv.trackerFolds) then sv.trackerFolds = nil end
end

local foldEvents = CreateFrame("Frame")
local function Fold(again)
  if InCombatLockdown() then foldEvents:RegisterEvent("PLAYER_REGEN_ENABLED") return end
  local tracker, sv, me = ObjectiveTrackerFrame, ns.sv, Me()
  local folds = me and sv and type(sv.trackerFolds) == "table" and sv.trackerFolds[me]
  if not (tracker and tracker.SetCollapsed and type(folds) == "table") then return end
  local sections = TrackerSections()
  if #sections == 0 and not again then C_Timer.After(2, function() Fold(true) end) return end -- (its sections not set yet)
  for _, section in ipairs(sections) do
    if folds[section.name] and not section.module:IsCollapsed() then section.module:SetCollapsed(true) end
  end
  if folds.all and not tracker:IsCollapsed() then tracker:SetCollapsed(true) end
end

foldEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
foldEvents:RegisterEvent("PLAYER_LOGOUT")
foldEvents:SetScript("OnEvent", function(self, event, isLogin, isReload)
  if event == "PLAYER_LOGOUT" then
    SaveFolds()
  elseif event == "PLAYER_REGEN_ENABLED" then
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    Fold()
  elseif isLogin or isReload then -- (the game's tracker set up on the same event: a moment later)
    C_Timer.After(1, function() Fold() end)
  end
end)

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
