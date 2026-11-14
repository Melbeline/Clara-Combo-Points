-- Clara Combo Points - Permanent Report Mute: a player reported with the game's Report button (right-click a name >
-- Report, the report sent) stays muted for good, on every character of the account: the game hides their messages
-- for the session only; this hides them in every chat (say, yell, emotes, whispers, channels, group, raid, guild,
-- instance, communities) from then on, across reloads and logins. Its page (Esc > Options > AddOns > Clara >
-- Interface > Permanent Report Mute) lists them, each with its Remove button, and takes a name to add by hand (one
-- reported before the module was there). The game's report itself is untouched: the button's own click sends it,
-- this only reads who it was about afterwards. A player is known by their GUID (their name too, for a name typed or
-- a report without one). Saved with Clara's settings (ClaraComboPointsDB.reportMute), for the whole account.

local ADDON, ns = ...
local L = ns.L

local issecret = issecretvalue or function() return false end
local function Plain(v) return v ~= nil and not issecret(v) end

-- The list: key (the GUID, else "name:" and the name) -> { name, guid, when }
local function List()
  local sv = ns.sv
  if not sv then return {} end
  if type(sv.reportMute) ~= "table" then sv.reportMute = {} end
  return sv.reportMute
end

-- A name as compared: its case and its realm left out
local function Norm(name)
  if type(name) ~= "string" or issecret(name) then return nil end
  name = strtrim(name):gsub("%-.*$", "")
  if name == "" then return nil end
  return name:lower()
end

ns:SetQolOpener("reportmute", function() ns:OpenSettingsTo(ns.reportMuteCategory) end)
if not ns:QolRuns("reportmute") then return end

local byGuid, byName = {}, {}
local function Index()
  wipe(byGuid)
  wipe(byName)
  for _, entry in pairs(List()) do
    if type(entry) == "table" then
      if type(entry.guid) == "string" then byGuid[entry.guid] = entry end
      local n = Norm(entry.name)
      if n then byName[n] = entry end
    end
  end
end

local function Say(text)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Clara|r: " .. text) end
end

