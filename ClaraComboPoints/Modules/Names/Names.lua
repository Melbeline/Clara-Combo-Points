-- Clara Combo Points - Names: WoW Forever characters have a surname; this hides it where one
-- chooses, each place with a box of its own: the target and focus frames (and their targets), the
-- party and raid frames, the pets (their frame, their owner in their tooltip), the players'
-- tooltips, the nameplates, the chat (the name shown only: its link still whispers the right
-- character). Over the heads, the game draws the names itself: the client's own surname settings
-- for the other players are turned off, when it has any. One's own name and surname over one's
-- head (and the surname on the player frame) are the game's own settings (Esc > Options >
-- Nameplates: My Name, My Secondary Name): the boxes here are those, turned together.
-- Saved in ClaraNamesDB, for the account. Not in Light.

local ADDON, ns = ...

ns.NamesRuns = ns:QolRuns("names")
if not ns.NamesRuns then return end

local PLACES = { "target", "focus", "party", "pets", "tooltip", "plates", "chat", "overhead" }
local OWN_NAME, OWN_SURNAME = "UnitNameOwn", "UnitSurnameOwn"
local SEP = Constants and Constants.CharacterNameSeparatorConsts
  and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR or " "
local issecret = issecretvalue or function() return false end

local db
local function Load()
  if type(ClaraNamesDB) ~= "table" then ClaraNamesDB = {} end
  db = ClaraNamesDB
  if type(db.hide) ~= "table" then db.hide = {} end
  for _, place in ipairs(PLACES) do
    if type(db.hide[place]) ~= "boolean" then db.hide[place] = true end
  end
  if type(db.savedCVars) ~= "table" then db.savedCVars = nil end
end
Load()

local function Hidden(place) return db.hide[place] == true end

-- "First Surname" -> "First" (nil: no surname in it, or unreadable)
local function First(text)
  if issecret(text) or type(text) ~= "string" then return nil end
  local at = text:find(SEP, 1, true)
  if not at or at == 1 then return nil end
  return text:sub(1, at - 1)
end

local function IsPlayer(unit)
  if not unit or issecret(unit) or not UnitIsPlayer then return false end
  local yes = UnitIsPlayer(unit)
  return not issecret(yes) and yes == true
end

local function IsMe(unit)
  if not unit or issecret(unit) or not UnitIsUnit then return false end
  local yes = UnitIsUnit(unit, "player")
  return not issecret(yes) and yes == true
end

---------------------------------------------------------------------------
-- The game's settings: one's own name and surname, the other players' surnames over their heads
---------------------------------------------------------------------------
local function GetCVarValue(name)
  if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
  return GetCVar and GetCVar(name)
end
local function SetCVarValue(name, value)
  if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar(name, value) elseif SetCVar then SetCVar(name, value) end
end

-- My Name / My Secondary Name over one's head: hidden while the game's setting is 0
local function OwnHidden(cvar)
  local value = GetCVarValue(cvar)
  return value ~= nil and tostring(value) == "0"
end
local function SetOwnHidden(cvar, hide)
  if GetCVarValue(cvar) == nil then return end
  SetCVarValue(cvar, hide and "0" or "1")
end

