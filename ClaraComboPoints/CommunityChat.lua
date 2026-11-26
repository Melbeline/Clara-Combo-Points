-- Clara Combo Points - the community chats back after a login: a bug of the game's (WoW's own for years, WoW Forever's
-- too): a community whose chat a window shows (Guild & Communities > Add to Chat Window, its box ticked) is at times
-- not joined as the game starts: its lines never come and it has no /number, though its box stays ticked (unticking
-- it and ticking it again brought it back). After the login (the clubs in: 15 seconds for the game to join them on
-- its own) and every 30 seconds after, the community chats the windows show are looked at: one not joined is joined
-- again, as the game does when its box is ticked (C_Club.AddClubStreamChatChannel), silently; the windows' own lists
-- are left alone (the game's).
-- Blizzard's fix seen: ten logins in a row from the game started (not reloads) with every community chat joined on its
-- own: Clara stands aside (nothing joined any more), a line in the chat says it once; seen broken again at a login:
-- Clara steps in again. A box on Clara's page, on by default.
-- Who is online in a community: the game's Guild & Communities window asks for a community's members, never for their
-- presence (its chat channels window does both): its list showed them all offline. The community it shows is subscribed
-- to its members' presence too (C_Club.SetClubPresenceSubscription, as the chat channels window does), the window
-- shown; the game lets it go as the window hides. Its own presence (Battle.net's Appear Offline hides a player from the
-- communities) is the player's choice: left alone.

local ADDON, ns = ...
local L = ns.L

local FIXED_AFTER = 10 -- logins in a row without the bug: Blizzard's fix
local FIRST_LOOK = 15  -- seconds after the clubs are in: the game should have joined them by then
local EVERY = 30       -- seconds: the windows looked at again (a chat lost on the way)

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

local session = { looks = 0, joined = 0 }

-- The community chats the chat windows show (their names "Community:<club>:<stream>"), once each
local function Shown()
  local out, seen = {}, {}
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local frame = _G["ChatFrame" .. i]
    local list = frame and frame.channelList
    if type(list) ~= "table" and GetChatWindowChannels then list = { GetChatWindowChannels(i) } end
    for _, name in pairs(type(list) == "table" and list or {}) do
      if type(name) == "string" and not issecret(name) and not seen[name] then
        local club, stream = name:match("^Community:(%d+):(%d+)$")
        if club then
          seen[name] = true
          out[#out + 1] = { name = name, club = tonumber(club), stream = tonumber(stream) }
        end
      end
    end
  end
  return out
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

-- The chats looked at; at a login's first look (from the game started), what it says of the bug counted
local function Look(verdict)
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
    if #missing > 0 then
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
  if s.fixed then return end -- (Blizzard's fix: Clara stands aside)
  for _, c in ipairs(missing) do
    if pcall(C_Club.AddClubStreamChatChannel, c.club, c.stream) then
      session.joined = session.joined + 1
      session.last = c.name
      session.at = GetTime()
    end
  end
end
ns.CommunityChatLook = Look -- (for its test)

function ns:CommunityChatReport()
  local s = Store()
  return ("community chats: shown %s, not joined at the last look %s; joined again this session %d%s; logins in a row without the bug %d/%d; Blizzard's fix seen %s; box %s"):format(
    tostring(session.shown or "?"), tostring(session.missing or "?"), session.joined,
    session.last and (" (the last: " .. session.last .. (session.at and (", %.0f s ago"):format(GetTime() - session.at) or "") .. ")") or "",
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

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
pcall(events.RegisterEvent, events, "INITIAL_CLUBS_LOADED")
events:SetScript("OnEvent", function(self, event, isInitialLogin)
  if not (C_Club and C_Club.AddClubStreamChatChannel) then self:UnregisterAllEvents() return end -- (no communities here)
  if event == "PLAYER_ENTERING_WORLD" then
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    cold = isInitialLogin == true
    -- (the clubs' event missed, as after a reload: looked at a little later all the same)
    if C_Timer and C_Timer.After then C_Timer.After(FIRST_LOOK + 10, FirstLook) end
  elseif event == "INITIAL_CLUBS_LOADED" then
    if C_Timer and C_Timer.After then C_Timer.After(FIRST_LOOK, FirstLook) else FirstLook() end
  end
end)