local Refresh = function() end -- (its page's list, once built)

-- Muted for good; nil when already there
local function Mute(name, guid)
  if type(guid) ~= "string" or not guid:find("^Player%-") then guid = nil end
  local n = Norm(name)
  if not (guid or n) then return nil end
  local list = List()
  local key = guid or ("name:" .. n)
  local found = (guid and byGuid[guid]) or (n and byName[n])
  if found then
    -- (known by name only: its GUID learned)
    if guid and not found.guid then
      for k, entry in pairs(list) do if entry == found then list[k] = nil end end
      found.guid = guid
      list[guid] = found
      Index()
    end
    return nil
  end
  list[key] = { name = (type(name) == "string" and not issecret(name)) and strtrim(name) or nil, guid = guid, when = time() }
  Index()
  Refresh()
  return list[key]
end
ns.ReportMuteAdd = Mute -- (for the tests)

local function Unmute(key)
  local list = List()
  local entry = list[key]
  if not entry then return end
  list[key] = nil
  Index()
  Refresh()
  Say(L.RM_REMOVED:format(entry.name or entry.guid or "?"))
end
ns.ReportMuteRemove = Unmute -- (for the tests)

function ns:ReportMuted(name, guid)
  if Plain(guid) and type(guid) == "string" and byGuid[guid] then return true end
  local n = Norm(name)
  return n ~= nil and byName[n] ~= nil
end

---------------------------------------------------------------------------
-- The report sent: who it was about (a player only: not a group's listing, a club, a pet, a house; not a PvP AFK
-- report), read after the game's own click
---------------------------------------------------------------------------
local function PersonTypes()
  local T = Enum and Enum.ReportType or {}
  local set = {}
  for _, k in ipairs({ "Chat", "InWorld", "ClubFinderApplicant", "GroupFinderApplicant", "ClubMember", "GroupMember",
    "Friend", "Mail", "PvPScoreboard", "PvPGroupMember", "CraftingOrder", "RecentAlly", "NeighborhoodRoster" }) do
    if T[k] ~= nil then set[T[k]] = true end
  end
  return set
end
local PERSON

local function Reported(frame)
  local info = frame and frame.reportInfo
  if type(info) ~= "table" then return end
  PERSON = PERSON or PersonTypes()
  local kind = info.reportType
  if kind ~= nil and not PERSON[kind] then return end
  local guid, name
  local loc = frame.reportPlayerLocation
  if type(loc) == "table" then
    if loc.GetGUID then guid = loc:GetGUID() end
    if not guid and loc.IsUnit and loc:IsUnit() and UnitGUID then guid = UnitGUID(loc:GetUnit()) end
    if loc.IsChatLineID and loc:IsChatLineID() and C_ChatInfo then
      local line = loc:GetChatLineID()
      if not guid and C_ChatInfo.GetChatLineSenderGUID then guid = C_ChatInfo.GetChatLineSenderGUID(line) end
      if C_ChatInfo.GetChatLineSenderName then name = C_ChatInfo.GetChatLineSenderName(line) end
    end
  end
  if not guid and type(info.reportTarget) == "string" then guid = info.reportTarget end
  if not Plain(guid) or type(guid) ~= "string" or not guid:find("^Player%-") then guid = nil end
  if Plain(frame.playerName) and type(frame.playerName) == "string" and frame.playerName ~= "" then name = frame.playerName end
  if not Plain(name) then name = nil end
  if not name and guid and GetPlayerInfoByGUID then
    local ok, _, _, _, _, _, n, realm = pcall(GetPlayerInfoByGUID, guid)
    if ok and Plain(n) and n ~= "" then name = (Plain(realm) and realm ~= "") and (n .. "-" .. realm) or n end
  end
  if not (guid or name) then return end
  local entry = Mute(name, guid)
  if entry then Say(L.RM_ADDED:format(entry.name or guid)) end
end
ns.ReportMuteReported = Reported -- (for the tests)

local hooked = false
local function HookReport()
  local frame = ReportFrame
  if hooked or type(frame) ~= "table" or (frame.IsForbidden and frame:IsForbidden()) then return end
  local button = frame.ReportButton
  if not (button and button.HookScript) then return end
  hooked = pcall(button.HookScript, button, "OnClick", function(self)
    local ok, err = pcall(Reported, self:GetParent() or frame)
    if not ok and geterrorhandler then geterrorhandler()(err) end
  end)
end

---------------------------------------------------------------------------
-- Their messages hidden, in every chat
---------------------------------------------------------------------------
local EVENTS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_WHISPER",
  "CHAT_MSG_CHANNEL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
  "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_GUILD",
  "CHAT_MSG_OFFICER", "CHAT_MSG_AFK", "CHAT_MSG_DND", "CHAT_MSG_COMMUNITIES_CHANNEL" }
-- (the chat events' arguments: the text, the author... the line's id, the author's GUID twelfth)
local function Filter(_, _, _, author, _, _, _, _, _, _, _, _, _, guid)
  if next(byGuid) == nil and next(byName) == nil then return false end
  return ns:ReportMuted(author, guid) and true or false
end
ns.ReportMuteFilter = Filter -- (for the tests)

local AddFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
if AddFilter then
  for _, event in ipairs(EVENTS) do pcall(AddFilter, event, Filter) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, name)
  if event == "PLAYER_LOGIN" then
    Index()
    HookReport()
  elseif name == "Blizzard_ReportFrame" then
    HookReport()
  end
end)

---------------------------------------------------------------------------
-- Its page: the muted players, each with Remove; a name to add by hand
---------------------------------------------------------------------------
local ROW_H, ROWS_MAX = 24, 400
local page = CreateFrame("Frame")
page:Hide()
local built = false
local rows = {}

