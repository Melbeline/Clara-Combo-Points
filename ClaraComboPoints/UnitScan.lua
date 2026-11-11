-- Clara Combo Points - UnitScan: an alert as soon as a creature looked for is around. Looked for: the
-- rares of WoW Forever (Rares.lua, by NPC ID), the names added (any creature or player of that name,
-- accents and case aside), the hunted mob, and enemy players if asked. Seen through the game's own
-- means only: your target, the mouseover, the nameplates as they come, your group's targets. Then a
-- sound (twice), the screen's edges flashing red, the game's icon flashing in the taskbar (even with
-- Clara's "don't flash" box: let through for this alert only, put back once you are in the game
-- again), and a window: a click on it targets the creature (/targetexact, out of combat).
-- Other players' sightings: those of UnitScan Hardcore Forever (its hidden channel ushccomms, and its
-- messages in the guild and the group) are always heard; on your map (and your layer, when
-- NovaWorldBuffs knows both), close by: the alert; further: a line in the chat with a map pin. Yours go
-- out only with the box ticked (off by default), in UnitScan Hardcore's own format, with
-- NovaWorldBuffs' layer as it requires, one per key press or click (the game sends to a channel only
-- then). The hunted mob: one name, the last one set; its key (Key Bindings > Clara Combo Points)
-- targets it.

local ADDON, ns = ...
local L = ns.L

local issecret = issecretvalue or function() return false end
local floor, abs = math.floor, math.abs

