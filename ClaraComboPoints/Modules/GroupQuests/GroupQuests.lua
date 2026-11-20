-- Clara Combo Points - group quest progress: each group member's progress on a quest, in the tooltip of what it
-- needs (an item, a creature, an object), as Questie shows it for the members who have Questie. The members who have
-- Clara send each other their quest log (an unseen addon message to the group: each quest's objectives, their counts,
-- and their names without the counts); the tooltip then gets one line per member and objective, "Name: 12/24 Thing",
-- the name in the member's class color, the count from red to green. An objective is the hovered thing's when its name
-- is the thing's (an item, an object) or holds the creature's (a creature to kill), or when the game's own quest lines
-- in that tooltip name it (outside dungeons: they also tell which creatures drop a quest's item). The lines go last,
-- after every addon's own (Questie's too): a member whose progress is already written there, or whom the game lists
-- itself, is not written again. Members without Clara send nothing: only Questie (theirs and yours) or the game can
-- show them. In a dungeon the game hides a creature's tooltip from addons: items and objects still work there.
-- /cl quetes: what was heard from each member.

local ADDON, ns = ...
local L = ns.L

if not ns:QolRuns("groupquests") then return end

local issecret = issecretvalue or function() return false end
local function Secret(...)
  for i = 1, select("#", ...) do if issecret((select(i, ...))) then return true end end
  return false
end
local function PublicTable(t)
  return not issecret(t) and type(t) == "table" and not (issecrettable and issecrettable(t))
end

local PREFIX = "ClaraQuests"
local PART = 240            -- a message's text, at most (the game takes 255)
local SEND_EVERY = 0.3      -- between two messages
local WAIT_THROTTLED = 1.5  -- the game said "too many": the next try
local WAIT_LOCKED = 5       -- the game forbids addon messages for now (a boss fight): the next try
local NAME_MAX = 60         -- a quest's title, an objective's name: cut there (bytes)
local LINE_TYPE = Enum and Enum.TooltipDataLineType or {}
local TITLE_LINE, OBJECTIVE_LINE, PLAYER_LINE = LINE_TYPE.QuestTitle or 17, LINE_TYPE.QuestObjective or 8, LINE_TYPE.QuestPlayer or 18
local KIND = Enum and Enum.TooltipDataType or {}

local G = {
  members = {},   -- [whole name, lower-case] = { name, quests = { [questID] = { title, done, objs = { { have, need, kind, name } } } }, heard }
  sent = {},      -- [questID] = the record last sent
  queue = {},     -- messages waiting
  lastResult = nil,
}
ns.GroupQuests = G

---------------------------------------------------------------------------
-- Names: a member by its whole name (WoW Forever's "First Surname": a sender is heard so, a unit's is made so),
-- without the realm; kept lower-case
---------------------------------------------------------------------------
local function Short(name)
  if type(name) ~= "string" or issecret(name) then return nil end
  name = (name:match("^(.-)%-[^%-]*$") or name):gsub("^%s+", ""):gsub("%s+$", "")
  return name ~= "" and name or nil
end
G.Short = Short

-- A unit's whole name ("First Surname", whatever the game's name settings hide), nil when hidden
local function UnitWhole(unit)
  local ok, name = pcall(ns.FullName, ns, unit)
  if ok and type(name) == "string" and not issecret(name) and name ~= "" then return name end
end

local function Me()
  local name = UnitWhole("player")
  return name and name:lower()
end