local function Sorted()
  local out = {}
  for key, entry in pairs(List()) do
    if type(entry) == "table" then out[#out + 1] = { key = key, entry = entry } end
  end
  table.sort(out, function(a, b)
    return (a.entry.name or a.key):lower() < (b.entry.name or b.key):lower()
  end)
  return out
end

local function Build()
  built = true
  local title = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
  title:SetPoint("TOPLEFT", 14, -16)
  title:SetText(L.QOL_NAV_REPORTMUTE)
  local hint = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", 16, -50)
  hint:SetPoint("RIGHT", -16, 0)
  hint:SetJustifyH("LEFT")
  hint:SetWordWrap(true)
  hint:SetTextColor(.8, .8, .85)
  hint:SetText(L.RM_HINT)

  -- a name to add by hand
  local label = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  label:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -14)
  label:SetText(L.RM_ADD_LABEL)
  local box = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
  box:SetSize(220, 22)
  box:SetAutoFocus(false)
  box:SetPoint("LEFT", label, "RIGHT", 12, 0)
  local add = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  add:SetSize(100, 22)
  add:SetPoint("LEFT", box, "RIGHT", 8, 0)
  add:SetText(L.ADD)
  local function Add()
    local text = box:GetText()
    local entry = Mute(text, nil)
    if entry then Say(L.RM_ADDED:format(entry.name)) end
    box:SetText("")
    box:ClearFocus()
  end
  add:SetScript("OnClick", Add)
  box:SetScript("OnEnterPressed", Add)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  page.box, page.add = box, add

  local count = page:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  count:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -18)
  page.count = count

  local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", count, "BOTTOMLEFT", -2, -6)
  scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -30, 12)
  local sheet = CreateFrame("Frame", nil, scroll)
  sheet:SetSize(1, 1)
  scroll:SetScrollChild(sheet)
  page.sheet = sheet

  local empty = sheet:CreateFontString(nil, "ARTWORK", "GameFontDisable")
  empty:SetPoint("TOPLEFT", 4, -4)
  empty:SetText(L.RM_EMPTY)
  page.empty = empty
end

local function Row(i)
  if rows[i] then return rows[i] end
  local row = CreateFrame("Frame", nil, page.sheet)
  row:SetSize(500, ROW_H)
  row:SetPoint("TOPLEFT", page.sheet, "TOPLEFT", 0, -(i - 1) * ROW_H)
  row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  row.name:SetPoint("LEFT", 4, 0)
  row.name:SetWidth(240)
  row.name:SetJustifyH("LEFT")
  row.when = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  row.when:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
  row.when:SetWidth(130)
  row.when:SetJustifyH("LEFT")
  row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.remove:SetSize(100, 20)
  row.remove:SetPoint("LEFT", row.when, "RIGHT", 8, 0)
  row.remove:SetText(L.REMOVE)
  row.remove:SetScript("OnClick", function(self) Unmute(self.key) end)
  rows[i] = row
  return row
end

Refresh = function()
  if not built then return end
  local list = Sorted()
  local width = math.max(300, (page:GetWidth() or 600) - 50)
  page.sheet:SetWidth(width)
  page.sheet:SetHeight(math.max(1, #list * ROW_H))
  page.count:SetText(L.RM_COUNT:format(#list))
  page.empty:SetShown(#list == 0)
  for i = 1, math.min(#list, ROWS_MAX) do
    local row, item = Row(i), list[i]
    row.name:SetText(item.entry.name or item.entry.guid or item.key)
    row.when:SetText(item.entry.when and L.RM_WHEN:format(date("%Y-%m-%d", item.entry.when)) or "")
    row.remove.key = item.key
    row:Show()
  end
  for i = #list + 1, #rows do rows[i]:Hide() end
end
ns.ReportMuteRefresh = function() Refresh() end -- (for the tests)

page:SetScript("OnShow", function()
  if not built then Build() end
  Refresh()
end)
ns.ReportMutePage = page -- (for the tests)

if Settings and Settings.RegisterCanvasLayoutCategory then
  local ok, category = pcall(function()
    if ns:QolCategory("reportmute") and Settings.RegisterCanvasLayoutSubcategory then
      return Settings.RegisterCanvasLayoutSubcategory(ns:QolCategory("reportmute"), page, L.QOL_NAV_REPORTMUTE)
    end
    local c = Settings.RegisterCanvasLayoutCategory(page, L.QOL_NAV_REPORTMUTE)
    Settings.RegisterAddOnCategory(c)
    return c
  end)
  if ok and category then ns.reportMuteCategory = category end
end
