-- Clara Combo Points - FriendsXP: the group members' experience in the experience bar's tooltip. The members who have
-- Clara (and this module on) send each other their level, their experience on it and their rested experience (an
-- unseen addon message to the group, at most one every 5 seconds); hovering the experience bar (or its rest tick), the
-- tooltip gets, under its first line, one line per member, yourself first: the name in the class's color and the
-- level, the experience on the level ("26,071 / 90,700 (29%)"), and under it the rested experience still to come
-- ("30,806 (34%)": of the level; up to 150%, 180% with the Legacy talent that raises it, never cut). The lines are the
-- tooltip's own (it widens to them): no name runs past its edge. Members without Clara send nothing: not shown.

local ADDON, ns = ...
local L = ns.L

if not ns:QolRuns("friendsxp") then return end

local PREFIX = "ClaraFriendsXP"
local SEND_GAP = 5 -- seconds between two messages at most (the experience moves often in a fight)
local RESTED_COLOR = { 0.35, 0.6, 1 } -- the game's rested blue

local issecret = issecretvalue or function() return false end
local function Secret(...)
  for i = 1, select("#", ...) do if issecret((select(i, ...))) then return true end end
  return false
end

local F = { members = {} } -- [whole name, lower-case] = { name, class, level, xp, max, rested, heard }
ns.FriendsXP = F

---------------------------------------------------------------------------
-- Names and the group
---------------------------------------------------------------------------
local function Short(name)
  if type(name) ~= "string" or issecret(name) then return nil end
  name = (name:match("^(.-)%-[^%-]*$") or name):gsub("^%s+", ""):gsub("%s+$", "")
  return name ~= "" and name or nil
end

local function Whole(unit)
  local ok, name = pcall(ns.FullName, ns, unit)
  if ok and type(name) == "string" and not issecret(name) and name ~= "" then return name end
  local n = UnitName and UnitName(unit)
  if type(n) == "string" and not issecret(n) and n ~= "" then return n end
end

local function Me()
  local name = Whole("player")
  return name and name:lower()
end

local function InGroup() return IsInGroup and IsInGroup() or false end

local function Channel()
  local home, instance = LE_PARTY_CATEGORY_HOME or 1, LE_PARTY_CATEGORY_INSTANCE or 2
  if IsInGroup and IsInGroup(instance) and not IsInGroup(home) then return "INSTANCE_CHAT" end
  if IsInRaid and IsInRaid() then return "RAID" end
  if InGroup() then return "PARTY" end
end