-- The group's unit tokens, and each member's token by name
local function Units()
  local list = {}
  if IsInRaid and IsInRaid() then
    for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do list[#list + 1] = "raid" .. i end
  else
    for i = 1, (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0) do list[#list + 1] = "party" .. i end
  end
  return list
end
function G.UnitOf(key)
  for _, unit in ipairs(Units()) do
    local name = UnitWhole(unit)
    if name and name:lower() == key then return unit end
  end
end

local function InGroup() return IsInGroup and IsInGroup() or false end

-- The channel to the group (a dungeon finder group alone: its own)
local function Channel()
  local home, instance = LE_PARTY_CATEGORY_HOME or 1, LE_PARTY_CATEGORY_INSTANCE or 2
  if IsInGroup and IsInGroup(instance) and not IsInGroup(home) then return "INSTANCE_CHAT" end
  if IsInRaid and IsInRaid() then return "RAID" end
  if InGroup() then return "PARTY" end
end

---------------------------------------------------------------------------
-- Texts: an objective's name without its count, cut to fit, the message marks taken out
---------------------------------------------------------------------------
local function Cut(s, max)
  if #s <= max then return s end
  s = s:sub(1, max)
  return (s:gsub("[\192-\255][\128-\191]*$", "")) -- (no letter cut in two)
end

local function Clean(s)
  s = tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[~%^|\r\n]", " ")
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- "Robo-mechanical Guts: 3/24", "3/24 Robo-mechanical Guts", "Tripes : 3/24" -> the name alone
function G.Bare(text)
  local s = Clean(text)
  s = s:gsub("%s*:?%s*%d+%s*/%s*%d+%s*:?%s*", " ")
  s = s:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s*:$", "")
  return s
end

---------------------------------------------------------------------------
-- The player's own quest log, as records ("Q^id^done^title^have,need,kind,name^...")
---------------------------------------------------------------------------
local KINDS = { monster = "m", item = "i", object = "o", event = "e", reputation = "r", log = "l", player = "p" }

local function Objectives(questID)
  local list = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID)
  if not PublicTable(list) then return nil end
  local objs = {}
  for k, o in ipairs(list) do
    if not PublicTable(o) then return nil end
    local text, have, need, kind = o.text, o.numFulfilled, o.numRequired, o.type
    if Secret(text, have, need, kind) then return nil end
    objs[k] = { tonumber(have) or 0, tonumber(need) or 0, KINDS[kind] or "x", Cut(G.Bare(text), NAME_MAX) }
  end
  return objs
end

-- The quests in the log now: [questID] = { title, done, objs }; nil when the game hides it (secret)
function G.Snapshot()
  local Q = C_QuestLog
  if not (Q and Q.GetNumQuestLogEntries and Q.GetInfo) then return nil end
  local count = Q.GetNumQuestLogEntries()
  if Secret(count) then return nil end
  local out = {}
  for i = 1, tonumber(count) or 0 do
    local info = Q.GetInfo(i)
    if not PublicTable(info) then return nil end
    local id, header, hidden, title = info.questID, info.isHeader, info.isHidden, info.title
    if Secret(id, header, hidden, title) then return nil end
    if not header and not hidden and type(id) == "number" and id > 0 then
      local objs = Objectives(id)
      if not objs then return nil end
      local done = Q.IsComplete and Q.IsComplete(id)
      if Secret(done) then return nil end
      out[id] = { Cut(Clean(title), NAME_MAX), done == true, objs }
    end
  end
  return out
end

function G.Record(id, q)
  local parts = { "Q", tostring(id), q[2] and "1" or "0", q[1] }
  for _, o in ipairs(q[3]) do parts[#parts + 1] = ("%d,%d,%s,%s"):format(o[1], o[2], o[3], o[4]) end
  local record = table.concat(parts, "^")
  while #record > PART and #parts > 4 do -- (too long even alone: its last objectives left out)
    parts[#parts] = nil
    record = table.concat(parts, "^")
  end
  return Cut(record, PART)
end

-- Records into messages, each under the game's limit
local function Pack(records)
  local messages, current = {}, ""
  for _, r in ipairs(records) do
    if current ~= "" and #current + 1 + #r > PART then
      messages[#messages + 1] = current
      current = r
    else
      current = current == "" and r or (current .. "~" .. r)
    end
  end
  if current ~= "" then messages[#messages + 1] = current end
  return messages
end
G.Pack = Pack

---------------------------------------------------------------------------
-- Sending: one message at a time; again later when the game says too many or not now
---------------------------------------------------------------------------
local sender = CreateFrame("Frame")
sender:Hide()
local wait = 0
sender:SetScript("OnUpdate", function(self, elapsed)
  wait = wait - elapsed
  if wait > 0 then return end
  local text = G.queue[1]
  local channel = Channel()
  if not text or not channel then
    wipe(G.queue)
    self:Hide()
    return
  end
  local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, text, channel)
  if not ok then result = 9 end
  if Secret(result) then result = 9 end
  G.lastResult = result
  if result == 3 or result == 8 then
    wait = WAIT_THROTTLED
  elseif result == 11 then
    wait = WAIT_LOCKED
  else
    table.remove(G.queue, 1) -- (sent, or never will be: not left to block the others)
    wait = SEND_EVERY
  end
  if not G.queue[1] then self:Hide() end
end)

local function Send(messages)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) or not Channel() then return end
  for _, m in ipairs(messages) do G.queue[#G.queue + 1] = m end
  if G.queue[1] then sender:Show() end
end

-- What changed in the log since last sent (all of it with full: "F" first, the others then forget the old)
function G.Update(full)
  if not InGroup() then
    wipe(G.sent)
    return
  end
  local snap = G.Snapshot()
  if not snap then return end
  local ids = {}
  for id in pairs(snap) do ids[#ids + 1] = id end
  table.sort(ids)
  local records, now = {}, {}
  if full then records[1] = "F" end
  for _, id in ipairs(ids) do
    local r = G.Record(id, snap[id])
    now[id] = r
    if full or G.sent[id] ~= r then records[#records + 1] = r end
  end
  if not full then
    local gone = {}
    for id in pairs(G.sent) do if not now[id] then gone[#gone + 1] = id end end
    table.sort(gone)
    for _, id in ipairs(gone) do records[#records + 1] = "X^" .. id end
  end
  G.sent = now
  if records[1] then Send(Pack(records)) end
end

-- Soon (several changes at once: one update)
local pending = {}
local function Soon(full, delay)
  if full then pending.full = true end
  if pending.timer then return end
  pending.timer = true
  C_Timer.After(delay or 1, function()
    pending.timer = nil
    local f = pending.full
    pending.full = nil
    G.Update(f)
  end)
end
G.Soon = Soon

---------------------------------------------------------------------------
-- Hearing: the members' logs
---------------------------------------------------------------------------
local function Parse(member, record)
  local fields = {}
  for f in (record .. "^"):gmatch("(.-)%^") do fields[#fields + 1] = f end
  local tag = fields[1]
  if tag == "F" then
    member.quests = {}
  elseif tag == "X" then
    local id = tonumber(fields[2])
    if id then member.quests[id] = nil end
  elseif tag == "Q" then
    local id = tonumber(fields[2])
    if not id then return end
    local objs = {}
    for i = 5, #fields do
      local have, need, kind, name = fields[i]:match("^(%d+),(%d+),(%a),(.*)$")
      if have then objs[#objs + 1] = { tonumber(have), tonumber(need), kind, name } end
    end
    member.quests[id] = { fields[4] or "", fields[3] == "1", objs }
  end
end

function G.Heard(text, channel, from)
  if Secret(text, channel, from) or type(text) ~= "string" then return end
  if channel ~= "PARTY" and channel ~= "RAID" and channel ~= "INSTANCE_CHAT" then return end
  local name = Short(from)
  if not name or name:lower() == Me() then return end
  if text == "H" then -- (a member just joined or reloaded: our whole log to them)
    Soon(true, 0.5 + math.random() * 1.5)
    return
  end
  local member = G.members[name:lower()]
  if not member then
    member = { quests = {} }
    G.members[name:lower()] = member
  end
  member.name = name
  member.heard = GetTime()
  for record in (text .. "~"):gmatch("(.-)~") do Parse(member, record) end
end

-- Members gone from the group: forgotten
local function Prune()
  if not InGroup() then
    wipe(G.members)
    return
  end
  local here = {}
  for _, unit in ipairs(Units()) do
    local name = UnitWhole(unit)
    if not name then return end -- (the names hidden for now: nothing forgotten)
    here[name:lower()] = true
  end
  for name in pairs(G.members) do if not here[name] then G.members[name] = nil end end
end

---------------------------------------------------------------------------
-- The tooltip: the hovered thing's objectives, each member's progress on them
---------------------------------------------------------------------------
local function Lower(s) return (s:lower()) end

local function Letter(c) return c ~= "" and (c:find("%w") ~= nil or c:byte() >= 128) end

-- Does text hold word, whole (not inside a longer word)? Letters past ASCII (accents) count as letters
local function Holds(text, word)
  if word == "" then return false end
  local t, w = Lower(text), Lower(word)
  local start = 1
  while true do
    local a, b = t:find(w, start, true)
    if not a then return false end
    if not Letter(t:sub(a - 1, a - 1)) and not Letter(t:sub(b + 1, b + 1)) then return true end
    start = a + 1
  end
end
G.Holds = Holds

-- What the tooltip is about: its kind ("item", "unit", "object"), its name, the game's own quest lines
-- ({ [questID] = { texts } }) and the members it lists itself ({ [questID] = { [guid] = true } })
local function Read(data)
  if not PublicTable(data) or not PublicTable(data.lines) then return nil end
  local kind
  if data.type == KIND.Item then
    kind = "item"
  elseif data.type == KIND.Unit then
    kind = "unit"
    local guid = data.guid
    if Secret(guid) or type(guid) ~= "string" or guid:find("^Player") then return nil end -- (a player: nothing)
  elseif data.type == KIND.Object then
    kind = "object"
  else
    return nil
  end
  local first = data.lines[1]
  if not PublicTable(first) or Secret(first.leftText) or type(first.leftText) ~= "string" then return nil end
  local name = Clean(first.leftText)
  if name == "" then return nil end
  local native, listed, questID = {}, {}, nil
  for _, line in ipairs(data.lines) do
    if PublicTable(line) and not Secret(line.type) then
      if line.type == TITLE_LINE and not Secret(line.id) then
        questID = tonumber(line.id)
      elseif line.type == OBJECTIVE_LINE and questID and not Secret(line.leftText) and type(line.leftText) == "string" then
        native[questID] = native[questID] or {}
        table.insert(native[questID], Clean(line.leftText))
      elseif line.type == PLAYER_LINE and questID and not Secret(line.guid) and type(line.guid) == "string" then
        listed[questID] = listed[questID] or {}
        listed[questID][line.guid] = true
      end
    end
  end
  return kind, name, native, listed
end

-- The objective named after the thing and one word ("Leper Gnome slain", "Lépreux gnome tué", "Gnomish Toolbox
-- used"): not a longer name ("Defias Bandit Leader slain" is not "Defias Bandit"'s, "Leper Gnome slain" not "Gnome"'s)
local function Named(objName, name)
  local o, n = Lower(objName), Lower(name)
  if o:sub(1, #n) == n and o:sub(#n + 1):find("^%s+%S+$") then return true end
  if #o > #n and o:sub(-#n) == n and o:sub(1, #o - #n):find("^%S+%s+$") then return true end
  return false
end
G.Named = Named

-- (an item: its name only, whole: "Linen Cloth" is not "Heavy Linen Cloth"'s)
local KIND_FITS = { item = {}, unit = { m = true }, object = { o = true, i = true, e = true } }

local function Fits(kind, name, native, questID, obj)
  local objName = obj[4]
  if objName == "" then return false end
  if Lower(objName) == Lower(name) then return true end
  if KIND_FITS[kind][obj[3]] and Named(objName, name) then return true end
  for _, text in ipairs(native[questID] or {}) do
    if Holds(text, objName) then return true end
  end
  return false
end

local function ClassHex(unit)
  if not unit then return "ffffffff" end
  local ok, _, class = pcall(UnitClass, unit)
  if not ok or Secret(class) or not class then return "ffffffff" end
  local color = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class))
    or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
  if not color then return "ffffffff" end
  if color.GenerateHexColor then return color:GenerateHexColor() end
  return ("ff%02x%02x%02x"):format((color.r or 1) * 255, (color.g or 1) * 255, (color.b or 1) * 255)
end

-- The count's color: red with none, yellow halfway, green done
local function CountHex(have, need)
  if need <= 0 or have >= need then return "ff40ff40" end
  local f = have / need
  local r, g = f < 0.5 and 1 or 2 * (1 - f), f < 0.5 and 2 * f or 1
  return ("ff%02x%02x00"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5))
end

-- The lines for this tooltip: { { member, objective name, text } }, members and objectives in a steady order
function G.Lines(data)
  if not next(G.members) then return nil end
  local kind, name, native, listed = Read(data)
  if not kind then return nil end
  local keys = {}
  for k in pairs(G.members) do keys[#keys + 1] = k end
  table.sort(keys)
  local out = {}
  for _, key in ipairs(keys) do
    local member = G.members[key].name
    local unit = G.UnitOf(key)
    local guid = unit and UnitGUID(unit)
    if Secret(guid) then guid = nil end
    local quests = G.members[key].quests
    local ids = {}
    for id in pairs(quests) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
      local shown = guid and listed[id] and listed[id][guid]
      if not shown then
        for _, obj in ipairs(quests[id][3]) do
          if Fits(kind, name, native, id, obj) then
            local count = obj[2] > 0 and ("|c%s%d/%d|r "):format(CountHex(obj[1], obj[2]), obj[1], obj[2]) or ""
            out[#out + 1] = { member, obj[4],
              L.GQ_LINE:format(("|c%s%s|r"):format(ClassHex(unit), member), count .. obj[4]) }
          end
        end
      end
    end
  end
  return out[1] and out or nil
end

-- A member's progress already written in the tooltip (by Questie: "12/24 Thing (Name)")?
local function Written(tooltip, member, objName)
  local name = tooltip:GetName()
  for i = 1, (tonumber(tooltip:NumLines()) or 0) do
    local fs = name and _G[name .. "TextLeft" .. i]
    local text = fs and fs:GetText()
    if text and not issecret(text) then
      local plain = Clean(text)
      if Lower(plain):find(Lower(member), 1, true) and Holds(plain, objName) then return true end
    end
  end
  return false
end
G.Written = Written

-- Worked out as the game builds the tooltip, written as it shows it: after every addon's own lines
local waiting
function G.PostCall(tooltip, data)
  if tooltip ~= GameTooltip then return end
  waiting = nil
  local ok, lines = pcall(G.Lines, data)
  if ok and lines then waiting = lines end
end

function G.Shown(tooltip)
  local lines = waiting
  if not lines or tooltip ~= GameTooltip then return end
  waiting = nil
  local added = false
  for _, line in ipairs(lines) do
    if not Written(tooltip, line[1], line[2]) then
      tooltip:AddLine(line[3], 1, 1, 1)
      added = true
    end
  end
  if added then tooltip:Show() end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
  for _, kind in ipairs({ KIND.Item, KIND.Unit, KIND.Object }) do
    if kind then TooltipDataProcessor.AddTooltipPostCall(kind, G.PostCall) end
  end
end
if GameTooltip then
  hooksecurefunc(GameTooltip, "Show", G.Shown)
  if GameTooltip.HookScript then GameTooltip:HookScript("OnTooltipCleared", function() waiting = nil end) end
end

---------------------------------------------------------------------------
-- /cl quetes: what was heard
---------------------------------------------------------------------------
function G.Report()
  local P = function(s) print("|cff33ff99Clara|r: " .. s) end
  if not InGroup() then P(L.GQ_REPORT_ALONE) return end
  local any = false
  for _, unit in ipairs(Units()) do
    local name = UnitWhole(unit)
    if name then
      local m = G.members[name:lower()]
      if m then
        local count = 0
        for _ in pairs(m.quests) do count = count + 1 end
        P(L.GQ_REPORT_MEMBER:format(name, count, math.floor(GetTime() - (m.heard or GetTime()))))
        any = true
      else
        P(L.GQ_REPORT_SILENT:format(name))
      end
    end
  end
  if G.lastResult and G.lastResult ~= 0 then P(L.GQ_REPORT_SEND:format(tostring(G.lastResult))) end
  if not any then P(L.GQ_REPORT_NONE) end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local wasInGroup = false
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
  if event == "CHAT_MSG_ADDON" then
    local prefix, text, channel, from = ...
    if prefix == PREFIX then G.Heard(text, channel, from) end
  elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
    Prune()
    local now = InGroup()
    local login, reload = ...
    local fresh = event == "PLAYER_ENTERING_WORLD" and (login or reload) -- (not a loading screen: nothing was lost)
    if now and (not wasInGroup or fresh) then
      -- (just joined, or logged in or reloaded: ask the others for theirs, send ours)
      wasInGroup = true
      C_Timer.After(fresh and 3 or 1, function()
        if InGroup() then
          Send({ "H" })
          Soon(true, 0.5)
        end
      end)
    elseif not now then
      wasInGroup = false
      wipe(G.sent)
    end
  elseif event == "UNIT_QUEST_LOG_CHANGED" then
    if ... == "player" then Soon(false) end
  else
    Soon(false)
  end
end)
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
for _, e in ipairs({ "CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE",
  "UNIT_QUEST_LOG_CHANGED", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN" }) do
  pcall(events.RegisterEvent, events, e)
end