local PREFIX, CHANNEL = "USHC", "ushccomms"
local COOLDOWN = 60      -- an alert per creature (name) at most this often
local SHARE_EVERY = 120  -- the same for what goes out, and for a far sighting's chat line
local NEAR = 60          -- close by: within 6 % of the map each way (UnitScan Hardcore's tolerance)
local REMOTE_FOR = 120   -- a far sighting kept this long: the alert if you come close
local SHOWN_FOR = 30     -- the window, unless clicked or closed
local SOUND = SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959

_G["BINDING_NAME_CLICK ClaraScanHunt:LeftButton"] = L.SCAN_HUNT_BINDING

local DEFAULTS = { rares = true, send = false, players = false, sound = true, flash = true, taskbar = true, far = true,
  plates = false }

local function Saved()
  local sv = ns.sv
  if not sv then return end
  sv.scan = sv.scan or {}
  return sv.scan
end

function ns:ScanOption(key)
  local s = Saved()
  local v = s and s[key]
  if v == nil then return DEFAULTS[key] end
  return v
end

---------------------------------------------------------------------------
-- What is looked for
---------------------------------------------------------------------------
local rareKeys          -- search key of a rare's name, in any of its languages -> NPC ID
local function RareKeys()
  if rareKeys then return rareKeys end
  rareKeys = {}
  for id, names in pairs(ns.RARES or {}) do
    for i = 1, 3 do
      if names[i] then rareKeys[ns:SearchKey(names[i])] = id end
    end
  end
  return rareKeys
end

-- A rare's name in the game's language (English for a language not known here)
local LANG = ({ frFR = 2, deDE = 3 })[GetLocale and GetLocale() or "enUS"] or 1
local function RareName(id)
  local names = ns.RARES and ns.RARES[id]
  return names and (names[LANG] or names[1])
end

local function Names() local s = Saved() return s and s.names end
local huntName, huntKey
local function HuntKey()
  local s = Saved()
  local hunt = s and s.hunt
  if hunt ~= huntName then huntName, huntKey = hunt, hunt and ns:SearchKey(hunt) end
  return huntKey
end

-- A name heard from another player (in their game's language): the name to show and target here, and
-- its key (a rare's by its ID, whatever the language; another's by its search key), or nil
local function Tracked(name)
  local key = ns:SearchKey(name)
  if key == "" then return end
  local names = Names()
  if names and names[key] then return names[key], key end
  local s = Saved()
  if s and s.hunt and HuntKey() == key then return s.hunt, key end
  if ns:ScanOption("rares") then
    local id = RareKeys()[key]
    if id then return RareName(id), "#" .. id end
  end
end

-- A yes from the game, never one it keeps secret (in some places a unit's state is)
local function Yes(v) return v == true and not issecret(v) end

local function NpcID(unit)
  local guid = UnitGUID(unit)
  if not guid or issecret(guid) then return end
  local kind, _, _, _, _, id = strsplit("-", guid)
  if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end

---------------------------------------------------------------------------
-- The alert: sound, screen, taskbar
---------------------------------------------------------------------------
local function Sound()
  PlaySound(SOUND, "Master")
  C_Timer.After(1, function() PlaySound(SOUND, "Master") end)
end

local flash
local function Flash()
  if not flash then
    flash = CreateFrame("Frame", nil, UIParent)
    flash:SetAllPoints()
    flash:SetFrameStrata("FULLSCREEN_DIALOG")
    flash:EnableMouse(false)
    local tex = flash:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\FullScreenTextures\\LowHealth")
    tex:SetBlendMode("ADD")
    flash:Hide()
    -- three pulses of 1.5 s: in, held, out
    flash:SetScript("OnUpdate", function(self)
      local t = GetTime() - self.t0
      local p = t % 1.5
      if t >= 4.5 then self:Hide() return end
      self:SetAlpha(p <= .5 and p * 2 or p <= 1 and 1 or 1 - (p - 1) * 2)
    end)
  end
  flash.t0 = GetTime()
  flash:SetAlpha(0)
  flash:Show()
end

-- The taskbar: the game's icon flashes only while the game is not the window in front (Windows' own
-- rule); EnableBlinkApplicationIcon, set to 0 by Clara's box (or anything else), is let through for
-- this flash, then put back at the first click, key or step in the game (or at logout).
local BLINK = "EnableBlinkApplicationIcon"
local blinkWas, back
local function BlinkBack()
  if blinkWas == nil then return end
  if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar(BLINK, blinkWas) end
  blinkWas = nil
  back:UnregisterAllEvents()
  if back.keys and not InCombatLockdown() then pcall(back.keys.EnableKeyboard, back.keys, false) end
end

local function Taskbar()
  if not FlashClientIcon then return end
  local cvar = C_CVar
  local now = cvar and cvar.GetCVar and cvar.GetCVar(BLINK)
  if now ~= nil and now ~= "1" then
    if blinkWas == nil then blinkWas = now end
    cvar.SetCVar(BLINK, "1")
  end
  FlashClientIcon()
  if blinkWas == nil then return end
  if not back then
    back = CreateFrame("Frame")
    back:SetScript("OnEvent", BlinkBack)
    if not InCombatLockdown() then
      local keys = CreateFrame("Frame", nil, UIParent)
      if pcall(keys.SetPropagateKeyboardInput, keys, true) then
        keys:SetScript("OnKeyDown", BlinkBack)
        back.keys = keys
      end
    end
  end
  for _, event in ipairs({ "GLOBAL_MOUSE_DOWN", "PLAYER_STARTED_MOVING", "PLAYER_LOGOUT" }) do pcall(back.RegisterEvent, back, event) end
  if back.keys and not InCombatLockdown() then pcall(back.keys.EnableKeyboard, back.keys, true) end
end

---------------------------------------------------------------------------
-- The window: a click targets the creature (a secure macro button: set out of combat only); in a
-- fight, the same look without the click, made clickable when the fight ends
---------------------------------------------------------------------------
local secure, plain   -- the two windows
local current         -- { name, sub, until }

local function Build(button)
  button:SetSize(210, 46)
  button:SetFrameStrata("FULLSCREEN_DIALOG")
  button:SetClampedToScreen(true)
  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetPoint("TOPLEFT", 3, -3)
  bg:SetPoint("BOTTOMRIGHT", -3, 3)
  bg:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
  bg:SetTexCoord(0, 1, 0, .25)
  local border = CreateFrame("Frame", nil, button, "BackdropTemplate")
  border:SetAllPoints()
  border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 })
  border:SetBackdropBorderColor(.7, .15, .05)
  button.title = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  button.title:SetPoint("TOPLEFT", 10, -8)
  button.title:SetPoint("RIGHT", -24, 0)
  button.title:SetJustifyH("LEFT")
  button.title:SetWordWrap(false)
  button.sub = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  button.sub:SetPoint("TOPLEFT", button.title, "BOTTOMLEFT", 0, -3)
  button.sub:SetPoint("RIGHT", -10, 0)
  button.sub:SetJustifyH("LEFT")
  button.sub:SetWordWrap(false)
  local glow = button:CreateTexture(nil, "OVERLAY")
  glow:SetPoint("CENTER")
  glow:SetSize(button:GetWidth() * 1.3, button:GetHeight() * 2.4)
  glow:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Alert-Glow")
  glow:SetBlendMode("ADD")
  glow:SetTexCoord(0, .78125, 0, .66796875)
  glow:SetAlpha(0)
  button.glow = glow
  button:SetScript("OnUpdate", function(self)
    local t = GetTime() - (self.t0 or 0)
    glow:SetAlpha(t <= .2 and t * 5 or t <= .7 and 1 - (t - .2) * 2 or 0)
    if current and GetTime() > current.untilAt and not (self == secure and InCombatLockdown()) then
      current = nil
      self:Hide()
    end
  end)
  local close = CreateFrame("Button", nil, button, "UIPanelCloseButton")
  close:SetSize(20, 20)
  close:SetPoint("TOPRIGHT", -2, -2)
  close:SetFrameLevel(border:GetFrameLevel() + 1)
  close:SetScript("OnClick", function()
    if button == secure and InCombatLockdown() then return end
    current = nil
    button:Hide()
  end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(self == secure and L.SCAN_WINDOW_TIP or L.SCAN_WINDOW_FIGHT, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", GameTooltip_Hide)
  -- Ctrl + drag moves it (both windows: the same spot)
  button:SetMovable(true)
  button:RegisterForDrag("LeftButton")
  button:SetScript("OnDragStart", function(self)
    if IsControlKeyDown() and not (self == secure and InCombatLockdown()) then self:StartMoving() end
  end)
  button:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local s, x, y = Saved(), self:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if s and x and ux then s.x, s.y = floor(x - ux + .5), floor(y - uy + .5) end
    for _, other in ipairs({ secure, plain }) do
      if other and other ~= self and not (other == secure and InCombatLockdown()) then
        other:ClearAllPoints()
        other:SetPoint("CENTER", UIParent, "CENTER", s and s.x or 0, s and s.y or -190)
      end
    end
  end)
  button:Hide()
end

local function Place(button)
  local s = Saved()
  button:ClearAllPoints()
  button:SetPoint("CENTER", UIParent, "CENTER", s and s.x or 0, s and s.y or -190)
end

local function Windows()
  if secure then return end
  secure = CreateFrame("Button", "ClaraScanButton", UIParent, "SecureActionButtonTemplate")
  secure:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
  secure:SetAttribute("type1", "macro")
  Build(secure)
  plain = CreateFrame("Button", nil, UIParent)
  Build(plain)
  Place(secure)
  Place(plain)
end

local function Show()
  if not current then return end
  Windows()
  local window = plain
  if not InCombatLockdown() then
    window = secure
    secure:SetAttribute("macrotext1", "/targetexact " .. current.name)
    plain:Hide()
    Place(secure)
  end
  window.title:SetText(current.name)
  window.sub:SetText(current.sub)
  window.t0 = GetTime()
  window:Show()
end

local regen = CreateFrame("Frame")
regen:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_REGEN_ENABLED")
  if current and plain and plain:IsShown() then Show() end
end)