local function Units()
  local list = {}
  if IsInRaid and IsInRaid() then
    for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do list[#list + 1] = "raid" .. i end
  else
    for i = 1, (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0) do list[#list + 1] = "party" .. i end
  end
  return list
end

-- Members gone from the group: forgotten
local function Prune()
  if not InGroup() then
    wipe(F.members)
    return
  end
  local here = {}
  for _, unit in ipairs(Units()) do
    local name = Whole(unit)
    if not name then return end -- (the names hidden for now: nothing forgotten)
    here[name:lower()] = true
  end
  for key in pairs(F.members) do if not here[key] then F.members[key] = nil end end
end

---------------------------------------------------------------------------
-- Ours, sent; theirs, heard ("X^level^xp^max^rested^CLASS"; "H": a member asks for everyone's)
---------------------------------------------------------------------------
local function Mine()
  if not (UnitLevel and UnitXP and UnitXPMax) then return nil end
  local level, xp, max = UnitLevel("player"), UnitXP("player"), UnitXPMax("player")
  local rested = GetXPExhaustion and GetXPExhaustion() or 0
  local _, class = UnitClass("player")
  if Secret(level, xp, max, rested, class) then return nil end
  if type(level) ~= "number" or type(xp) ~= "number" or type(max) ~= "number" then return nil end
  return { name = Whole("player"), class = class, level = level, xp = xp, max = max,
    rested = type(rested) == "number" and rested or 0 }
end
F.Mine = Mine

local function Record(m)
  return ("X^%d^%d^%d^%d^%s"):format(m.level, math.floor(m.xp), math.floor(m.max), math.floor(m.rested), m.class or "")
end

local lastText, lastSent, waiting, again = nil, -SEND_GAP, false, false
local function Post(text)
  local channel = Channel()
  if not (channel and C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false end
  local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, text, channel)
  if not ok or Secret(result) then return false end
  return result == nil or result == true or result == 0
end

local function SendNow(force)
  local m = Mine()
  if not m or not InGroup() then return end
  local text = Record(m)
  if text == lastText and not force then return end
  if Post(text) then
    lastText, lastSent = text, GetTime()
  end
end

-- Soon (several changes at once, or a fight's every kill: one message, 5 seconds apart at most)
local function Soon(force)
  if force then again = true end
  if waiting then return end
  waiting = true
  local wait = math.max(0.5, SEND_GAP - (GetTime() - lastSent))
  C_Timer.After(wait, function()
    waiting = false
    local f = again
    again = false
    SendNow(f)
  end)
end
F.Soon = Soon

function F.Heard(text, channel, from)
  if Secret(text, channel, from) or type(text) ~= "string" then return end
  if channel ~= "PARTY" and channel ~= "RAID" and channel ~= "INSTANCE_CHAT" then return end
  local name = Short(from)
  if not name or name:lower() == Me() then return end
  if text == "H" then Soon(true) return end -- (a member just joined or reloaded: ours to them)
  local level, xp, max, rested, class = text:match("^X%^(%d+)%^(%d+)%^(%d+)%^(%d+)%^(%u*)$")
  if not level then return end
  F.members[name:lower()] = { name = name, class = class ~= "" and class or nil, level = tonumber(level),
    xp = tonumber(xp), max = tonumber(max), rested = tonumber(rested), heard = GetTime() }
end

---------------------------------------------------------------------------
-- The tooltip: under its first line, yourself then each member heard, in the group's order
---------------------------------------------------------------------------
local function Big(n) return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n) end

local function ClassHex(class)
  local color = class and ((C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class))
    or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
  if not color then return "ffffffff" end
  if color.GenerateHexColor then return color:GenerateHexColor() end
  return ("ff%02x%02x%02x"):format((color.r or 1) * 255, (color.g or 1) * 255, (color.b or 1) * 255)
end

-- One member's lines: the name and level, the experience on the level; its rested experience under it
local function Lines(m)
  local out = {}
  local left = ("|c%s%s|r  |cffffd100%d|r"):format(ClassHex(m.class), m.name or "?", m.level or 0)
  local right
  if (m.max or 0) > 0 then
    -- (the percent rounded up, as the game's own first line of this tooltip has it)
    right = ("%s / %s (%d%%)"):format(Big(m.xp or 0), Big(m.max), math.ceil((m.xp or 0) / m.max * 100))
  else
    right = L.FXP_MAX_LEVEL
  end
  out[1] = { left, right, 1, 1, 1, 1, 1, 1 }
  if (m.rested or 0) > 0 and (m.max or 0) > 0 then
    out[2] = { "    " .. L.FXP_RESTED, ("%s (%d%%)"):format(Big(m.rested), math.floor(m.rested / m.max * 100 + 0.5)),
      0.7, 0.7, 0.7, RESTED_COLOR[1], RESTED_COLOR[2], RESTED_COLOR[3] }
  end
  return out
end
F.Lines = Lines

-- The members heard, in the group's order (those gone from the units' names last)
local function Heard()
  local list, done = {}, {}
  for _, unit in ipairs(Units()) do
    local name = Whole(unit)
    local m = name and F.members[name:lower()]
    if m and not done[m] then
      done[m] = true
      if not m.class then local _, c = UnitClass(unit) if not Secret(c) then m.class = c end end
      list[#list + 1] = m
    end
  end
  for _, m in pairs(F.members) do if not done[m] then list[#list + 1] = m end end
  return list
end

local inserted -- (the first line written, to know the tooltip has them already)
local function AddTo(tooltip)
  tooltip = tooltip or GameTooltip
  if not (tooltip and tooltip:IsShown()) or not InGroup() then return end
  local others = Heard()
  if #others == 0 then return end
  local n = tooltip:NumLines()
  local name = tooltip:GetName()
  local first = name and _G[name .. "TextLeft1"]
  local second = name and _G[name .. "TextLeft2"]
  if not first then return end
  if inserted and second and second:GetText() == inserted then return end
  -- the lines after the first, kept to be written again under ours
  local kept = {}
  for i = 2, n do
    local l, r = _G[name .. "TextLeft" .. i], _G[name .. "TextRight" .. i]
    local lt = l and l:GetText()
    local rt = r and r:IsShown() and r:GetText() or nil
    if Secret(lt, rt) then return end -- (a line it cannot read: left as it is)
    local lr, lg, lb = l:GetTextColor()
    local k = { lt or " ", lr, lg, lb, wrap = l.CanWordWrap and l:CanWordWrap() }
    if rt then
      local rr, rg, rb = r:GetTextColor()
      k.right, k.rr, k.rg, k.rb = rt, rr, rg, rb
    end
    kept[#kept + 1] = k
  end
  local title = first:GetText()
  if Secret(title) then return end
  local tr, tg, tb = first:GetTextColor()
  tooltip:ClearLines()
  tooltip:AddLine(title or " ", tr, tg, tb)
  local rows = {}
  local mine = Mine()
  if mine then for _, row in ipairs(Lines(mine)) do rows[#rows + 1] = row end end
  for _, m in ipairs(others) do for _, row in ipairs(Lines(m)) do rows[#rows + 1] = row end end
  for _, row in ipairs(rows) do tooltip:AddDoubleLine(unpack(row)) end
  for _, k in ipairs(kept) do
    if k.right then
      tooltip:AddDoubleLine(k[1], k.right, k[2], k[3], k[4], k.rr, k.rg, k.rb)
    else
      tooltip:AddLine(k[1], k[2], k[3], k[4], k.wrap)
    end
  end
  inserted = rows[1] and rows[1][1]
  tooltip:Show()
end
F.AddTo = AddTo

-- The game's experience bar in its two places (the bars' own hover and their rest tick's), hooked once each
local hooked = setmetatable({}, { __mode = "k" })
local function HookOnce(frame)
  if type(frame) ~= "table" or hooked[frame] or not frame.HookScript then return end
  hooked[frame] = true
  frame:HookScript("OnEnter", function() AddTo(GameTooltip) end)
end
local function HookBars()
  for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
    for _, bar in pairs(type(container) == "table" and type(container.bars) == "table" and container.bars or {}) do
      if type(bar) == "table" and bar.ExhaustionTick then
        HookOnce(bar)
        HookOnce(bar.ExhaustionTick)
      end
    end
  end
end

-- /cl souris: who was heard
function ns:FriendsXPReport()
  local names = {}
  for _, m in pairs(F.members) do
    names[#names + 1] = ("%s %d %d/%d rested %d (%.0f s ago)"):format(m.name, m.level or 0, m.xp or 0, m.max or 0,
      m.rested or 0, GetTime() - (m.heard or GetTime()))
  end
  return "FriendsXP: " .. (#names > 0 and table.concat(names, "; ") or "nobody heard")
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local wasInGroup = false
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
  if event == "CHAT_MSG_ADDON" then
    local prefix, text, channel, from = ...
    if prefix == PREFIX then F.Heard(text, channel, from) end
  elseif event == "PLAYER_LOGIN" then
    HookBars()
  elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
    Prune()
    local now = InGroup()
    local login, reload = ...
    local fresh = event == "PLAYER_ENTERING_WORLD" and (login or reload)
    if now and (not wasInGroup or fresh) then
      -- (just joined, or logged in or reloaded: ask the others for theirs, send ours)
      wasInGroup = true
      C_Timer.After(fresh and 3 or 1, function()
        if InGroup() then
          Post("H")
          Soon(true)
        end
      end)
    elseif not now then
      wasInGroup = false
      lastText = nil
    end
  else -- (our experience moved)
    Soon(false)
  end
end)
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
for _, e in ipairs({ "CHAT_MSG_ADDON", "PLAYER_LOGIN", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE",
  "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP" }) do
  pcall(events.RegisterEvent, events, e)
end
