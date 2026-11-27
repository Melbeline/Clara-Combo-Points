-- Clara Combo Points - the community chats back after a login: a bug of the game's (WoW's own for years, WoW Forever's
-- too): a community whose chat a window shows (Guild & Communities > Add to Chat Window, its box ticked) is at times
-- not joined as the game starts: its lines never come and it has no /number, though its box stays ticked (unticking
-- it and ticking it again brought it back). Looked at as early as the game allows: as the communities are loaded
-- (before, the game knows none of them), as the world is entered (a reload: they are there already), again a few
-- seconds later, 15 seconds after, and every 30 seconds after that: a community chat the windows show, not joined, is
-- joined again, as the game does when its box is ticked (C_Club.AddClubStreamChatChannel), silently; the windows' own
-- lists are left alone (the game's).
-- Joined but its lines not coming to the window (the box ticked, the line seen in Guild & Communities, not in the
-- chat; unticking and ticking it again brought them back): the window's link to the channel, kept by the game itself
-- (AddChatWindowChannel), is lost, as after a chat joined late. So, as the game's own box does: at the first look of
-- each login (the reloads too) and after each chat joined again, each window showing a joined community chat is
-- linked to it again (RemoveChatWindowChannel, AddChatWindowChannel: the game's functions only, the windows' lists
-- untouched, nothing said), as soon as it is joined (once each session, and after each time it is joined again). And a community line seen (CLUB_MESSAGE_ADDED) with no chat line for it 3 seconds later
-- (CHAT_MSG_COMMUNITIES_CHANNEL) tells the link is lost: linked again at once, the line missed shown in those windows
-- (as the game shows it; not when the game keeps it secret), and the bug counted as seen (Clara steps in again).
-- Blizzard's fix seen: ten logins in a row from the game started (not reloads) with every community chat joined on its
-- own (none joined by Clara before the look 15 seconds after the communities came): Clara stands aside (nothing joined any more), a line in the chat says it once; seen broken again at a login:
-- Clara steps in again. A box on Clara's page, on by default.
-- Who is online in a community: the game's Guild & Communities window asks for a community's members, never for their
-- presence (its chat channels window does both): its list showed them all offline. The community it shows is subscribed
-- to its members' presence too (C_Club.SetClubPresenceSubscription, as the chat channels window does), the window
-- shown; the game lets it go as the window hides. Its own presence (Battle.net's Appear Offline hides a player from the
-- communities) is the player's choice: left alone.

local ADDON, ns = ...
local L = ns.L

-- (Melbeline's other addons carry the same fixes, CommunityFix.lua: Clara's run, theirs stand aside)
ClaraCommunityFix = ADDON

local FIXED_AFTER = 10 -- logins in a row without the bug: Blizzard's fix
local FIRST_LOOK = 15  -- seconds after the clubs are in: the game should have joined them by then
local EVERY = 30       -- seconds: the windows looked at again (a chat lost on the way)
local WAIT = 3         -- seconds: a community line's chat line waited for

local issecret = issecretvalue or function() return false end

function ns:CommunityChat() return not (self.sv and self.sv.communityChat == false) end
function ns:SetCommunityChat(on)
  if not self.sv then return end
  if on then self.sv.communityChat = nil else self.sv.communityChat = false end
end

-- What it learned, kept for the account: the logins in a row without the bug, Blizzard's fix seen
local function Store()
  local sv = ns.sv
  if not sv then return {} end
  if type(sv.communityChatFix) ~= "table" then sv.communityChatFix = {} end
  return sv.communityChatFix
end

local session = { looks = 0, joined = 0, linked = 0, lost = 0, replayed = 0 }

-- The community chats the chat windows show (their names "Community:<club>:<stream>"), once each, with the windows
local function Shown()
  local out, seen = {}, {}
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local frame = _G["ChatFrame" .. i]
    local list = frame and frame.channelList
    if type(list) ~= "table" and GetChatWindowChannels then list = { GetChatWindowChannels(i) } end
    for _, name in pairs(type(list) == "table" and list or {}) do
      if type(name) == "string" and not issecret(name) then
        local club, stream = name:match("^Community:(%d+):(%d+)$")
        if club then
          local c = seen[name]
          if not c then
            c = { name = name, club = tonumber(club), stream = tonumber(stream), windows = {} }
            seen[name] = c
            out[#out + 1] = c
          end
          if c.windows[#c.windows] ~= i then c.windows[#c.windows + 1] = i end
        end
      end
    end
  end
  return out, seen
end

-- Joined: the game gives it a number (/1, /2...)
local function Joined(name)
  local ok, id = pcall(GetChannelName, name)
  if not ok or issecret(id) then return true end -- (cannot tell: left alone)
  return type(id) == "number" and id > 0
end

local function Ours(club)
  if not (C_Club and C_Club.GetClubInfo) then return false end
  local ok, info = pcall(C_Club.GetClubInfo, club)
  return ok and info ~= nil
end

-- Each window showing a joined community chat linked to it again, as the game's box does (its own functions)
local relink = {} -- chats to link again once joined (just joined again: their number may come a moment later)
local function Link(c)
  if not (RemoveChatWindowChannel and AddChatWindowChannel) or not Joined(c.name) then return false end
  local done = true
  for _, i in ipairs(c.windows) do
    pcall(RemoveChatWindowChannel, i, c.name)
    local ok, zone = pcall(AddChatWindowChannel, i, c.name)
    if not ok or zone == nil then done = false end -- (again at the next look)
  end
  if done then
    session.linked = session.linked + 1
    session.linkedLast, session.linkedAt = c.name, GetTime()
  end
  return done
end

-- The chats looked at; at the look 15 s after a login from the game started, what it says of the bug counted; each
-- joined chat's windows linked to it once each session (and again after it is joined again)
local Look
local linked = {} -- (the chats whose windows were linked this session)
local function LinkPending(shown)
  for _, c in ipairs(shown) do
    if (relink[c.name] or not linked[c.name]) and Ours(c.club) and Link(c) then
      relink[c.name] = nil
      linked[c.name] = true
    end
  end
end
Look = function(verdict, quick)
  if not ns.sv or not ns:CommunityChat() then return end
  if InCombatLockdown and InCombatLockdown() then return end -- (again at the next look)
  if not (C_Club and C_Club.AddClubStreamChatChannel and GetChannelName) then return end
  session.looks = session.looks + 1
  local shown, missing = Shown(), {}
  for _, c in ipairs(shown) do
    if Ours(c.club) and not Joined(c.name) then missing[#missing + 1] = c end
  end
  session.shown, session.missing = #shown, #missing
  local s = Store()
  if verdict and #shown > 0 then
    if #missing > 0 or (session.early or 0) > 0 then -- (missing now, or joined by Clara at an early look)
      s.clean = 0
      if s.fixed then s.fixed = nil end -- (broken again: Clara steps in again)
    else
      s.clean = (s.clean or 0) + 1
      if s.clean >= FIXED_AFTER and not s.fixed then
        s.fixed = (GetBuildInfo and select(2, GetBuildInfo())) or true
        if DEFAULT_CHAT_FRAME and L and L.COMMUNITY_CHAT_FIXED then
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Clara|r: " .. L.COMMUNITY_CHAT_FIXED)
        end
      end
    end
  end
  if verdict ~= nil and not quick then session.early = 0 end -- (counted once, at this login's look)
  if s.fixed then return end -- (Blizzard's fix: Clara stands aside)
  for _, c in ipairs(missing) do
    if pcall(C_Club.AddClubStreamChatChannel, c.club, c.stream) then
      session.joined = session.joined + 1
      if quick then session.early = (session.early or 0) + 1 end
      session.last = c.name
      session.at = GetTime()
      relink[c.name] = true
    end
  end
  LinkPending(shown)
  -- (a chat joined again: linked as soon as it has its number)
  if next(relink) and C_Timer and C_Timer.After then C_Timer.After(WAIT, function() LinkPending((Shown())) end) end
end
ns.CommunityChatLook = Look -- (for its test)

---------------------------------------------------------------------------
-- A community line with no chat line: the window's link lost
---------------------------------------------------------------------------
local lastLine, waiting = {}, {}

-- The line missed shown in the windows, as the game shows a community chat's line (not when the game keeps it secret)
local function Replay(c, ids)
  if not (C_Club and C_Club.GetMessageInfo) then return end
  local ok, number = pcall(GetChannelName, c.name)
  if not ok or issecret(number) or type(number) ~= "number" or number <= 0 then return end
  local label = c.name
  if ChatFrameUtil and ChatFrameUtil.ResolveChannelName then
    local okL, l = pcall(ChatFrameUtil.ResolveChannelName, c.name)
    if okL and type(l) == "string" and not issecret(l) then label = l end
  end
  local color = ChatTypeInfo and ChatTypeInfo["CHANNEL" .. number]
  local r, g, b = 1, 0.75, 0.75
  if type(color) == "table" and type(color.r) == "number" then r, g, b = color.r, color.g, color.b end
  for _, id in ipairs(ids) do
    local okM, m = pcall(C_Club.GetMessageInfo, c.club, c.stream, id)
    local text = okM and type(m) == "table" and m.content
    local who = okM and type(m) == "table" and type(m.author) == "table" and m.author.name
    if type(text) == "string" and not issecret(text) and (who == nil or (type(who) == "string" and not issecret(who))) then
      local line = ("|Hchannel:channel:%d|h[%d. %s]|h %s%s"):format(number, number, label, who and ("[" .. who .. "]: ") or "", text)
      local okF, fmt = pcall(function() return ChatFrameUtil.GetTimestampFormat() end)
      if okF and type(fmt) == "string" and TimeUtil and TimeUtil.BetterDate then
        local okT, stamp = pcall(TimeUtil.BetterDate, fmt, time())
        if okT and type(stamp) == "string" then line = stamp .. line end
      end
      for _, i in ipairs(c.windows) do
        local frame = _G["ChatFrame" .. i]
        if frame and frame.AddMessage then frame:AddMessage(line, r, g, b) end
      end
      session.replayed = session.replayed + 1
    end
  end
end

local function Lost(name, ids)
  if not ns.sv or not ns:CommunityChat() then return end
  local _, byName = Shown()
  local c = byName[name]
  if not (c and Ours(c.club) and Joined(name)) then return end
  session.lost = session.lost + 1
  session.lostLast, session.lostAt = name, GetTime()
  local s = Store()
  s.clean = 0
  if s.fixed then s.fixed = nil end -- (broken again: Clara steps in again)
  Link(c)
  Replay(c, ids)
end
ns.CommunityChatLost = Lost -- (for its test)

local function ClubLine(club, stream, id)
  if not ns.sv or not ns:CommunityChat() then return end
  if club == nil or stream == nil or issecret(club) or issecret(stream) then return end
  local name = ("Community:%s:%s"):format(tostring(club), tostring(stream))
  local _, byName = Shown()
  if not byName[name] or not Joined(name) then return end -- (no window shows it, or not joined: the looks see to it)
  if lastLine[name] and GetTime() - lastLine[name] < WAIT then return end -- (its chat line came first)
  local list = waiting[name]
  if not list then
    list = {}
    waiting[name] = list
    if C_Timer and C_Timer.After then
      C_Timer.After(WAIT, function()
        if waiting[name] ~= list then return end -- (its chat line came)
        waiting[name] = nil
        Lost(name, list)
      end)
    end
  end
  list[#list + 1] = id
end

local function ChatLine(...)
  local name = select(9, ...)
  if type(name) ~= "string" or issecret(name) then -- (cannot tell which: none lost)
    for k in pairs(waiting) do waiting[k] = nil end
    return
  end
  lastLine[name] = GetTime()
  waiting[name] = nil
end

local relay = CreateFrame("Frame")
pcall(relay.RegisterEvent, relay, "CLUB_MESSAGE_ADDED")
pcall(relay.RegisterEvent, relay, "CHAT_MSG_COMMUNITIES_CHANNEL")
relay:SetScript("OnEvent", function(_, event, ...)
  if event == "CLUB_MESSAGE_ADDED" then ClubLine(...) else ChatLine(...) end
end)

function ns:CommunityChatReport()
  local s = Store()
  local function Ago(at) return at and (", %.0f s ago"):format(GetTime() - at) or "" end
  return ("community chats: shown %s, not joined at the last look %s; joined again this session %d%s; windows linked again %d%s; lines that did not come %d%s, shown again %d; logins in a row without the bug %d/%d; Blizzard's fix seen %s; box %s"):format(
    tostring(session.shown or "?"), tostring(session.missing or "?"), session.joined,
    session.last and (" (the last: " .. session.last .. Ago(session.at) .. ")") or "",
    session.linked, session.linkedLast and (" (the last: " .. session.linkedLast .. Ago(session.linkedAt) .. ")") or "",
    session.lost, session.lostLast and (" (the last: " .. session.lostLast .. Ago(session.lostAt) .. ")") or "", session.replayed,
    s.clean or 0, FIXED_AFTER, s.fixed and ("yes (build " .. tostring(s.fixed) .. ")") or "no", tostring(ns:CommunityChat()))
    .. (ns.CommunityPresenceText and ns.CommunityPresenceText() or "")
end

---------------------------------------------------------------------------
-- The communities window's community subscribed to its members' presence
---------------------------------------------------------------------------
local presence = { club = nil, times = 0 }
local function Subscribe(frame, clubId)
  if not (C_Club and C_Club.SetClubPresenceSubscription) or clubId == nil or issecret(clubId) then return end
  if not (frame and frame.IsShown and frame:IsShown()) then return end
  local info = C_Club.GetClubInfo and C_Club.GetClubInfo(clubId)
  if type(info) == "table" and Enum and Enum.ClubType and info.clubType == Enum.ClubType.Guild then return end -- (the guild's roster has its own)
  if pcall(C_Club.SetClubPresenceSubscription, clubId) then
    presence.club, presence.times = clubId, presence.times + 1
    presence.name = type(info) == "table" and not issecret(info.name) and info.name or nil
  end
end
ns.CommunityPresenceSubscribe = Subscribe -- (for its test)
ns.CommunityPresenceText = function()
  return ("; presence asked for %d times (the last: %s)"):format(presence.times, tostring(presence.name or presence.club or "none"))
end

local presenceHooked = false
local function HookPresence()
  local f = _G.CommunitiesFrame
  if presenceHooked or type(f) ~= "table" or type(f.OnClubSelected) ~= "function" then return end
  presenceHooked = true
  hooksecurefunc(f, "OnClubSelected", function(self, clubId) Subscribe(self, clubId) end)
  f:HookScript("OnShow", function(self)
    -- (shown again on the community it had: subscribed again, the game having let it go as it hid)
    if C_Timer and C_Timer.After then C_Timer.After(0, function() Subscribe(self, self.selectedClubId) end) end
  end)
end
HookPresence()
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
  if name == "Blizzard_Communities" then HookPresence() end
  if presenceHooked then self:UnregisterAllEvents() end
end)

local cold, looked, ticker
local function FirstLook()
  if looked then return end
  looked = true
  Look(cold)
  if not ticker and C_Timer and C_Timer.NewTicker then
    ticker = C_Timer.NewTicker(EVERY, function() Look(false) end)
  end
end

-- The early looks: at once, and again a moment later (the game joining its chats one by one)
local QUICK = { 0, 1, 3, 6 }
local lastQuick -- (the last early look: several of the game's events at once make one)
local function Quick()
  if looked then return end -- (the 15 s look done: the ticker's)
  local now = GetTime()
  if lastQuick and now - lastQuick < 0.2 then return end
  lastQuick = now
  Look(false, true)
end
local function QuickSoon()
  Quick()
  if C_Timer and C_Timer.After then
    for i = 2, #QUICK do C_Timer.After(QUICK[i], Quick) end
  end
end
ns.CommunityChatQuick = Quick -- (for its test)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
pcall(events.RegisterEvent, events, "INITIAL_CLUBS_LOADED")
pcall(events.RegisterEvent, events, "CLUB_STREAMS_LOADED")
events:SetScript("OnEvent", function(self, event, isInitialLogin)
  if not (C_Club and C_Club.AddClubStreamChatChannel) then self:UnregisterAllEvents() return end -- (no communities here)
  if event == "PLAYER_ENTERING_WORLD" then
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    cold = isInitialLogin == true
    QuickSoon() -- (a reload: the communities are there already)
    -- (the clubs' event missed, as after a reload: the 15 s look a little later all the same)
    if C_Timer and C_Timer.After then C_Timer.After(FIRST_LOOK + 10, FirstLook) end
  elseif event == "INITIAL_CLUBS_LOADED" then
    QuickSoon()
    if C_Timer and C_Timer.After then C_Timer.After(FIRST_LOOK, FirstLook) else FirstLook() end
  elseif event == "CLUB_STREAMS_LOADED" then
    Quick() -- (a community's chats known: looked at at once)
  end
end)