-- The client's surname settings other than one's own (none known in WoW Forever's options: found
-- among its console commands, once)
local othersCache
local function OtherSurnameCVars()
  if othersCache then return othersCache end
  local found, seen = {}, {}
  local function Add(name)
    if type(name) == "string" and not seen[name] and name ~= OWN_SURNAME and GetCVarValue(name) ~= nil then
      seen[name] = true
      found[#found + 1] = name
    end
  end
  if C_Console and C_Console.GetAllCommands then
    local ok, commands = pcall(C_Console.GetAllCommands)
    if ok and type(commands) == "table" then
      for _, entry in ipairs(commands) do
        local name = type(entry) == "table" and entry.command or nil
        if type(name) == "string" and name:lower():find("surname", 1, true) then Add(name) end
      end
    end
  end
  for _, name in ipairs({ "UnitSurname", "UnitSurnameOther", "UnitSurnameFriendly", "UnitSurnameEnemy" }) do Add(name) end
  table.sort(found)
  othersCache = found
  return found
end

local wroteAt = -10
local function ApplyOverhead()
  local hide = Hidden("overhead")
  for _, name in ipairs(OtherSurnameCVars()) do
    local value = GetCVarValue(name)
    if hide and value ~= nil and tostring(value) ~= "0" then
      db.savedCVars = db.savedCVars or {}
      if db.savedCVars[name] == nil then db.savedCVars[name] = tostring(value) end
      wroteAt = GetTime()
      SetCVarValue(name, "0")
    elseif not hide and db.savedCVars and db.savedCVars[name] ~= nil then
      wroteAt = GetTime()
      SetCVarValue(name, db.savedCVars[name])
      db.savedCVars[name] = nil
    end
  end
  if db.savedCVars and next(db.savedCVars) == nil then db.savedCVars = nil end
end

---------------------------------------------------------------------------
-- Unit frames (UnitFrame_Update: the player, target, focus and their targets, party, pet frames,
-- the game's and ClassicUI's), party and raid frames and nameplates (CompactUnitFrame_UpdateName)
---------------------------------------------------------------------------
local function PlaceOfUnit(unit)
  if unit == "target" or unit == "targettarget" then return "target" end
  if unit == "focus" or unit == "focustarget" then return "focus" end
  if unit == "pet" or unit:find("pet%d*$") then return "pets" end
  if unit:find("^party%d") or unit:find("^raid%d") then return "party" end
  if unit:find("^nameplate") then return "plates" end
  return nil
end

local function Trim(text, unit, place)
  if not (text and text.GetText) or not unit or issecret(unit) then return end
  if IsMe(unit) then
    -- WoW Forever writes no name for you with My Secondary Name off (its first-name split finds
    -- nothing to split): the last unit's name stayed
    if not OwnHidden(OWN_SURNAME) then return end
    local mine = UnitName("player")
    if issecret(mine) or type(mine) ~= "string" or mine == "" then return end
    mine = First(mine) or mine
    local shown = text:GetText()
    if issecret(shown) or shown ~= mine then text:SetText(mine) end
    return
  end
  -- (a pet's own name is never cut: some have two words; its owner shows in its tooltip)
  if not (place and Hidden(place)) or not IsPlayer(unit) then return end
  local shown = text:GetText()
  local short = First(shown)
  if short then text:SetText(short) end
end

local function OnUnitFrame(frame)
  if type(frame) ~= "table" or not frame.name then return end
  local unit = frame.unit
  if type(unit) ~= "string" then return end
  Trim(frame.name, unit, PlaceOfUnit(unit))
end

local function OnCompactFrame(frame)
  if type(frame) ~= "table" or not frame.name or (frame.IsForbidden and frame:IsForbidden()) then return end
  local unit = frame.unit
  if type(unit) ~= "string" or issecret(unit) then return end
  local place = unit:find("^nameplate") and "plates" or (PlaceOfUnit(unit) or "party")
  Trim(frame.name, unit, place)
end

-- The frames shown now, after a box changed: trimmed, or their full names back
local function FrameTexts()
  local list = {}
  local function Add(frame)
    if type(frame) == "table" and frame.name and type(frame.unit) == "string" then list[#list + 1] = frame end
  end
  Add(PlayerFrame)
  Add(TargetFrame); Add(TargetFrame and TargetFrame.totFrame)
  Add(FocusFrame); Add(FocusFrame and FocusFrame.totFrame)
  Add(PetFrame)
  if PartyFrame and PartyFrame.PartyMemberFramePool then
    for frame in PartyFrame.PartyMemberFramePool:EnumerateActive() do Add(frame) end
  end
  for i = 1, 4 do Add(_G["PartyMemberFrame" .. i]) end
  return list
end

local function RefreshFrames()
  for _, frame in ipairs(FrameTexts()) do
    local unit = frame.unit
    local place = PlaceOfUnit(unit)
    if UnitExists(unit) and place and not Hidden(place) and IsPlayer(unit) and GetUnitName then
      local full = GetUnitName(unit, true)
      if not issecret(full) and type(full) == "string" and full ~= "" then frame.name:SetText(full) end
    end
    OnUnitFrame(frame)
  end
end

---------------------------------------------------------------------------
-- Tooltips: a player's name line, a pet's owner line
---------------------------------------------------------------------------
local OWNER_FORMATS = {}
for _, key in ipairs({ "UNITNAME_TITLE_PET", "UNITNAME_TITLE_MINION", "UNITNAME_TITLE_GUARDIAN",
  "UNITNAME_TITLE_CHARM", "UNITNAME_TITLE_COMPANION", "UNITNAME_TITLE_CREATION" }) do
  local fmt = _G[key]
  if type(fmt) == "string" and fmt:find("%s", 1, true) then
    local pattern = "^" .. fmt:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1"):gsub("%%s", "(.+)") .. "$"
    OWNER_FORMATS[#OWNER_FORMATS + 1] = { fmt = fmt, pattern = pattern }
  end
end

-- text with whole a replaced by b (plain), nil when a is not in it
local function Replace(text, a, b)
  local at = text:find(a, 1, true)
  if not at then return nil end
  return text:sub(1, at - 1) .. b .. text:sub(at + #a)
end

local function FullName(unit)
  local name, second = UnitName(unit)
  if issecret(name) or issecret(second) or type(name) ~= "string" then return nil end
  if type(second) == "string" and second ~= "" and not name:find(SEP, 1, true) then return name .. SEP .. second end
  return name
end

local function OnUnitTooltip(tooltip)
  if tooltip ~= GameTooltip or not tooltip.GetUnit then return end
  local _, unit = tooltip:GetUnit()
  if not unit or issecret(unit) then return end
  local line1 = _G["GameTooltipTextLeft1"]
  if IsPlayer(unit) then
    if not Hidden("tooltip") or not line1 then return end
    local full = FullName(unit)
    local short = First(full)
    local text = line1:GetText()
    if not short or issecret(text) or type(text) ~= "string" then return end
    local new = Replace(text, full, short)
    if new then line1:SetText(new) end
    return
  end
  if not Hidden("pets") or #OWNER_FORMATS == 0 then return end
  local controlled = UnitPlayerControlled and UnitPlayerControlled(unit)
  if issecret(controlled) or not controlled then return end
  for i = 2, math.min(tooltip:NumLines(), 4) do
    local line = _G["GameTooltipTextLeft" .. i]
    local text = line and line:GetText()
    if text and not issecret(text) then
      for _, owner in ipairs(OWNER_FORMATS) do
        local who = text:match(owner.pattern)
        local short = who and First(who)
        if short then
          line:SetText(owner.fmt:format(short))
          return
        end
      end
    end
  end
end

---------------------------------------------------------------------------
-- Chat: the name shown in a player's link ("[First Surname]" -> "[First]"); the link kept
---------------------------------------------------------------------------
local function ShortShown(shown)
  local at = shown:find(SEP, 1, true)
  if not at or at == 1 then return shown end
  local stop = shown:find("[|%-]", at + #SEP) or (#shown + 1)
  return shown:sub(1, at - 1) .. shown:sub(stop)
end

local function ShortLinks(message)
  return (message:gsub("(|Hplayer:[^|]*|h%[)(.-)(%]|h)", function(open, shown, close)
    return open .. ShortShown(shown) .. close
  end))
end
ns.NamesShortLinks = ShortLinks

local hookedChat = {}
local function Added(frame, message)
  if not Hidden("chat") or issecret(message) or type(message) ~= "string" then return end
  if not message:find("|Hplayer:", 1, true) then return end
  local short = ShortLinks(message)
  if short == message or not frame.TransformMessages then return end
  frame:TransformMessages(function(old) return old == message end, function(_, ...) return short, ... end)
end

local function HookChat(frame)
  if type(frame) ~= "table" or hookedChat[frame] or type(frame.AddMessage) ~= "function" then return end
  hookedChat[frame] = true
  hooksecurefunc(frame, "AddMessage", Added)
end

local function HookAllChat()
  for i = 1, NUM_CHAT_WINDOWS or 10 do HookChat(_G["ChatFrame" .. i]) end
  if type(CHAT_FRAMES) == "table" then
    for _, name in ipairs(CHAT_FRAMES) do HookChat(_G[name]) end
  end
end

---------------------------------------------------------------------------
local function Start()
  if type(UnitFrame_Update) == "function" then hooksecurefunc("UnitFrame_Update", OnUnitFrame) end
  if type(CompactUnitFrame_UpdateName) == "function" then hooksecurefunc("CompactUnitFrame_UpdateName", OnCompactFrame) end
  HookAllChat()
  if type(FCF_OpenTemporaryWindow) == "function" then hooksecurefunc("FCF_OpenTemporaryWindow", HookAllChat) end
  -- after the other addons' own (Leatrix Plus rewrites the name line)
  C_Timer.After(0, function()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
      TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnitTooltip)
    end
  end)
  ApplyOverhead()
  RefreshFrames()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("CVAR_UPDATE")
f:SetScript("OnEvent", function(self, event, name)
  if event == "PLAYER_LOGIN" then
    Start()
  elseif event == "PLAYER_ENTERING_WORLD" then
    ApplyOverhead() -- (the client may lay its saved settings back)
  elseif event == "CVAR_UPDATE" then
    if name == OWN_SURNAME or name == OWN_NAME then
      RefreshFrames()
      if ns.NamesChanged then ns.NamesChanged() end
      return
    end
    -- An other players' surname setting turned back on in the game: the box follows
    if not Hidden("overhead") or type(name) ~= "string" or GetTime() - wroteAt < 3 then return end
    for _, cvar in ipairs(OtherSurnameCVars()) do
      if cvar == name and tostring(GetCVarValue(cvar)) ~= "0" then
        db.hide.overhead = false
        db.savedCVars = nil
        if ns.NamesChanged then ns.NamesChanged() end
        return
      end
    end
  end
end)

ns.Names = {
  PLACES = PLACES,
  Hidden = Hidden,
  SetHidden = function(place, hide)
    db.hide[place] = hide and true or false
    if place == "overhead" then ApplyOverhead() else RefreshFrames() end
  end,
  OwnHidden = function() return OwnHidden(OWN_NAME), OwnHidden(OWN_SURNAME) end,
  SetOwnName = function(hide) SetOwnHidden(OWN_NAME, hide) end,
  SetOwnSurname = function(hide) SetOwnHidden(OWN_SURNAME, hide); RefreshFrames() end,
  OverheadSettings = OtherSurnameCVars,
}
