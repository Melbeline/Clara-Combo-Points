-- Clara Combo Points - Chat look: in a player's chat line, the small head of their race in their sex after their name
-- (a night elf woman's, a dwarf man's...), their level before it in its difficulty color ([40]), and the line's time
-- and level clickable: a click (right or left) shows the whole line selected in the small copy box (time, channel,
-- level, name and what they wrote). Each part has its box on the module's card (Interface; in Clara's Improvements tab
-- too): the level and the copy on by default; the head off by default, on by default on the owner's own accounts
-- (ICKSTU, WANJ and the WoW1 linked to them on the same computer: the gold tracker knows them by their folders'
-- names, brought by the Windows script; another player's WoW1 is not linked to them). Its box ticked or unticked: kept.
-- As BetterForeverChat shows them, its code left aside: the line, once the game has put it in a window (a post-hook on
-- the window's AddMessage, the game's own code untouched), has its text changed in place, the newest line only (the
-- game's own TransformMessages goes through the whole history, thousands of lines, at each line: what made the game
-- halt). A line the game keeps secret is left as it is. Lines put back from the previous session keep theirs.
-- The level: from the units around (target, mouse, group, raid), the game's player info, the last /who; none known:
-- none shown. Saved with Clara's settings (ClaraComboPointsDB.chatLook).
-- With Prat (another chat addon), Prat first: its level by the name (its PlayerNames' Show Level) shown, Clara's not; a
-- level or a race's head another addon already put by the name: Clara's not added; the level and the head outside
-- Prat's brackets ([38:Name] stays whole); Prat's time at the line's start clickable as the game's; Clara's change made
-- after Prat has put its time (its Timestamps, which leaves a line already changed as it is).

local ADDON, ns = ...
local L = ns.L

local issecret = issecretvalue or function() return false end
local function Plain(v) return v ~= nil and not issecret(v) end

local function Store()
  local sv = ns.sv
  if not sv then return {} end
  if type(sv.chatLook) ~= "table" then sv.chatLook = {} end
  return sv.chatLook
end
-- One of the owner's accounts: ICKSTU or WANJ, or an account the Windows script links to one of them (their WoW1)
local OWNER = { ickstu = true, wanj = true }
local function OwnersAccount()
  local G, S = ns.Money, ns.Sync
  local db = G and G.db
  if type(db) ~= "table" or type(db.accounts) ~= "table" then return false end
  for id, a in pairs(db.accounts) do
    local name = type(a) == "table" and type(a.n) == "string" and a.n:lower() or nil
    if name and OWNER[name] and (id == db.me or (S and S.OwnAccount and S.OwnAccount(id))) then return true end
  end
  return false
end
ns.ChatLookOwners = OwnersAccount -- (for the tests)

-- (the head: its default by account, a choice kept as true or false; the others on by default, kept false unticked)
local function On(key)
  local v = Store()[key]
  if key == "heads" then
    if v == nil then return OwnersAccount() end
    return v == true
  end
  return v ~= false
end
local function Set(key, on)
  if key == "heads" then Store()[key] = on and true or false
  elseif on then Store()[key] = nil
  else Store()[key] = false end
end

ns:SetQolSwitches("chatlook", {
  { label = "CL_HEADS", get = function() return On("heads") end, set = function(on) Set("heads", on) end },
  { label = "CL_LEVEL", get = function() return On("level") end, set = function(on) Set("level", on) end },
  { label = "CL_COPY", get = function() return On("copy") end, set = function(on) Set("copy", on) end },
})
if not ns:QolRuns("chatlook") then return end

-- The player chats decorated (not the monsters', the system's, the emotes')
local EVENTS = {}
for _, e in ipairs({ "SAY", "YELL", "WHISPER", "WHISPER_INFORM", "CHANNEL", "GUILD", "OFFICER", "PARTY", "PARTY_LEADER",
  "RAID", "RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER", "COMMUNITIES_CHANNEL" }) do
  EVENTS["CHAT_MSG_" .. e] = true
end

---------------------------------------------------------------------------
-- The level: the units around, the game's player info, the last /who (a few minutes)
---------------------------------------------------------------------------
local levels, byName, order = {}, {}, {}
local KEEP = 600 -- seconds a level seen is trusted
local function Valid(level) return Plain(level) and type(level) == "number" and level >= 1 and level <= 255 and level % 1 == 0 end
local function Remember(guid, name, level)
  if not Valid(level) then return end
  if Plain(guid) and type(guid) == "string" then
    if not levels[guid] then
      order[#order + 1] = guid
      if #order > 800 then levels[table.remove(order, 1)] = nil end
    end
    levels[guid] = { level = level, at = GetTime() }
  end
  if Plain(name) and type(name) == "string" and name ~= "" then byName[name:gsub("%-.*$", ""):lower()] = { level = level, at = GetTime() } end
end
local function Observe(unit)
  if not (UnitExists and UnitExists(unit) and UnitIsPlayer and UnitIsPlayer(unit)) then return end
  local guid, level = UnitGUID(unit), UnitLevel(unit)
  Remember(guid, UnitName(unit), level)
end
local UNITS = { "player", "target", "focus", "mouseover" }
for i = 1, 4 do UNITS[#UNITS + 1] = "party" .. i end
for i = 1, 40 do UNITS[#UNITS + 1] = "raid" .. i end
local function LevelOf(guid, sender, gameLevel)
  for _, unit in ipairs(UNITS) do
    local g = UnitGUID and UnitGUID(unit)
    if g ~= nil and Plain(g) and g == guid then
      local level = UnitLevel(unit)
      if Valid(level) then Remember(guid, nil, level) return level end
    end
  end
  if Valid(gameLevel) then return gameLevel end
  local now = GetTime()
  local known = levels[guid]
  if known and now - known.at <= KEEP then return known.level end
  if Plain(sender) and type(sender) == "string" then
    local n = byName[sender:gsub("%-.*$", ""):lower()]
    if n and now - n.at <= KEEP then return n.level end
  end
end
local function LevelText(level)
  local color = "|cffb8b8b8"
  local fn = GetCreatureDifficultyColor or GetQuestDifficultyColor
  if fn then
    local ok, c = pcall(fn, level)
    if ok and type(c) == "table" and Plain(c.r) and type(c.r) == "number" then
      color = ("|cff%02x%02x%02x"):format(math.floor(c.r * 255 + .5), math.floor(c.g * 255 + .5), math.floor(c.b * 255 + .5))
    end
  end
  return color .. "[" .. level .. "]|r"
end

local watch = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "GROUP_ROSTER_UPDATE", "WHO_LIST_UPDATE", "PLAYER_LEVEL_UP" }) do
  pcall(watch.RegisterEvent, watch, e)
end
watch:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_TARGET_CHANGED" then Observe("target")
  elseif event == "UPDATE_MOUSEOVER_UNIT" then Observe("mouseover")
  elseif event == "GROUP_ROSTER_UPDATE" then
    for i = 1, 4 do Observe("party" .. i) end
  elseif event == "WHO_LIST_UPDATE" then
    local F = C_FriendList
    if not (F and F.GetNumWhoResults and F.GetWhoInfo) then return end
    for i = 1, math.min(F.GetNumWhoResults() or 0, 50) do
      local ok, info = pcall(F.GetWhoInfo, i)
      if ok and type(info) == "table" then Remember(nil, info.fullName, info.level) end
    end
  end
end)

---------------------------------------------------------------------------
-- The head: the race's small icon, in the player's sex
---------------------------------------------------------------------------
local function Size(frame)
  local h
  if frame and frame.GetFont then
    local _, size = frame:GetFont()
    h = size
  end
  if not Plain(h) or type(h) ~= "number" then h = 14 end
  return math.max(10, math.floor(h + .5)), -math.floor(h * 0.28 + .5)
end
local function Head(race, sex, frame)
  if not (Plain(race) and type(race) == "string" and Plain(sex) and GetRaceAtlas) then return nil end
  local gender = sex == 2 and "male" or sex == 3 and "female" or nil
  if not gender then return nil end
  local atlas = GetRaceAtlas(race:lower(), gender)
  if not (C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)) then return nil end
  local size, offset = Size(frame)
  return ("|A:%s:%d:%d:0:%d|a"):format(atlas, size, size, offset)
end

---------------------------------------------------------------------------
-- The line changed in place: its head, its level, its time and level clickable
---------------------------------------------------------------------------
-- A line as it reads, without the game's markup
local function PlainLine(text)
  text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  text = text:gsub("|H.-|h(.-)|h", "%1"):gsub(" ?|T.-|t", ""):gsub(" ?|A.-|a", "")
  return (text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end
ns.ChatLookPlain = PlainLine -- (for the tests)

local LINK = "addon:" .. ADDON .. ":line:"
local session = ("%x"):format(time and time() or 0)
local serial = 0

-- The game's time at the line's start, as its chat settings write it ("[19:46:37] "): its length
local function Stamp(text)
  local fmt = ChatFrameUtil and ChatFrameUtil.GetTimestampFormat and ChatFrameUtil.GetTimestampFormat()
  if type(fmt) ~= "string" or fmt == "" or not (TimeUtil and TimeUtil.BetterDate) then return nil end
  local ok, sample = pcall(TimeUtil.BetterDate, fmt, time())
  if not ok or type(sample) ~= "string" or #sample == 0 or #text < #sample then return nil end
  local head = text:sub(1, #sample)
  if head:gsub("%d", "0") ~= sample:gsub("%d", "0") then return nil end
  return #sample
end
-- Else a time another addon put first, in its color or not (Prat's "|cff999999[20:55:11]|r"): its length
local function LeadStamp(text)
  local e = text:match("^|c%x%x%x%x%x%x%x%x[^|]*|r()")
  if e then
    local inner = text:sub(11, e - 3)
    if #inner <= 24 and inner:find("^%[?%d%d?[:%.h]%d%d") then return e - 1 end
  end
  local e2 = text:match("^%[%d%d?[:%.h]%d%d[^%]|]*%]()")
  if e2 then return e2 - 1 end
end

-- Prat's level by the name, on (its PlayerNames' Show Level): Prat's shown, Clara's not
local function PratLevels()
  if not ns.PratModule then return false end
  local _, profile = ns.PratModule("PlayerNames")
  return profile ~= nil and profile.level == true
end

local function Build(text, eventArgs, frame)
  local guid, sender = eventArgs[12], eventArgs[2]
  if not (Plain(guid) and type(guid) == "string" and guid:find("^Player%-")) then return nil end
  local s, e = text:find("|Hplayer[^:]*:[^|]*|h.-|h")
  if not s then return nil end
  local race, sex, gameLevel
  if GetPlayerInfoByGUID then
    local ok, _, _, _, r, x, _, _, lv = pcall(GetPlayerInfoByGUID, guid)
    if ok then race, sex, gameLevel = r, x, lv end
  end
  local copy = On("copy")
  local key
  if copy then
    serial = serial + 1
    key = LINK .. session .. "-" .. serial
  end
  local before, link, after = text:sub(1, s - 1), text:sub(s, e), text:sub(e + 1)
  -- What the line already shows by the name: a level in it (Prat's "38:Name"), a race's head
  local shownLevel = PlainLine(link):find("%d")
  local shownHead = text:lower():find("raceicon", 1, true)
  -- Brackets outside the name's link (Prat's): the level before them, the head after them
  local open = before:match("()|c%x%x%x%x%x%x%x%x[%[<]|r$") or before:match("()[%[<]$")
  if open then before, link = before:sub(1, open - 1), before:sub(open) .. link end
  local close = after:match("^|c%x%x%x%x%x%x%x%x[%]>]|r()") or after:match("^[%]>]()")
  if close then link, after = link .. after:sub(1, close - 1), after:sub(close) end
  local level = On("level") and not shownLevel and not PratLevels() and LevelOf(guid, sender, gameLevel) or nil
  local levelText = level and LevelText(level) or nil
  if levelText and key then levelText = "|H" .. key .. "|h" .. levelText .. "|h" end
  local head = On("heads") and not shownHead and Head(race, sex, frame) or nil
  local out = before .. (levelText and (levelText .. " ") or "") .. link .. (head and (" " .. head) or "") .. after
  if key then
    local n = Stamp(out) or LeadStamp(out)
    if n then
      local stamp, rest = out:sub(1, n), out:sub(n + 1)
      local core, space = stamp:match("^(.-)(%s*)$")
      out = "|H" .. key .. "|h" .. core .. "|h" .. space .. rest
    end
  end
  return out
end
ns.ChatLookBuild = Build -- (for the tests)

-- After the game's AddMessage: the line just put in the window, if it is this event's
local function Apply(frame, entry, eventArgs)
  local text = entry.message
  if not (Plain(text) and type(text) == "string") then return end
  local ok, out = pcall(Build, text, eventArgs, frame)
  if ok and type(out) == "string" and out ~= text then
    entry.message = out
    if frame.MarkDisplayDirty then frame:MarkDisplayDirty() end
  end
end

-- Lines changed at the next frame: Prat's time put first (its hook, after Clara's, leaves a line already changed as it is)
local queue = {}
local runner = CreateFrame("Frame")
runner:Hide()
runner:SetScript("OnUpdate", function(self)
  self:Hide()
  local q = queue
  queue = {}
  for _, item in ipairs(q) do Apply(item[1], item[2], item[3]) end
end)
local function Later()
  return ns.PratModule ~= nil and ns.PratModule("Timestamps") ~= nil
end
ns.ChatLookFlush = function() runner:GetScript("OnUpdate")(runner) end -- (for the tests)

local function After(frame, text, _, _, _, _, _, _, event, eventArgs)
  if not (Plain(text) and type(text) == "string" and Plain(event) and EVENTS[event]) then return end
  if not (Plain(eventArgs) and type(eventArgs) == "table") or (canaccesstable and not canaccesstable(eventArgs)) then return end
  if not (On("heads") or On("level") or On("copy")) then return end
  local buffer = frame.historyBuffer
  local entry = buffer and buffer.GetEntryAtIndex and buffer:GetEntryAtIndex(1)
  if type(entry) ~= "table" or entry.message ~= text then return end
  local extra = entry.extraData
  if not (type(extra) == "table" and extra[5] == eventArgs and extra[4] == event) then return end
  if Later() then
    queue[#queue + 1] = { frame, entry, eventArgs }
    runner:Show()
    return
  end
  Apply(frame, entry, eventArgs)
end
ns.ChatLookAfter = After -- (for the tests)

local hooked = {}
local function Hook(frame)
  if not frame or hooked[frame] or frame == ChatFrame2 or type(frame.AddMessage) ~= "function" then return end
  hooked[frame] = true
  hooksecurefunc(frame, "AddMessage", After)
end
local function HookAll()
  for i = 1, NUM_CHAT_WINDOWS or 10 do Hook(_G["ChatFrame" .. i]) end
  for _, name in ipairs(CHAT_FRAMES or {}) do Hook(_G[name]) end
end
HookAll()
if FCF_OpenTemporaryWindow then hooksecurefunc("FCF_OpenTemporaryWindow", HookAll) end
if FCF_OpenNewWindow then hooksecurefunc("FCF_OpenNewWindow", HookAll) end

---------------------------------------------------------------------------
-- A click on the time or the level: the whole line, selected to copy
---------------------------------------------------------------------------
local function Find(link, frame)
  local needle = "|H" .. link .. "|h"
  local frames = {}
  if frame and frame.GetNumMessages then frames[1] = frame end
  for i = 1, NUM_CHAT_WINDOWS or 10 do frames[#frames + 1] = _G["ChatFrame" .. i] end
  for _, f in ipairs(frames) do
    if f and f.GetNumMessages and f.GetMessageInfo then
      for i = f:GetNumMessages() or 0, 1, -1 do
        local msg = f:GetMessageInfo(i)
        if Plain(msg) and type(msg) == "string" and msg:find(needle, 1, true) then return msg end
      end
    end
  end
end
local function Clicked(_, link, _, _, frame)
  if type(link) ~= "string" or link:sub(1, #LINK) ~= LINK then return end
  local msg = Find(link, frame)
  if msg and ns.ShowCopyBox then ns.ShowCopyBox(PlainLine(msg)) end
end
ns.ChatLookClicked = Clicked -- (for the tests)
if EventRegistry and EventRegistry.RegisterCallback then
  EventRegistry:RegisterCallback("SetItemRef", Clicked, watch)
end