local function Window(name, sub)
  current = { name = name, sub = sub, untilAt = GetTime() + SHOWN_FOR }
  Show()
  if InCombatLockdown() then regen:RegisterEvent("PLAYER_REGEN_ENABLED") end
end

---------------------------------------------------------------------------
-- Found: the alert (once a minute per creature), shared if the box says so
---------------------------------------------------------------------------
local alerted, shared, told = {}, {}, {}   -- key -> when: the alert, sent (or heard), the far line
local Share

local function Found(name, key, sub, mine, npc)
  local now = GetTime()
  if (alerted[key] and now - alerted[key] < COOLDOWN) or (UnitOnTaxi and UnitOnTaxi("player")) then return end
  alerted[key] = now
  if ns:ScanOption("sound") then Sound() end
  if ns:ScanOption("flash") then Flash() end
  if ns:ScanOption("taskbar") then Taskbar() end
  Window(name, sub)
  if mine and npc and ns:ScanOption("send") then Share(name, key) end
end
ns.ScanFound = Found -- (for the test button and the tests)

local function Look(unit)
  if not unit or not UnitExists(unit) then return end
  local name = UnitName(unit)
  if not name or issecret(name) then return end
  if Yes(UnitIsPlayer(unit)) then
    local key = ns:SearchKey(name)
    local names = Names()
    if (names and names[key]) or HuntKey() == key then
      Found(name, key, L.SCAN_SEEN, true, false)
    elseif ns:ScanOption("players") and Yes(UnitIsEnemy("player", unit)) and Yes(UnitCanAttack("player", unit)) then
      local level = UnitLevel(unit)
      local class = UnitClass(unit)
      if issecret(level) or issecret(class) then level, class = nil, nil end
      Found(name, key, L.SCAN_ENEMY .. (level and class and (" · " .. (level > 0 and level or "??") .. " " .. class) or ""), true, false)
    end
    return
  end
  if Yes(UnitPlayerControlled(unit)) or Yes(UnitIsDead(unit)) then return end
  local id = NpcID(unit)
  if id and ns.RARES and ns.RARES[id] and ns:ScanOption("rares") then
    local class = UnitClassification(unit)
    Found(name, "#" .. id, not issecret(class) and class == "rareelite" and L.SCAN_RARE_ELITE or L.SCAN_RARE, true, true)
    return
  end
  local names = Names()
  if (names and next(names)) or HuntKey() then
    local key = ns:SearchKey(name)
    if (names and names[key]) or HuntKey() == key then Found(name, key, L.SCAN_SEEN, true, true) end
  end
end

---------------------------------------------------------------------------
-- UnitScan Hardcore's format: "KEY|mapID|x|y|layer" (KEY the name in capitals, x and y in thousandths
-- of the map, the layer NovaWorldBuffs'), on its channel in Base64 after "USHC B64:"
---------------------------------------------------------------------------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_VALUE = {}
for i = 1, 64 do B64_VALUE[B64:sub(i, i)] = i - 1 end

local function Encode(data)
  local out = {}
  for i = 1, #data, 3 do
    local a, b, c = data:byte(i, i + 2)
    local n = a * 65536 + (b or 0) * 256 + (c or 0)
    local q = { floor(n / 262144) % 64, floor(n / 4096) % 64, floor(n / 64) % 64, n % 64 }
    out[#out + 1] = B64:sub(q[1] + 1, q[1] + 1) .. B64:sub(q[2] + 1, q[2] + 1)
      .. (b and B64:sub(q[3] + 1, q[3] + 1) or "=") .. (c and B64:sub(q[4] + 1, q[4] + 1) or "=")
  end
  return table.concat(out)
end

local function Decode(data)
  local out = {}
  data = data:gsub("[^%w%+/=]", "")
  for i = 1, #data - 3, 4 do
    local c1, c2, c3, c4 = data:sub(i, i), data:sub(i + 1, i + 1), data:sub(i + 2, i + 2), data:sub(i + 3, i + 3)
    local n = (B64_VALUE[c1] or 0) * 262144 + (B64_VALUE[c2] or 0) * 4096 + (B64_VALUE[c3] or 0) * 64 + (B64_VALUE[c4] or 0)
    out[#out + 1] = string.char(floor(n / 65536) % 256)
    if c3 ~= "=" then out[#out + 1] = string.char(floor(n / 256) % 256) end
    if c4 ~= "=" then out[#out + 1] = string.char(n % 256) end
  end
  return table.concat(out)
end
ns.ScanCodec = { Encode = Encode, Decode = Decode } -- (for the tests)

local function Here()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
  local map = C_Map.GetBestMapForUnit("player")
  if not map or issecret(map) then return end
  local pos = C_Map.GetPlayerMapPosition(map, "player")
  if not pos then return map end
  local x, y = pos:GetXY()
  if issecret(x) or issecret(y) or not x or x <= 0 or x > 1 or y <= 0 or y > 1 then return map end
  return map, floor(x * 1000 + .5), floor(y * 1000 + .5)
end

local function Layer()
  local layer = tonumber(_G.NWB_CurrentLayer)
  return layer and layer > 0 and layer or nil
end

---------------------------------------------------------------------------
-- Heard: other players' sightings
---------------------------------------------------------------------------
local remote = {}   -- key -> { name, map, x, y, at }
local proximity     -- the ticker looking at remote sightings while any is kept

local function MapPinLink(map, x, y)
  return ("|cff3fa9f5|Haddon:%s:pin:%d:%d:%d|h[%s]|h|r"):format(ADDON, map, x, y, L.SCAN_PIN)
end

local function CheckRemote()
  local now = GetTime()
  local map, x, y = Here()
  for key, seen in pairs(remote) do
    if now - seen.at > REMOTE_FOR then
      remote[key] = nil
    elseif map == seen.map and x and abs(x - seen.x) <= NEAR and abs(y - seen.y) <= NEAR then
      remote[key] = nil
      Found(seen.name, key, L.SCAN_HEARD, false, true)
    end
  end
  if not next(remote) and proximity then
    proximity:Cancel()
    proximity = nil
  end
end

local function Heard(text)
  local key, map, x, y, layer = strsplit("|", text, 5)
  if not (key and map) then return end
  local name, own = Tracked(key)
  if not name then return end
  map = tonumber(map)
  local hereMap, hereX, hereY = Here()
  if not map or map ~= hereMap then return end
  local ox, oy = tonumber(x), tonumber(y)
  if not (ox and oy) then
    -- the older format: KEY|mapID|subzone|layer
    local mine, theirs = Layer(), tonumber(y)
    if mine and theirs and theirs > 0 and mine ~= theirs then return end
    if x == GetSubZoneText() then
      shared[own] = GetTime()
      Found(name, own, L.SCAN_HEARD, false, true)
    end
    return
  end
  local mine, theirs = Layer(), tonumber(layer)
  if mine and theirs and theirs > 0 and mine ~= theirs then return end
  shared[own] = GetTime() -- (seen and told already: not sent again from here)
  if hereX and abs(hereX - ox) <= NEAR and abs(hereY - oy) <= NEAR then
    Found(name, own, L.SCAN_HEARD, false, true)
    return
  end
  local now = GetTime()
  remote[own] = { name = name, map = map, x = ox, y = oy, at = now }
  if not proximity then proximity = C_Timer.NewTicker(2, CheckRemote) end
  -- the chat line: once in a while, and not for a creature you have just seen yourself
  if ns:ScanOption("far") and not (told[own] and now - told[own] < SHARE_EVERY) and not (alerted[own] and now - alerted[own] < COOLDOWN) then
    told[own] = now
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    ns.Print(L.SCAN_FAR:format(name, info and info.name or "?", ox / 10, oy / 10) .. " " .. MapPinLink(map, ox, oy))
  end
end
ns.ScanHeard = Heard -- (for the tests)

local me
local function FromMe(sender)
  if type(sender) ~= "string" or issecret(sender) then return true end
  me = me or UnitName("player")
  return (Ambiguate and Ambiguate(sender, "none") or sender:match("^[^-]+")) == me
end

local function OnChannel(text, sender, channel)
  if type(text) ~= "string" or issecret(text) or type(channel) ~= "string" or issecret(channel) then return end
  if not channel:lower():find(CHANNEL, 1, true) or FromMe(sender) then return end
  local payload = text:match("[Bb]64:([%w%+/=]+)")
  if payload then
    Heard(Decode(payload))
  else
    local raw = text:match("^" .. PREFIX .. "%s*(.*)$")
    if raw then Heard((raw:gsub("||", "|"))) end
  end
end

---------------------------------------------------------------------------
-- Its channel: joined at each login (once the game's own channels are), hidden from the chat
---------------------------------------------------------------------------
local function ChannelID()
  local id = GetChannelName(CHANNEL)
  if id and id > 0 then return id, CHANNEL end
  local list = { GetChannelList() }
  for i = 1, #list, 3 do
    local name = list[i + 1]
    if type(name) == "string" and name:lower():find(CHANNEL, 1, true) then return list[i], name end
  end
end

local function HideChannel(name)
  for i = 1, NUM_CHAT_WINDOWS or 10 do
    local frame = _G["ChatFrame" .. i]
    if frame then
      if frame.RemoveChannel then pcall(frame.RemoveChannel, frame, name)
      elseif ChatFrame_RemoveChannel then pcall(ChatFrame_RemoveChannel, frame, name) end
    end
  end
end

local tries = 0
local function Join()
  local id, name = ChannelID()
  if id then HideChannel(name) return end
  -- after the game's channels and the ones the server rejoins (settled), to take the last number: never in front
  -- of the player's own (ChatPlace.lua keeps it after them too)
  local channels = ns.ChatChannels
  if channels and channels.Settled and not channels.Settled() then C_Timer.After(3, Join) return end
  tries = tries + 1
  if tries > 6 then return end
  -- after the game's own channels (General first), never before them
  if select("#", GetChannelList()) == 0 and tries < 5 then C_Timer.After(4, Join) return end
  -- (the game's own UI joins with JoinPermanentChannel: the last resort, if the other two are not there)
  local join = JoinChannelByName or JoinTemporaryChannel or JoinPermanentChannel
  if join then pcall(join, CHANNEL) end
  C_Timer.After(5, Join)
end

-- Its lines never shown in a chat window (nor the notice of joining it)
local function Quiet(_, _, _, _, _, channel, ...)
  local base = select(5, ...)
  for _, s in ipairs({ channel, base }) do
    if type(s) == "string" and not issecret(s) and s:lower():find(CHANNEL, 1, true) then return true end
  end
  return false
end
local AddFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
if AddFilter then
  AddFilter("CHAT_MSG_CHANNEL", Quiet)
  AddFilter("CHAT_MSG_CHANNEL_NOTICE", Quiet)
  AddFilter("CHAT_MSG_CHANNEL_NOTICE_USER", Quiet)
end

---------------------------------------------------------------------------
-- Sent (the box ticked): at the next key press or click in the world
---------------------------------------------------------------------------
local queue = {}
local SendChat = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage

local function SendNext()
  local entry = queue[1]
  if not entry then return end
  table.remove(queue, 1)
  local id = ChannelID()
  if id then
    pcall(SendChat, PREFIX .. " B64:" .. Encode(entry), "CHANNEL", nil, id)
  elseif C_ChatInfo and C_ChatInfo.SendAddonMessage then
    if IsInGuild() then pcall(C_ChatInfo.SendAddonMessage, PREFIX, entry, "GUILD") end
    if IsInGroup() then pcall(C_ChatInfo.SendAddonMessage, PREFIX, entry, IsInRaid() and "RAID" or "PARTY") end
  end
end

local sender
local function Sender()
  if sender or InCombatLockdown() then return end
  sender = CreateFrame("Frame", nil, UIParent)
  if pcall(sender.SetPropagateKeyboardInput, sender, true) then
    sender:EnableKeyboard(true)
    sender:SetScript("OnKeyDown", function() if queue[1] then SendNext() end end)
  end
  if WorldFrame and WorldFrame.HookScript then
    WorldFrame:HookScript("OnMouseDown", function() if queue[1] then SendNext() end end)
  end
end

function Share(name, key)
  local now = GetTime()
  if shared[key] and now - shared[key] < SHARE_EVERY then return end
  local layer = Layer()
  local map, x, y = Here()
  if not (layer and map and x) then return end -- (UnitScan Hardcore takes none without them)
  shared[key] = now
  Sender()
  queue[#queue + 1] = ("%s|%d|%d|%d|%d"):format(name:upper(), map, x, y, layer)
end

function ns:SetScanOption(key, value)
  local s = Saved()
  if not s then return end
  if value == DEFAULTS[key] then s[key] = nil else s[key] = value end
  if key == "send" and value then Sender() end
  if key == "plates" then ns:ScanPlates() end
  if key == "rares" then rareKeys = nil end
end

---------------------------------------------------------------------------
-- Names, the hunted mob and its key
---------------------------------------------------------------------------
function ns:ScanNames()
  local list = {}
  for _, name in pairs(Names() or {}) do list[#list + 1] = name end
  table.sort(list)
  return list
end

function ns:ToggleScanName(name)
  local s = Saved()
  name = name and strtrim(name)
  if not s or not name or name == "" then return end
  local key = ns:SearchKey(name)
  s.names = s.names or {}
  if s.names[key] then
    s.names[key] = nil
    if not next(s.names) then s.names = nil end
    return false
  end
  s.names[key] = name
  return true
end

local hunter
local function HuntButton()
  if InCombatLockdown() then regen:RegisterEvent("PLAYER_REGEN_ENABLED") return end
  if not hunter then
    hunter = CreateFrame("Button", "ClaraScanHunt", UIParent, "SecureActionButtonTemplate")
    hunter:RegisterForClicks("AnyUp", "AnyDown")
    hunter:SetAttribute("type", "macro")
  end
  local s = Saved()
  hunter:SetAttribute("macrotext", s and s.hunt and ("/targetexact " .. s.hunt) or "")
end

function ns:ScanHunt() local s = Saved() return s and s.hunt end

function ns:SetScanHunt(name)
  local s = Saved()
  if not s then return end
  name = name and strtrim(name)
  s.hunt = name ~= "" and name or nil
  HuntButton()
end

-- The hunted key set from a fight: set when it ends
regen:HookScript("OnEvent", function() if hunter or (Saved() and Saved().hunt) then HuntButton() end end)

---------------------------------------------------------------------------
-- Nameplates seen from further (the game's own setting, at its highest; given back when unticked)
---------------------------------------------------------------------------
local PLATE_CVAR, PLATE_FAR = "nameplateMaxDistance", "41"
function ns:ScanPlates()
  local s, cvar = Saved(), C_CVar
  if not (s and cvar and cvar.GetCVar and cvar.SetCVar) then return end
  local now = cvar.GetCVar(PLATE_CVAR)
  if ns:ScanOption("plates") then
    if s.plateWas == nil and now ~= nil then s.plateWas = now end
    if now ~= PLATE_FAR then pcall(cvar.SetCVar, PLATE_CVAR, PLATE_FAR) end
  elseif s.plateWas ~= nil then
    pcall(cvar.SetCVar, PLATE_CVAR, s.plateWas)
    s.plateWas = nil
  end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, a1, a2, a3, a4, ...)
  if event == "NAME_PLATE_UNIT_ADDED" then
    Look(a1)
  elseif event == "PLAYER_TARGET_CHANGED" then
    Look("target")
  elseif event == "UPDATE_MOUSEOVER_UNIT" then
    Look("mouseover")
  elseif event == "UNIT_TARGET" then
    if type(a1) == "string" and not issecret(a1) and (a1:find("^party%d") or a1:find("^raid%d")) then Look(a1 .. "target") end
  elseif event == "CHAT_MSG_CHANNEL" then
    OnChannel(a1, a2, a4)
  elseif event == "CHAT_MSG_ADDON" then
    if a1 == PREFIX and type(a2) == "string" and not issecret(a2) and not FromMe(a4) then Heard(a2) end
  elseif event == "PLAYER_ENTERING_WORLD" then
    tries = 0
    C_Timer.After(5, Join)
  end
end)

local function Start()
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end
  for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "UNIT_TARGET",
    "CHAT_MSG_CHANNEL", "CHAT_MSG_ADDON", "PLAYER_ENTERING_WORLD" }) do
    events:RegisterEvent(event)
  end
  if ns:ScanOption("send") then Sender() end
  if ns:ScanOption("plates") or (Saved() and Saved().plateWas) then ns:ScanPlates() end
  if ns:ScanHunt() then HuntButton() end
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_LOGIN")
  if not ns:QolRuns("unitscan") then return end -- (the module turned off)
  Start()
end)

-- A click on a far sighting's map pin: the game's own pin there, tracked
if EventRegistry and EventRegistry.RegisterCallback then
  local PIN = "addon:" .. ADDON .. ":pin:"
  EventRegistry:RegisterCallback("SetItemRef", function(_, link)
    if type(link) ~= "string" or link:sub(1, #PIN) ~= PIN then return end
    local map, x, y = link:sub(#PIN + 1):match("^(%d+):(%d+):(%d+)$")
    map, x, y = tonumber(map), tonumber(x), tonumber(y)
    if not (map and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(map) and UiMapPoint) then return end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x / 1000, y / 1000))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
  end, "ClaraScan")
end
