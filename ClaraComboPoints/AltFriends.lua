-- Clara Combo Points - characters in the friends list. WoW Forever's server keeps no character friends
-- (Battle.net friends only), and its list takes none of the account's own characters; Clara keeps a list of
-- characters instead (for the whole account: one's own and friends'), and shows them in the friends window
-- (WoW Forever's: in two sections of their own, online and offline, placed by the player; the older one: above the
-- offline Battle.net friends), in the game's look: online or offline (see "Online or not" below),
-- with their level and class as Clara last saw them (the gold tracker, or the character's own Clara) and when
-- last seen. Add Character, between Add Friend and Send Message (the three the same width), adds one by its
-- first name and surname with the suggestions of the mail's To field (the account's characters among them).
-- Over a row: its tooltip; right-click: whisper (online) or remove it from the list.
-- The game's Add Friend window in the 1.x look, two lines: the game's (a BattleTag, or a name the Forever way)
-- and one that adds a character to this list, the classic way.

local ADDON, ns = ...
local L = ns.L

local GAP = 2                -- between the three foot buttons
local LEFT, RIGHT = 4, 6     -- the game's margins for its two (FriendsFrameButtonTemplate_BottomLeft / _BottomRight)
local NAME_MAX = 12 + 1 + 64 -- a first name, a space, a surname (the game's own Add Friend box)
local HEARD = 300            -- seconds: a character heard on the sync this recently is online
local KNOWN_AFTER = 120      -- seconds after login: every character counts as known (offline unless found online)
local TYPE = "claraAlt"      -- the list entries' button type (the game's: numbers)

local AltFriends = {}
ns.AltFriends = AltFriends
AltFriends.TYPE = TYPE

---------------------------------------------------------------------------
-- The list (ns.sv.altFriends: lower-case whole name -> { name = "First Surname" })
---------------------------------------------------------------------------
local function Normal(name)
  if type(name) ~= "string" then return nil end
  name = name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
  if name == "" or #name > NAME_MAX then return nil end
  -- (each word with its capital, as the game writes a name: "Elle woods" typed, "Elle Woods" kept). Its first letter
  -- whole: an accented one is two bytes ("é"), and the game's capitals, which read UTF-8, broke its first byte taken
  -- alone ("Miss ▯milia"); "émilia" typed, "Émilia" kept.
  name = (name:gsub("%S+", function(word)
    local first, rest = word:match("^([%z\1-\127\194-\244][\128-\191]*)(.*)$")
    if not first then return word end
    return first:upper() .. rest
  end))
  return name
end

-- A name the earlier capitals broke (its accented first letter cut in two, kept so: "Éclair" became "▯clair"): the
-- replacement sign in it, or bytes that are no UTF-8
local function Broken(name)
  if type(name) ~= "string" or issecretvalue(name) then return false end
  if name:find("\239\191\189", 1, true) then return true end
  local i, n = 1, #name
  while i <= n do
    local b = name:byte(i)
    local len = b < 128 and 1 or (b >= 194 and b <= 223) and 2 or (b >= 224 and b <= 239) and 3 or (b >= 240 and b <= 244) and 4
    if not len then return true end
    for k = i + 1, i + len - 1 do
      local c = name:byte(k)
      if not c or c < 128 or c > 191 then return true end
    end
    i = i + len
  end
  return false
end
AltFriends.Broken = Broken
-- Its plain letters alone, lower-case (the accented ones, and what is left of a broken one, dropped): a broken name
-- and its whole spelling alike ("▯clair Chazal", "Éclair Chazal": "clair chazal")
local function Plain(name) return ((name:gsub("[\128-\255]", "")):lower()) end

local function List()
  local sv = ns.sv
  if not sv then return nil end
  if type(sv.altFriends) ~= "table" then sv.altFriends = {} end
  local list, moved = sv.altFriends, nil
  for key, alt in pairs(list) do
    if type(key) ~= "string" or type(alt) ~= "table" or type(alt.name) ~= "string" then list[key] = nil
    else
      -- (a broken name: its whole spelling back from its key, when that one is whole)
      if Broken(alt.name) and not Broken(key) and key:find("[\128-\255]") and Plain(key) == Plain(alt.name) then
        alt.name = key
      end
      if not Normal(alt.name) then list[key] = nil
      else
        alt.name = Normal(alt.name)
        if Broken(key) and not Broken(alt.name) then moved = moved or {}; moved[key] = alt end
      end
    end
  end
  -- (one kept under a broken key, its name whole: kept under its whole one)
  for key, alt in pairs(moved or {}) do
    list[key] = nil
    local whole = alt.name:lower()
    if not list[whole] then list[whole] = alt end
  end
  return list
end
AltFriends.List = List

-- A whole name seen or heard as the game writes it (a sender, a unit, a Battle.net friend's character, a character
-- known), or one of the names kept lower-case: one of the list whose name is broken takes it back, under its whole
-- name. Its first name and surname must match whole (their plain letters).
function AltFriends.Mend(heard)
  if issecretvalue(heard) or type(heard) ~= "string" then return false end
  local proper = ((heard:match("^([^%-]+)") or heard):gsub("^%s+", ""):gsub("%s+$", ""))
  if proper == "" or not proper:find("[\128-\255]") or Broken(proper) then return false end
  local list = List()
  if not list then return false end
  local plain = Plain(proper)
  for key, alt in pairs(list) do
    if Broken(alt.name) and Plain(alt.name) == plain then
      local name = Normal(proper)
      if not name then return false end
      list[key] = nil
      if not list[name:lower()] then list[name:lower()] = alt end
      alt.name = name
      if AltFriends.Refresh then AltFriends.Refresh() end
      return true
    end
  end
  return false
end

-- A line in the chat as the game's own system lines (yellow), in the game's words when it has them
local function SaySystem(text)
  local frame = DEFAULT_CHAT_FRAME
  if not (frame and frame.AddMessage) then return end
  local info = ChatTypeInfo and ChatTypeInfo.SYSTEM
  frame:AddMessage(text, info and info.r or 1, info and info.g or 1, info and info.b or 0)
end
AltFriends.SaySystem = SaySystem

-- Added or removed: said as the game says it of a friend ("Melbeline Moon added to friends."), the whole name
function AltFriends.Add(name)
  name = Normal(name)
  local list = List()
  if not (name and list) then return false end
  local key = name:lower()
  if list[key] then
    SaySystem((ERR_FRIEND_ALREADY_S or L.ALT_ALREADY):format(list[key].name))
    return false
  end
  list[key] = { name = name }
  SaySystem((ERR_FRIEND_ADDED_S or L.ALT_ADDED):format(name))
  AltFriends.Refresh()
  return true
end

function AltFriends.Remove(name)
  local list = List()
  if not (list and type(name) == "string") then return false end
  local alt = list[name:lower()]
  if not alt then return false end
  list[name:lower()] = nil
  SaySystem((ERR_FRIEND_REMOVED_S or L.ALT_REMOVED):format(alt.name))
  AltFriends.Refresh()
  return true
end

-- In the list's order: online first, then by name.
local function Sorted()
  local out = {}
  for _, alt in pairs(List() or {}) do out[#out + 1] = alt end
  table.sort(out, function(a, b)
    local oa, ob = AltFriends.Online(a.name), AltFriends.Online(b.name)
    if oa ~= ob then return oa end
    return a.name:lower() < b.name:lower()
  end)
  return out
end
AltFriends.Sorted = Sorted

---------------------------------------------------------------------------
-- What Clara knows of a character: online, level, class, last played
---------------------------------------------------------------------------
local function Realm()
  local realm = GetNormalizedRealmName and GetNormalizedRealmName() or (GetRealmName and GetRealmName() or "")
  return (realm or ""):gsub("%s", "")
end

-- Its key in the gold tracker and the sync ("First-Realm": the first name the game gives)
local function KeyOf(name) return (name:match("^(%S+)") or name) .. "-" .. Realm() end

local function IsMe(name)
  local me = ns.FullName and ns:FullName("player")
  return type(me) == "string" and me:lower() == name:lower()
end

-- Its first name (Clara's key for it in the gold tracker and the sync)
local function GameName(name) return name:match("^(%S+)") or name end
AltFriends.GameName = GameName
-- The name the server knows it by: the whole name, first name and surname (WoW Forever's names are unique with
-- their surname: a whisper to the first name alone finds no one), any realm part off, lower-case
local function Key(name) return ((name:match("^([^%-]+)") or name):gsub("^%s+", ""):gsub("%s+$", "")):lower() end

-- The server's answers (see "Online or not"): Key(name) -> { verdict = online, at, tried, sent, asked }
local probes = {}
local startedAt -- (GetTime at login)

local function SyncOnline(name)
  local S = ns.Sync
  if S and S.Online then return S.Online(KeyOf(name)) end
  local seen = S and S.seen and S.seen[KeyOf(name)]
  return type(seen) == "number" and GetTime() - seen < HEARD
end

-- This WoW account's characters (ns.sv: saved for this account alone), each kept as it logs in: Key(name) -> when
local function AccountChars()
  local sv = ns.sv
  if type(sv) ~= "table" then return nil end
  if type(sv.accountChars) ~= "table" then sv.accountChars = {} end
  return sv.accountChars
end

-- A gold tracker record's whole name ("First Surname")
local function WholeOf(rec)
  local whole = rec.n
  local surname = type(rec.s) == "string" and rec.s ~= "" and rec.s or nil
  if surname and not whole:lower():find(" " .. surname:lower(), 1, true) then whole = whole .. " " .. surname end
  return whole
end

-- Each character's WoW account, from the gold tracker (every account's characters: this one's, and the other
-- accounts' the sync brought): account[Key(name)] = id, members[id] = { whole names }, me = this account's id. Built
-- once a frame (a list sorted asks it of every character).
local index, indexAt, indexOf
local function AccountIndex()
  local now = GetTime()
  local db = ns.Money and ns.Money.db
  local chars = type(db) == "table" and db.chars or nil
  if index and indexAt == now and indexOf == chars then return index end
  index, indexAt, indexOf = { account = {}, members = {} }, now, chars
  if type(chars) == "table" then
    index.me = type(db.me) == "string" and db.me or nil
    for _, rec in pairs(db.chars) do
      if type(rec) == "table" and type(rec.n) == "string" and type(rec.a) == "string" then
        local whole = WholeOf(rec)
        index.account[Key(whole)] = rec.a
        local list = index.members[rec.a] or {}
        index.members[rec.a] = list
        list[#list + 1] = whole
      end
    end
  end
  return index
end

-- The list's broken names mended from every whole name Clara knows: the characters seen (their sex kept), this
-- account's, the gold tracker's, the Battle.net friends' characters in the game (nothing done while none is broken)
local function MendKnown()
  local any = false
  for _, alt in pairs(List() or {}) do if Broken(alt.name) then any = true break end end
  if not any then return end
  local names = {}
  local sv = ns.sv
  for key in pairs(type(sv) == "table" and type(sv.sexes) == "table" and sv.sexes or {}) do names[#names + 1] = key end
  for key in pairs(AccountChars() or {}) do names[#names + 1] = key end
  for _, list in pairs(AccountIndex().members) do
    for _, whole in ipairs(list) do names[#names + 1] = whole end
  end
  if C_BattleNet and C_BattleNet.GetFriendAccountInfo and BNGetNumFriends then
    local okCount, count = pcall(BNGetNumFriends)
    for i = 1, (okCount and type(count) == "number" and not issecretvalue(count)) and count or 0 do
      local ok, info = pcall(C_BattleNet.GetFriendAccountInfo, i)
      local game = ok and type(info) == "table" and info.gameAccountInfo
      if type(game) == "table" then names[#names + 1] = game.characterName end
    end
  end
  for _, name in ipairs(names) do
    if type(name) == "string" then AltFriends.Mend(name) end
  end
end
AltFriends.MendKnown = MendKnown

-- One of this WoW account's other characters: never online while the player plays (a WoW account plays one character
-- at a time), never asked. Known from the characters that logged in on this account, and from the gold tracker's
-- records of this account (by first name and surname).
local function OnThisAccount(name)
  if type(name) ~= "string" or IsMe(name) then return false end
  local key = Key(name)
  local mine = AccountChars()
  if mine and mine[key] then return true end
  local ix = AccountIndex()
  return ix.me ~= nil and ix.account[key] == ix.me
end
AltFriends.OnThisAccount = OnThisAccount

-- When it was last surely online, or nil: its own Clara answered or said hello, or it was heard in the chat by its
-- whole name, within the last minute; or the sync hears it. Never the server's silence alone (it may only be late).
local HEARD_FOR = 60
local function SurelyOnline(name)
  local at
  if SyncOnline(name) then
    local S = ns.Sync
    local seen = S and S.seen and S.seen[KeyOf(name)]
    at = type(seen) == "number" and seen or GetTime()
  end
  local p = probes[Key(name)]
  if p and p.verdict == true and type(p.heardAt) == "number" and GetTime() - p.heardAt < HEARD_FOR then
    at = math.max(at or p.heardAt, p.heardAt)
  end
  return at
end

-- Another of the player's WoW accounts playing another of its characters (surely online, and heard since this one
-- was): this one cannot be online (one character at a time per account), never asked
local function AccountBusy(name)
  if type(name) ~= "string" then return false end
  local key = Key(name)
  local ix = AccountIndex()
  local account = ix.account[key]
  if not account or account == ix.me then return false end
  local mine = SurelyOnline(name)
  for _, other in ipairs(ix.members[account] or {}) do
    if Key(other) ~= key then
      local at = SurelyOnline(other)
      if at and (not mine or at > mine) then return true end
    end
  end
  return false
end
AltFriends.AccountBusy = AccountBusy

-- Its WoW account plays another character: this account (the player's), or another one surely online
local function Elsewhere(name) return OnThisAccount(name) or AccountBusy(name) end
AltFriends.Elsewhere = Elsewhere

local function Verdict(name)
  local p = probes[Key(name)]
  if p then return p.verdict end
end

-- The newer of the two: the server's answer (or a Clara's hello or goodbye) and the sync's last word
function AltFriends.Online(name)
  if IsMe(name) then return true end
  if Elsewhere(name) then return false end
  local p = probes[Key(name)]
  local S = ns.Sync
  local heard = SyncOnline(name) and S and S.seen and S.seen[KeyOf(name)]
  if p and p.verdict ~= nil and (type(heard) ~= "number" or (p.at or 0) >= heard) then return p.verdict end
  return SyncOnline(name) and true or false
end

-- Whether Clara knows yet if it is online: the server answered, or the sync heard it, or long enough since login
function AltFriends.Known(name)
  if IsMe(name) or Elsewhere(name) or SyncOnline(name) or Verdict(name) ~= nil then return true end
  return startedAt ~= nil and GetTime() - startedAt > KNOWN_AFTER
end

-- A name as Leatrix's friend check compares it: first name and surname (WoW Forever's names are unique by both; two
-- characters may share a first name), its realm, case and spacing aside
local function FullKey(name)
  if type(name) ~= "string" or name == "" or (issecretvalue and issecretvalue(name)) then return nil end
  local consts = Constants and Constants.CharacterNameSeparatorConsts
  local sep = consts and consts.CHARACTERNAME_SURNAME_SEPARATOR
  name = name:match("^([^%-]+)") or name -- (its realm left out)
  if type(sep) == "string" and sep ~= "" and sep ~= " " and sep ~= "-" then
    name = name:gsub(sep:gsub("%p", "%%%0"), " ")
  end
  name = name:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
  if name == "" then return nil end
  return name:lower()
end
AltFriends.FullKey = FullKey -- (for the tests)

-- One of the player's characters, or one in Clara's list of characters (theirs and their friends'), by its first name
-- and surname: Leatrix's friends (its party invites accepted, invited on a whispered word). Known from Clara's list
-- and from the gold tracker (this account's characters, and the other accounts' the sync brought). A name with no
-- surname matches only a character with none.
function AltFriends.IsAlt(name)
  local key = FullKey(name)
  if not key then return false end
  if key == FullKey(ns.FullName and ns:FullName("player")) then return false end
  for _, alt in pairs(List() or {}) do
    if type(alt) == "table" and FullKey(alt.name) == key then return true end
  end
  local money = ns.Money and ns.Money.db and ns.Money.db.chars
  if type(money) == "table" then
    for _, rec in pairs(money) do
      if type(rec) == "table" and type(rec.n) == "string" then
        local full = rec.n
        local surname = type(rec.s) == "string" and rec.s ~= "" and rec.s or nil
        if surname and not full:lower():find(" " .. surname:lower(), 1, true) then full = full .. " " .. surname end
        if FullKey(full) == key then return true end
      end
    end
  end
  return false
end

-- Its sex (for the class's name, "Prêtresse" for a woman as the game says it since TBC): 2 male, 3 female, by
-- Key(name), for the whole account: one's own characters say theirs as they log in, a character's own addon says it
-- with its answer, the game tells it of one seen (in the chat, the group, the target, under the mouse)
local function Sexes()
  local store = ns.sv
  if type(store) ~= "table" then return nil end
  if type(store.sexes) ~= "table" then store.sexes = {} end
  return store.sexes
end
local function SexOf(name)
  local sexes = Sexes()
  return sexes and sexes[Key(name)]
end

function AltFriends.Facts(name)
  local facts = {}
  if IsMe(name) then
    facts.level = UnitLevel and UnitLevel("player")
    facts.class = select(2, UnitClass("player"))
    facts.sex = UnitSex and UnitSex("player")
    facts.zone = GetRealZoneText and GetRealZoneText() or (GetZoneText and GetZoneText())
    return facts
  end
  local money = ns.Money and ns.Money.db and ns.Money.db.chars
  local rec = money and money[KeyOf(name)]
  if rec then facts.level, facts.class, facts.at = rec.l, rec.c, rec.at end
  -- What its own Clara said (newer than the gold tracker's), and when Clara last found it online
  local alt = (List() or {})[name:lower()]
  if type(alt) == "table" then
    if alt.level and (not facts.at or (alt.levelAt or 0) >= facts.at) then
      facts.level, facts.class = alt.level, alt.class or facts.class
    end
    if alt.class then facts.class = alt.class end -- (a class never changes: known from the game alone too)
    if alt.zone and AltFriends.Online(name) then facts.zone = alt.zone end
    if type(alt.seen) == "number" and (not facts.at or alt.seen > facts.at) then facts.at = alt.seen end
  end
  facts.sex = (type(alt) == "table" and alt.sex) or SexOf(name)
  return facts
end

local function ClassName(class, sex)
  if not class then return nil end
  local names = sex == 3 and LOCALIZED_CLASS_NAMES_FEMALE or LOCALIZED_CLASS_NAMES_MALE
  return (names and names[class]) or (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
end

-- A name in its class's color (the game's own class colors), when its class is known
local function ClassColored(text, class)
  if type(class) ~= "string" or class == "" then return text end
  local ok, color = pcall(function()
    return (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class))
      or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
  end)
  if not ok or type(color) ~= "table" then return text end
  if color.WrapTextInColorCode then return color:WrapTextInColorCode(text) end
  if type(color.r) ~= "number" then return text end
  return ("|cff%02x%02x%02x%s|r"):format(math.floor(color.r * 255 + 0.5), math.floor(color.g * 255 + 0.5), math.floor(color.b * 255 + 0.5), text)
end

local function Ago(at)
  if type(at) ~= "number" or at <= 0 or not time then return nil end
  local seconds = math.max(60, time() - at)
  local text = SecondsToTime and SecondsToTime(seconds, false, false, 1) or (math.floor(seconds / 60) .. " min")
  return L.ALT_LAST_SEEN:format(text)
end

---------------------------------------------------------------------------
-- Add Alt: a name typed (first name and surname), with the To field's suggestions
---------------------------------------------------------------------------
local function Box(dialog) return dialog and (dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox) end

local function Dialog()
  if StaticPopupDialogs.CLARA_ADD_ALT then return end
  local choices = AUTOCOMPLETE_LIST and AUTOCOMPLETE_LIST.MAIL
  StaticPopupDialogs.CLARA_ADD_ALT = {
    text = L.ALT_ADD_ASK,
    button1 = ACCEPT or "Accept",
    button2 = CANCEL or "Cancel",
    hasEditBox = 1,
    autoCompleteSource = C_AutoComplete and C_AutoComplete.GetAutoCompleteResults or nil,
    autoCompleteArgs = choices and { choices.include, choices.exclude } or nil,
    maxLetters = NAME_MAX,
    OnAccept = function(dialog) local box = Box(dialog) if box then AltFriends.Add(box:GetText()) end end,
    OnShow = function(dialog) local box = Box(dialog) if box then box:SetFocus() end end,
    OnHide = function(dialog) local box = Box(dialog) if box then box:SetText("") end end,
    EditBoxOnEnterPressed = function(editBox)
      AltFriends.Add(editBox:GetText())
      editBox:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
    timeout = 0, exclusive = 1, whileDead = 1, hideOnEscape = 1,
  }
end

function AltFriends.Ask()
  Dialog()
  StaticPopup_Show("CLARA_ADD_ALT")
end

---------------------------------------------------------------------------
-- The game's Add Friend window in the 1.x look (the 1.15 client's): "Add Friend" and its "?", the Battle.net
-- and faction icons with OR between, then two lines to type in. The top line is the game's own box, only
-- moved: a BattleTag, or a name sent the Forever way, by its own Enter and Add Friend button (the game's code,
-- untouched: an addon's code may not send a friend request). The bottom line adds a character to Clara's list,
-- the classic way: at once, no request. Drawn over the game's window: its parts moved, restyled or hidden,
-- none of its values written; its "?" page left as the game's.
---------------------------------------------------------------------------
local ADD_W, ADD_H = 384, 264      -- the 1.15 window (232 high), a line more
local LINE_Y, LINE_STEP = -130, 32 -- the first line (where the 1.15 one is), the second under it
local LINE_W = 280
local BUTTON_COORDS = { 0, 0.625, 0, 0.6875 }

local addPage, charBox, charAccept, leftIcon, leftFriend, leftHead, leftText, rightIcon

local function GameAddFriend()
  local frame, entry, box = AddFriendFrame, AddFriendEntryFrame, AddFriendNameEditBox
  local accept, cancel = AddFriendEntryFrameAcceptButton, AddFriendEntryFrameCancelButton
  if frame and entry and box and accept and cancel then return frame, entry, box, accept, cancel end
end

-- The 1.x red button (the 1.15 window's)
local function PanelLook(button)
  for _, part in ipairs({ { "Normal", "Up" }, { "Pushed", "Down" }, { "Disabled", "Disabled" }, { "Highlight", "Highlight" } }) do
    local state, file = part[1], part[2]
    button["Set" .. state .. "Texture"](button, "Interface\\Buttons\\UI-Panel-Button-" .. file)
    local tex = button["Get" .. state .. "Texture"](button)
    if tex then tex:SetTexCoord(unpack(BUTTON_COORDS)) end
  end
  local tex = button:GetHighlightTexture()
  if tex and tex.SetBlendMode then tex:SetBlendMode("ADD") end
end

-- The 1.x box border (Common-Input-Border), on the box's three pieces
local function InputLook(box, left, right, middle)
  local file = "Interface\\Common\\Common-Input-Border"
  left:SetTexture(file)
  left:SetTexCoord(0, 0.0625, 0, 0.625)
  left:ClearAllPoints()
  left:SetWidth(8)
  left:SetPoint("TOPLEFT", box, "TOPLEFT", -5, 0)
  left:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", -5, 0)
  right:SetTexture(file)
  right:SetTexCoord(0.9375, 1, 0, 0.625)
  right:ClearAllPoints()
  right:SetWidth(8)
  right:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
  middle:SetTexture(file)
  middle:SetTexCoord(0.0625, 0.9375, 0, 0.625)
  middle:ClearAllPoints()
  middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
  middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
end

local function TopText()
  local box = AddFriendNameEditBox
  local ok, text = pcall(function() return box:GetText() end)
  return ok and type(text) == "string" and not issecretvalue(text) and text or ""
end

-- The game's Add Friend button while the top line has text (its own state: the game's), ours for the bottom one
local function AddButtons()
  if not addPage then return end
  local _, _, _, accept = GameAddFriend()
  local top = TopText() ~= ""
  accept:SetShown(top)
  charAccept:SetShown(not top)
  charAccept:SetEnabled(Normal(charBox:GetText()) ~= nil)
end

-- The bottom line's character added (and the window shut when the top line is empty and it asks to)
local function AddCharacter(close)
  if not charBox then return false end
  local text = charBox:GetText()
  if not Normal(text) then return false end
  charBox:SetText("")
  AltFriends.Add(text)
  if close and TopText() == "" and AddFriendFrame and AddFriendFrame:IsShown() then
    if StaticPopupSpecial_Hide then StaticPopupSpecial_Hide(AddFriendFrame) else AddFriendFrame:Hide() end
  end
  AddButtons()
  return true
end
AltFriends.AddCharacter = AddCharacter

-- The left column as the game wrote its own (BattleTag or Real ID, or Battle.net unavailable in red)
local function MirrorLeft()
  local entry = AddFriendEntryFrame
  local holder = entry and entry.OptionsContainer and entry.OptionsContainer.LeftTextContainer
  if not (holder and leftHead) then return end
  local ok, title, desc, alpha, r, g, b = pcall(function()
    local r, g, b = holder.Description:GetTextColor()
    return holder.Title:GetText(), holder.Description:GetText(), holder.Title:GetAlpha(), r, g, b
  end)
  if not ok then return end
  if type(title) == "string" and not issecretvalue(title) and title ~= "" then leftHead:SetText(title) end
  if type(desc) == "string" and not issecretvalue(desc) then leftText:SetText(desc) end
  leftHead:SetAlpha(type(alpha) == "number" and alpha or 1)
  if type(r) == "number" then leftText:SetTextColor(r, g, b) end
  local grey = type(alpha) == "number" and alpha < 1 and 0.4 or 1
  leftIcon:SetVertexColor(grey, grey, grey)
  leftFriend:SetVertexColor(grey, grey, grey)
end

-- Each time the entry page shows: the game's border and cross off (the page has its own), the faction icon,
-- the left column, the bottom line empty, the button's 1.x text
local function DressShown()
  local frame, entry, _, accept = GameAddFriend()
  if not (frame and addPage) then return end
  local level = entry:GetFrameLevel()
  addPage:SetFrameLevel(level)
  charBox:SetFrameLevel(level + 2)
  charAccept:SetFrameLevel(level + 2)
  if frame.Border then frame.Border:Hide() end
  if frame.CloseButton then frame.CloseButton:Hide() end
  local faction = UnitFactionGroup("player")
  if faction == "Alliance" or faction == "Horde" then
    rightIcon:SetTexture("Interface\\FriendsFrame\\PlusManz-" .. faction)
    rightIcon:Show()
  else
    rightIcon:Hide()
  end
  charBox:SetText("")
  MirrorLeft()
  accept:SetText(ADD_FRIEND or "Add Friend")
  AddButtons()
end

-- The "?" page (the game's): its border and cross back
local function Undress()
  local frame = AddFriendFrame
  if not frame then return end
  if frame.Border then frame.Border:Show() end
  if frame.CloseButton then frame.CloseButton:Show() end
end

local function Column(page, file, point, x)
  local icon = page:CreateTexture(nil, "BORDER")
  icon:SetTexture(file)
  icon:SetSize(40, 40)
  icon:SetAlpha(0.5)
  icon:SetPoint(point, page, point, x, -50)
  local friend = page:CreateTexture(nil, "ARTWORK")
  friend:SetTexture("Interface\\FriendsFrame\\PlusManz-PlusManz")
  friend:SetSize(36, 36)
  friend:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", -10, -4)
  local head = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  head:SetPoint("TOP", friend, "BOTTOM", 8, 4)
  local text = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  text:SetPoint("TOP", head, "BOTTOM", 0, -4)
  text:SetWidth(160)
  text:SetJustifyH("CENTER")
  return icon, friend, head, text
end

local function MakeCharBox(page, gameBox)
  local box = CreateFrame("EditBox", "ClaraAddFriendCharacterBox", page, "AutoCompleteEditBoxTemplate")
  box:SetSize(LINE_W, 20)
  box:SetPoint("TOP", page, "TOP", 0, LINE_Y - LINE_STEP)
  box:SetAutoFocus(false)
  box:SetMaxLetters(NAME_MAX)
  local font = gameBox.GetFontObject and gameBox:GetFontObject()
  box:SetFontObject(font or GameFontHighlightSmall)
  InputLook(box, box:CreateTexture(nil, "BACKGROUND"), box:CreateTexture(nil, "BACKGROUND"), box:CreateTexture(nil, "BACKGROUND"))
  local gameFill = AddFriendNameEditBoxFill
  local fill = box:CreateFontString(nil, "BORDER", "GameFontDisableSmall")
  local fillFont = gameFill and gameFill.GetFontObject and gameFill:GetFontObject()
  if fillFont then fill:SetFontObject(fillFont) end
  fill:SetPoint("LEFT", box, "LEFT", 0, 0)
  fill:SetText(L.ALT_ADD_FILL)
  box.fill = fill
  local choices = AUTOCOMPLETE_LIST and AUTOCOMPLETE_LIST.MAIL
  if AutoCompleteEditBox_SetAutoCompleteSource and C_AutoComplete and choices then
    AutoCompleteEditBox_SetAutoCompleteSource(box, C_AutoComplete.GetAutoCompleteResults, choices.include, choices.exclude)
    box.addHighlightedText = true
  end
  box:SetScript("OnEnterPressed", function(self)
    if AutoCompleteEditBox_OnEnterPressed and AutoCompleteEditBox_OnEnterPressed(self) then return end
    AddCharacter(true)
  end)
  box:SetScript("OnTextChanged", function(self, userInput)
    if AutoCompleteEditBox_OnTextChanged then AutoCompleteEditBox_OnTextChanged(self, userInput) end
    self.fill:SetShown(self:GetText() == "")
    AddButtons()
  end)
  box:SetScript("OnTabPressed", function(self)
    if AutoCompleteEditBox_OnTabPressed and AutoCompleteEditBox_OnTabPressed(self) then return end
    gameBox:SetFocus()
  end)
  box:SetScript("OnEscapePressed", function(self)
    if AutoCompleteEditBox_OnEscapePressed and AutoCompleteEditBox_OnEscapePressed(self) then return end
    self:ClearFocus()
  end)
  box:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(L.ALT_ADD_BUTTON, 1, 1, 1)
    GameTooltip:AddLine(L.ALT_ADD_TIP, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  box:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return box
end

local function MakeAddPage(frame, entry, box, accept, cancel)
  local page = CreateFrame("Frame", "ClaraAddFriendPage", entry, "BackdropTemplate")
  page:SetSize(ADD_W, ADD_H)
  page:SetPoint("TOP", frame, "TOP", 0, 0)
  page:EnableMouse(true)
  if page.SetBackdrop then
    page:SetBackdrop(BACKDROP_DIALOG_32_32 or {
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileEdge = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
  end
  local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOP", page, "TOP", -12, -24)
  title:SetText(ADD_FRIEND or "Add Friend")
  local orLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  orLabel:SetPoint("TOP", page, "TOP", 0, -66)
  orLabel:SetText(OR_CAPS or "OR")
  orLabel:SetTextColor(1, 1, 1)
  leftIcon, leftFriend, leftHead, leftText = Column(page, "Interface\\FriendsFrame\\PlusManz-BattleNet", "TOPLEFT", 92)
  leftHead:SetText(BATTLETAG or "BattleTag")
  local rightFriend, rightHead, rightText
  rightIcon, rightFriend, rightHead, rightText = Column(page, "Interface\\FriendsFrame\\PlusManz-Alliance", "TOPRIGHT", -82)
  rightHead:SetText(CHARACTER_FRIEND or "Character")
  rightText:SetText(L.ALT_ADD_CLASSIC)

  -- the game's parts: its "?" by the title, its box the top line, its two buttons at the 1.15 spots
  local info = AddFriendEntryFrameInfoButton
  if info then
    info:ClearAllPoints()
    info:SetPoint("LEFT", title, "RIGHT", 8, 0)
  end
  box:ClearAllPoints()
  box:SetPoint("TOP", page, "TOP", 0, LINE_Y)
  box:SetWidth(LINE_W)
  if box.Left and box.Right and AddFriendNameEditBoxMiddle then InputLook(box, box.Left, box.Right, AddFriendNameEditBoxMiddle) end
  accept:ClearAllPoints()
  accept:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 45, 30)
  accept:SetSize(118, 22)
  PanelLook(accept)
  cancel:ClearAllPoints()
  cancel:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -50, 30)
  cancel:SetSize(118, 22)
  PanelLook(cancel)
  local hide = { entry.TitleContainer, entry.OptionsContainer, entry.EditBoxContainer and entry.EditBoxContainer.RequestInfoText }
  for i = 1, 3 do if hide[i] then hide[i]:Hide() end end

  addPage = page
  charBox = MakeCharBox(page, box)
  local errorText = entry.EditBoxContainer and entry.EditBoxContainer.ErrorMessage
  if errorText then
    errorText:ClearAllPoints()
    errorText:SetPoint("TOP", charBox, "BOTTOM", 0, -6)
  end
  charAccept = CreateFrame("Button", "ClaraAddFriendCharacterButton", page)
  charAccept:SetNormalFontObject(GameFontNormal)
  charAccept:SetHighlightFontObject(GameFontHighlight)
  charAccept:SetDisabledFontObject(GameFontDisable)
  charAccept:SetText(ADD_FRIEND or "Add Friend")
  charAccept:SetSize(118, 22)
  charAccept:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 45, 30)
  PanelLook(charAccept)
  charAccept:SetScript("OnClick", function() AddCharacter(true) end)
  AltFriends.addPage, AltFriends.charBox, AltFriends.charAccept = page, charBox, charAccept
end

-- Once: the page made, the game's window hooked (after its own code each time: nothing of it changed)
function AltFriends.DressAddFriend()
  if addPage then return true end
  local frame, entry, box, accept, cancel = GameAddFriend()
  if not frame then return false end
  MakeAddPage(frame, entry, box, accept, cancel)
  entry:HookScript("OnShow", DressShown)
  entry:HookScript("OnHide", Undress)
  box:HookScript("OnTextChanged", AddButtons)
  box:HookScript("OnTabPressed", function()
    if not (AutoCompleteBox and AutoCompleteBox:IsShown()) then charBox:SetFocus() end
  end)
  -- (both lines typed: the game's Add Friend or Enter sends the top one, the bottom one added after it)
  accept:HookScript("OnClick", function() AddCharacter(false) end)
  if AddFriendFrame_Accept then hooksecurefunc("AddFriendFrame_Accept", function() AddCharacter(false) end) end
  if AddFriendFrame_Show then hooksecurefunc("AddFriendFrame_Show", MirrorLeft) end
  if AddFriendEntryFrame_Init then
    hooksecurefunc("AddFriendEntryFrame_Init", function() accept:SetText(ADD_FRIEND or "Add Friend") end)
  end
  if entry:IsVisible() then DressShown() end
  return true
end

---------------------------------------------------------------------------
-- The foot: Add Friend, Add Alt, Send Message, the same width
---------------------------------------------------------------------------
local altButton

local function MakeButton(parent)
  local cui = ns.ClassicUIRuns and ns.ClassicUIPrivate
  local button
  if cui and cui.PanelButton then
    button = cui.PanelButton(parent, L.ALT_ADD_BUTTON, 100) -- (ClassicUI's 1.x button, as the other two there)
  else
    button = CreateFrame("Button", "ClaraAddAltButton", parent, "UIPanelButtonTemplate")
    button:SetText(L.ALT_ADD_BUTTON)
  end
  button:SetScript("OnClick", function() AltFriends.Ask() end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L.ALT_ADD_BUTTON, 1, 1, 1)
    GameTooltip:AddLine(L.ALT_ADD_TIP, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return button
end

function AltFriends.LayFoot()
  local add, send = FriendsFrameAddFriendButton, FriendsFrameSendMessageButton
  if not (add and send and FriendsFrame) then return false end
  altButton = altButton or MakeButton(add:GetParent())
  AltFriends.button = altButton
  local width = FriendsFrame:GetWidth() or 0
  if width <= 0 then width = 338 end
  local w = math.floor((width - LEFT - RIGHT - 2 * GAP) / 3)
  add:SetWidth(w)
  send:SetWidth(w)
  altButton:ClearAllPoints()
  altButton:SetPoint("LEFT", add, "RIGHT", GAP, 0)
  altButton:SetPoint("RIGHT", send, "LEFT", -GAP, 0)
  altButton:SetHeight(add:GetHeight() or 21)
  altButton:Show()
  return true
end

---------------------------------------------------------------------------
-- The list: the alts above the offline Battle.net friends
---------------------------------------------------------------------------
local function OfflineBNet(id)
  if not (C_BattleNet and C_BattleNet.GetFriendAccountInfo) then return false end
  local ok, info = pcall(C_BattleNet.GetFriendAccountInfo, id)
  if not ok or type(info) ~= "table" or info.isFavorite then return false end
  local game = info.gameAccountInfo
  return not (game and game.isOnline)
end

-- One the game lists itself (a character friend of another account): left where the game puts it.
local function GameFriend(name)
  if not (C_FriendList and C_FriendList.GetFriendInfo) then return false end
  local ok, info = pcall(C_FriendList.GetFriendInfo, name)
  return ok and type(info) == "table"
end

function AltFriends.AddToList()
  local frame = FriendsListFrame
  local box = frame and frame.ScrollBox
  if not (box and box.GetDataProvider and frame:IsShown()) then return 0 end
  local data = box:GetDataProvider()
  if not data then return 0 end
  local alts = {}
  for _, alt in ipairs(Sorted()) do
    if not GameFriend(alt.name) then alts[#alts + 1] = alt end
  end
  if #alts == 0 then return 0 end
  local BNET, DIVIDER = FRIENDS_BUTTON_TYPE_BNET, FRIENDS_BUTTON_TYPE_DIVIDER
  local size = data:GetSize()
  local at
  for i = 1, size do
    local entry = data:Find(i)
    if entry and entry.buttonType == BNET and OfflineBNet(entry.id) then at = i break end
  end
  local block = {}
  if not at then
    local last = size > 0 and data:Find(size)
    if last and last.buttonType ~= DIVIDER then block[#block + 1] = { buttonType = DIVIDER } end
    at = size + 1
  end
  for i, alt in ipairs(alts) do block[#block + 1] = { id = i, buttonType = TYPE, alt = alt } end
  if at <= size then block[#block + 1] = { buttonType = DIVIDER } end -- (then the offline Battle.net friends)
  for k, entry in ipairs(block) do data:InsertAtIndex(entry, at + k - 1) end
  return #alts
end

function AltFriends.Refresh()
  -- (not forced: the game keeps where the list is scrolled to)
  if FriendsListFrame and FriendsListFrame:IsShown() and FriendsList_Update then FriendsList_Update() end
  if AltFriends.SocialRefresh then AltFriends.SocialRefresh() end
end

---------------------------------------------------------------------------
-- A row: the game's friend row, drawn here; the mouse on a layer of ours (the game's own scripts read
-- its friends only)
---------------------------------------------------------------------------
local function Tip(catcher)
  local alt = catcher.alt
  if not alt then return end
  local facts = AltFriends.Facts(alt.name)
  GameTooltip:SetOwner(catcher, "ANCHOR_RIGHT")
  GameTooltip:SetText(ClassColored(alt.name, facts.class), 1, 0.82, 0)
  if facts.level and facts.class then
    GameTooltip:AddLine((FRIENDS_LEVEL_TEMPLATE or "Level %d %s"):format(facts.level, ClassName(facts.class, facts.sex)), 1, 1, 1)
  end
  if AltFriends.Online(alt.name) then
    GameTooltip:AddLine(facts.zone or L.ALT_ONLINE, 0.2, 1, 0.2)
  else
    GameTooltip:AddLine(Ago(facts.at) or FRIENDS_LIST_OFFLINE or "Offline", 0.6, 0.6, 0.6)
  end
  GameTooltip:AddLine(L.ALT_ROW_HINT, 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end

local function Menu(catcher)
  local alt = catcher.alt
  if not (alt and MenuUtil and MenuUtil.CreateContextMenu) then return end
  MenuUtil.CreateContextMenu(catcher, function(_, root)
    root:CreateTitle(alt.name)
    if not IsMe(alt.name) then
      root:CreateButton(WHISPER or "Whisper", function()
        local tell = (ChatFrameUtil and ChatFrameUtil.SendTell) or ChatFrame_SendTell
        if tell then tell(alt.name) end
      end)
      root:CreateButton(PARTY_INVITE or INVITE or "Invite", function()
        local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
        if invite then invite(alt.name) end
      end)
    end
    root:CreateButton(L.ALT_REMOVE, function() AltFriends.Remove(alt.name) end)
  end)
end

local function Catcher(button)
  local catcher = button.claraAlt
  if catcher then return catcher end
  catcher = CreateFrame("Button", nil, button)
  catcher:SetAllPoints(button)
  catcher:SetFrameLevel(button:GetFrameLevel() + 10)
  catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  catcher:SetScript("OnEnter", function(self)
    if button.LockHighlight then button:LockHighlight() end
    Tip(self)
  end)
  catcher:SetScript("OnLeave", function()
    if button.UnlockHighlight then button:UnlockHighlight() end
    GameTooltip:Hide()
  end)
  catcher:SetScript("OnClick", function(self, which) if which == "RightButton" then Menu(self) end end)
  button.claraAlt = catcher
  return catcher
end
AltFriends.Catcher = Catcher

local function Color(color, alpha)
  if type(color) == "table" and color.GetRGBA then return color:GetRGBA() end
  return 0.588, 0.588, 0.588, alpha or 0.05
end

function AltFriends.DrawRow(button, entry)
  if not button then return end
  local alt = entry and entry.buttonType == TYPE and entry.alt
  if not alt then
    if button.claraAlt then button.claraAlt:Hide(); button.claraAlt.alt = nil end
    return
  end
  local online = AltFriends.Online(alt.name)
  local facts = AltFriends.Facts(alt.name)
  local nameText, info = alt.name, nil
  if online then
    if facts.level and facts.class then
      nameText = ClassColored(alt.name, facts.class) .. ", " .. (FRIENDS_LEVEL_TEMPLATE or "Level %d %s"):format(facts.level, ClassName(facts.class, facts.sex))
    end
    info = facts.zone or L.ALT_ONLINE
  else
    info = Ago(facts.at) or FRIENDS_LIST_OFFLINE or "Offline"
  end
  if button.background then
    button.background:SetColorTexture(Color(online and FRIENDS_WOW_BACKGROUND_COLOR or FRIENDS_OFFLINE_BACKGROUND_COLOR))
  end
  if button.status then
    button.status:SetTexture(online and (FRIENDS_TEXTURE_ONLINE or "Interface\\FriendsFrame\\StatusIcon-Online")
      or (FRIENDS_TEXTURE_OFFLINE or "Interface\\FriendsFrame\\StatusIcon-Offline"))
  end
  if button.name then
    button.name:SetText(nameText)
    local r, g, b = Color(online and FRIENDS_WOW_NAME_COLOR or FRIENDS_GRAY_COLOR)
    if not online and not FRIENDS_GRAY_COLOR then r, g, b = 0.486, 0.518, 0.541 end
    button.name:SetTextColor(r, g, b)
  end
  if button.info then button.info:SetText(info) end
  for _, key in ipairs({ "gameIcon", "travelPassButton", "summonButton", "Favorite" }) do
    if button[key] then button[key]:Hide() end
  end
  button:Show()
  local catcher = Catcher(button)
  catcher.alt = alt
  catcher:Show()
end

---------------------------------------------------------------------------
-- Hooks: the game's own list update and rows, the window shown
---------------------------------------------------------------------------
local hooked = false
local function Hook()
  if hooked or not FriendsFrame then return end
  hooked = true
  if FriendsList_Update then hooksecurefunc("FriendsList_Update", function() AltFriends.AddToList() end) end
  if FriendsFrame_UpdateFriendButton then
    hooksecurefunc("FriendsFrame_UpdateFriendButton", function(button, entry) AltFriends.DrawRow(button, entry) end)
  end
  FriendsFrame:HookScript("OnShow", function() AltFriends.LayFoot() end)
  if FriendsListFrame then FriendsListFrame:HookScript("OnShow", function() AltFriends.LayFoot() end) end
end
AltFriends.Hook = Hook

---------------------------------------------------------------------------
-- The game's new social window (WoW Forever's friends window when its server turns it on: the default UI's): the
-- characters in its friends list, in two sections of their own made as the game's own (a header, folded by a click
-- and kept so), "Characters online" and "Characters offline", on the game's cards. By default the ones online on top,
-- those offline after the Battle.net friends; the sections' order is the player's (see "The sections moved" below). Put in the list as the game builds
-- it, before it lays it out; what shows changing (a character online or gone, one added, a section moved) the list
-- is arranged again in place. The game's card-size cache, filled as it lays out our lines too, emptied after each
-- read (else the game would refuse its own friend search at its next refresh: an empty list). Each card drawn by the
-- game from what is known of the character; the mouse on a layer of ours (tooltip, right-click menu), the Battle.net
-- party and summon buttons hidden. The search box filters them too.
---------------------------------------------------------------------------
local HEADER_FAVORITES, HEADER_FRIENDS = 1, 2 -- (the game's FriendsListHeaderType: its two sections)
local SECTIONS = { "online", "favorites", "friends", "offline" } -- (all of them, in their first order: the ones online on top)
local OLD_FIRST = { "favorites", "friends", "online", "offline" } -- (the first order until 19 November: kept as it was, today's)
local BNET = { favorites = true, friends = true }
local OURS = { online = "claraOnline", offline = "claraOffline" } -- (our headers' types: the game keeps their fold)
local socialView
local socialNodes = { online = {}, offline = {} } -- (our cards in the list shown, per section, in order)
local socialFrames = {} -- (the cards drawn now with ours: frame -> node)
local arranged -- (the list last arranged here)

local function IndexOf(list, value)
  for i, v in ipairs(list) do if v == value then return i end end
  return nil
end

-- The sections' order and our sections' folds (ns.sv.friendSections, for the whole WoW account): each section once,
-- one unknown dropped, one missing put back at its first place
local function SectionStore()
  local sv = ns.sv
  if type(sv) ~= "table" then return nil end
  local store = sv.friendSections
  if type(store) ~= "table" then store = {}; sv.friendSections = store end
  local order = {}
  for _, key in ipairs(type(store.order) == "table" and store.order or {}) do
    if IndexOf(SECTIONS, key) and not IndexOf(order, key) then order[#order + 1] = key end
  end
  for i, key in ipairs(SECTIONS) do
    if not IndexOf(order, key) then table.insert(order, math.min(i, #order + 1), key) end
  end
  -- (the earlier first order, never changed: the characters online on top now, as the first order has them)
  if store.v ~= 2 then
    local same = #order == #OLD_FIRST
    for i, key in ipairs(OLD_FIRST) do same = same and order[i] == key end
    if same then order = { unpack(SECTIONS) } end
    store.v = 2
  end
  store.order = order
  if type(store.folded) ~= "table" then store.folded = {} end
  return store
end
AltFriends.SectionStore = SectionStore

-- What the game's card reads of a friend, for a character
local function SocialInfo(alt)
  local online = AltFriends.Online(alt.name)
  local facts = AltFriends.Facts(alt.name)
  -- All on the card's top line, as the 1.x list: "Name, Level 26 Priest", the name in its class color when online
  -- (the game wraps it in its own color: the class's, inside, shows); no character line (the name not twice); the
  -- zone or when last seen on the line under it
  local shown = alt.name
  if online then
    shown = ClassColored(alt.name, facts.class)
    if facts.level and facts.class then
      shown = shown .. ", " .. (FRIENDS_LEVEL_TEMPLATE or "Level %d %s"):format(facts.level, ClassName(facts.class, facts.sex))
    end
  end
  local character = nil
  local levels = Enum and Enum.BattleNetFriendLevel
  local raf = Enum and Enum.RafLinkType
  return {
    accountName = shown, battleTag = "", note = "", friendTags = {}, isFavorite = false, isAFK = false,
    isDND = false, customMessage = "", customMessageTime = 0, rafLinkType = raf and raf.None or 0,
    friendLevel = levels and levels.Title, lastOnlineTime = (not online and facts.at) or 0,
    gameAccountInfo = {
      isOnline = online, characterName = character, characterLevel = facts.level,
      className = facts.class and ClassName(facts.class, facts.sex) or nil, classFilename = facts.class,
      areaName = online and (facts.zone or L.ALT_ONLINE) or nil, richPresence = facts.zone,
      clientProgram = online and (BNET_CLIENT_WOW or "WoW") or "", wowProjectID = WOW_PROJECT_ID,
      factionName = UnitFactionGroup("player"), realmID = 0, isInCurrentRegion = true,
      isGameAFK = false, isGameBusy = false,
    },
  }
end

local function SocialMatches(alt)
  local bar = socialView and socialView.FilterBar and socialView.FilterBar.SearchBar
  local ok, text = pcall(function() return bar and bar:GetText() end)
  if not ok or type(text) ~= "string" or issecretvalue(text) or text == "" then return true end
  return alt.name:lower():find(text:lower(), 1, true) ~= nil
end

-- The characters the list shows (the search box's), online and offline apart
local function SocialAlts()
  local online, offline = {}, {}
  for _, alt in ipairs(Sorted()) do
    if not GameFriend(alt.name) and SocialMatches(alt) then
      local list = AltFriends.Online(alt.name) and online or offline
      list[#list + 1] = alt
    end
  end
  return online, offline
end

-- A section of the list (a line at its top): its key; nil for any other line
local function SectionKey(node)
  local data = node and node.GetData and node:GetData()
  if type(data) ~= "table" or data.headerText == nil then return nil end
  if data.claraSection then return data.claraSection end
  if data.headerType == HEADER_FAVORITES then return "favorites" end
  if data.headerType == HEADER_FRIENDS then return "friends" end
  return nil
end

local function HeaderText(key, count)
  return (key == "online" and L.ALT_SECTION_ONLINE or L.ALT_SECTION_OFFLINE):format(count)
end

-- A line made apart (in a list of its own), then given to ours: the whole change shown at once
local function NewNode(provider, data)
  local made = CreateTreeDataProvider and CreateTreeDataProvider()
  if made then return made:Insert(data) end
  local node = provider:Insert(data)
  provider:GetRootNode():Remove(node, true)
  return node
end
local function Adopt(node, parent, provider)
  node.parent, node.dataProvider = parent, provider
  for _, child in ipairs(node.nodes or {}) do Adopt(child, node, provider) end
  return node
end

-- One of our sections: its header (folded as it was left), a spacer under it as the game's, its cards
local function NewSection(provider, root, key, alts)
  local section = NewNode(provider, { headerType = OURS[key], headerText = HeaderText(key, #alts), claraSection = key })
  local store = SectionStore()
  section.collapsed = store and store.folded[key] == true or nil
  section:Insert({ isSpacer = true })
  local cards = {}
  for i, alt in ipairs(alts) do cards[i] = section:Insert({ claraAlt = alt, accountInfo = SocialInfo(alt) }) end
  return Adopt(section, root, provider), cards
end

-- The list's sections in the player's order, ours made again, a spacer between two (as the game's); a list shown:
-- laid out again once
local function Arrange(provider)
  local root = provider and provider.GetRootNode and provider:GetRootNode()
  local nodes = root and root.GetNodes and root:GetNodes()
  local store = SectionStore()
  if type(nodes) ~= "table" or not store then return end
  local sections, others = {}, {}
  for _, node in ipairs(nodes) do
    local key = SectionKey(node)
    local data = node:GetData()
    if key then
      if BNET[key] then sections[key] = node end
    elseif not (type(data) == "table" and data.isSpacer) then
      others[#others + 1] = node -- (anything else of the game's: kept first, as it was)
    end
  end
  local online, offline = SocialAlts()
  socialNodes = { online = {}, offline = {} }
  if #online > 0 then sections.online, socialNodes.online = NewSection(provider, root, "online", online) end
  if #offline > 0 then sections.offline, socialNodes.offline = NewSection(provider, root, "offline", offline) end
  local lines = {}
  for _, node in ipairs(others) do lines[#lines + 1] = node end
  for _, key in ipairs(store.order) do
    local section = sections[key]
    if section then
      if #lines > 0 then lines[#lines + 1] = Adopt(NewNode(provider, { isSpacer = true }), root, provider) end
      lines[#lines + 1] = section
    end
  end
  for i = #nodes, 1, -1 do nodes[i] = nil end
  for i, node in ipairs(lines) do nodes[i] = node end
  arranged = provider
  if provider.Invalidate then provider:Invalidate() end
end

local function ShownProvider()
  local box = socialView and socialView.ScrollBox
  local provider = box and box.GetDataProvider and box:GetDataProvider()
  return provider ~= nil and provider == arranged and provider or nil
end

-- A card of ours: the mouse layer on it, the Battle.net party and summon buttons hidden
local function DressCard(frame, alt)
  if frame.PartyButton then frame.PartyButton:Hide() end
  if frame.RAFSummonButton then frame.RAFSummonButton:Hide() end
  frame.claraAltHid = true
  local catcher = AltFriends.Catcher(frame)
  catcher.alt = alt
  catcher:Show()
end

-- Each card as the list draws it: ours dressed; a Battle.net friend's as the game made it (its party button back
-- when the card was ours before)
local function SocialCard(_, frame, node)
  local data = node and node.GetData and node:GetData()
  local alt = type(data) == "table" and data.claraAlt
  if not alt then
    socialFrames[frame] = nil
    if frame.claraAlt then frame.claraAlt:Hide(); frame.claraAlt.alt = nil end
    if frame.claraAltHid and frame.PartyButton then frame.PartyButton:Show() end
    frame.claraAltHid = nil
    return
  end
  socialFrames[frame] = node
  DressCard(frame, alt)
end

-- A card of ours drawn again in place (the same characters online and offline: no line put in or taken out)
local function Redraw(frame, node)
  local data = node:GetData()
  local alt = data.claraAlt
  local info = data.accountInfo
  local game = info and info.gameAccountInfo
  if not (alt and game) then return end
  local online = game.isOnline
  pcall(function()
    local nameColor = online and HIGHLIGHT_FONT_COLOR or FRIENDS_GRAY_COLOR
    if frame.FriendName then
      frame.FriendName:SetText(nameColor and nameColor.WrapTextInColorCode and nameColor:WrapTextInColorCode(info.accountName) or info.accountName)
    end
    if frame.Location then
      local text = online and (game.areaName or "") or (FriendsListUtil and FriendsListUtil.GetLastOnlineText(info) or "")
      local color = online and FRIENDS_GRAY_COLOR or DARKGRAY_COLOR
      frame.Location:SetText(color and color.WrapTextInColorCode and color:WrapTextInColorCode(text) or text)
    end
    if frame.PresenceHolder and frame.PresenceHolder.SetPresence and SocialUIUtil then
      frame.PresenceHolder:SetPresence(SocialUIUtil.GetPresenceTypeForBattleNetAccountInfo(info))
    end
    if frame.Background then frame.Background:SetAtlas(online and "friends-card-default" or "friends-card-disabled", false) end
    if frame.GameIconHolder then
      if online and C_Texture and frame.GameIconHolder.Icon then
        C_Texture.SetTitleIconTexture(frame.GameIconHolder.Icon, BNET_CLIENT_WOW or "WoW", Enum.TitleIconVersion.Small)
      end
      frame.GameIconHolder:SetShown(online)
    end
  end)
  DressCard(frame, alt)
end

-- What changed, while the list shows: the same characters online and offline, their cards drawn again in place;
-- else the list arranged again (a character coming online goes to its section at once)
function AltFriends.SocialRefresh()
  if not (socialView and socialView:IsVisible()) then return end
  local provider = ShownProvider()
  if not provider then return end
  local online, offline = SocialAlts()
  local now = { online = online, offline = offline }
  for key, alts in pairs(now) do
    if #alts ~= #socialNodes[key] then return Arrange(provider) end
  end
  for key, alts in pairs(now) do
    for i, node in ipairs(socialNodes[key]) do
      local data = node:GetData()
      data.claraAlt, data.accountInfo = alts[i], SocialInfo(alts[i])
    end
  end
  for frame, node in pairs(socialFrames) do
    if frame:IsVisible() then Redraw(frame, node) end
  end
end

---------------------------------------------------------------------------
-- The sections moved: a padlock beside the window's X. Unlocked, each section (the Battle.net favorites and friends,
-- and ours) is dragged by its header to where it goes among the others, the list scrolling by itself as it is pushed
-- against its top or its bottom (faster the further past); the order is kept. Its right-click menu: the characters
-- online, or offline, above the Battle.net friends (else after them), the first order back. Locked again as the
-- window closes.
---------------------------------------------------------------------------
local LOCK = "Interface\\Buttons\\LockButton-"
local SCROLL_ZONE = 28                    -- the list scrolls with the cursor this near its top or bottom, or past them
local SCROLL_SLOW, SCROLL_FAST = 150, 1500 -- its speed in the list's units a second: at the zone's edge, pushed far
local unlocked = false
local lockButton, ghost, marker, driver
local grips = setmetatable({}, { __mode = "k" }) -- (a header's frame -> its grip)
local drag -- (the section dragged: { key =, shown =, slot = })

local function Click() if SOUNDKIT and PlaySound then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end end

-- The list's sections in their order, as it shows
local function ShownKeys()
  local provider = ShownProvider()
  local root = provider and provider:GetRootNode()
  local keys = {}
  for _, node in ipairs(root and root:GetNodes() or {}) do
    local key = SectionKey(node)
    if key then keys[#keys + 1] = key end
  end
  return keys
end

-- The order kept, after the sections shown were put in this order (those not shown left where they were)
local function KeepShownOrder(shown)
  local store = SectionStore()
  if not store then return end
  local out, n = {}, 0
  for _, key in ipairs(store.order) do
    if IndexOf(shown, key) then n = n + 1; out[#out + 1] = shown[n] else out[#out + 1] = key end
  end
  store.order = out
end

local function Rearrange()
  local provider = ShownProvider()
  if provider then Arrange(provider) end
end

-- Is this section of ours above the Battle.net friends? Put it there, or after them (online before offline)
local function Above(key)
  local store = SectionStore()
  if not store then return false end
  local order = store.order
  return IndexOf(order, key) < math.min(IndexOf(order, "favorites"), IndexOf(order, "friends"))
end
AltFriends.SectionAbove = Above
local function SetAbove(key, above)
  local store = SectionStore()
  if not store then return end
  local order = store.order
  table.remove(order, IndexOf(order, key))
  local first = math.min(IndexOf(order, "favorites"), IndexOf(order, "friends"))
  local last = math.max(IndexOf(order, "favorites"), IndexOf(order, "friends"))
  local other = IndexOf(order, key == "online" and "offline" or "online")
  local at
  if above then
    at = first
    if key == "online" and other < first then at = other end
  else
    at = last + 1
    if key == "offline" and other > last then at = other + 1 end
  end
  table.insert(order, at, key)
  Rearrange()
end
AltFriends.SetSectionAbove = SetAbove
local function ResetOrder()
  local store = SectionStore()
  if not store then return end
  store.order = { unpack(SECTIONS) }
  Rearrange()
end
AltFriends.ResetSectionOrder = ResetOrder

-- Raw screen units (the cursor's): a frame's top and bottom
local function Edges(frame)
  local top, bottom = frame:GetTop(), frame:GetBottom()
  if not (top and bottom) then return nil end
  local scale = frame:GetEffectiveScale()
  return top * scale, bottom * scale
end

-- Where the section dragged would go: after how many of the sections shown (0: first). The cursor over another
-- section (its header or its cards): before it when that one is above the dragged one, after it when below; over the
-- dragged one itself: where it is. Above all the lines in sight: before the first in sight (the list scrolls on up);
-- below them all: after the last. Each section's lines in sight kept (seen: key -> { top, bottom }) for the marker.
local function Slot(y, fromKey)
  local box = socialView.ScrollBox
  local shown, seen = ShownKeys(), {}
  local under, firstKey, firstTop, lastKey, lastBottom
  box:ForEachFrame(function(frame, node)
    local top, bottom = Edges(frame)
    if not top or not frame:IsVisible() then return nil end
    local key = SectionKey(node) or SectionKey(node and node.GetParent and node:GetParent())
    if not key then return nil end -- (a spacer between two sections)
    local at = seen[key]
    if at then at[1], at[2] = math.max(at[1], top), math.min(at[2], bottom) else seen[key] = { top, bottom } end
    if y <= top and y > bottom then under = key end
    if not firstTop or top > firstTop then firstTop, firstKey = top, key end
    if not lastBottom or bottom < lastBottom then lastBottom, lastKey = bottom, key end
    return nil
  end)
  local from = IndexOf(shown, fromKey or (drag and drag.key)) or 0
  local slot
  if under then
    local i = IndexOf(shown, under) or 0
    if i < from then slot = i - 1 elseif i > from then slot = i else slot = from end
  elseif firstTop and y > firstTop then
    slot = math.max(0, (IndexOf(shown, firstKey) or 1) - 1)
    if (IndexOf(shown, firstKey) or 1) > from and from > 0 then slot = from end
  elseif lastBottom and y <= lastBottom then
    slot = IndexOf(shown, lastKey) or #shown
    if slot < from then slot = from end
  else
    slot = drag and drag.slot or from -- (between two sections: as it was)
  end
  return slot, shown, seen
end
AltFriends.SectionSlot = Slot

-- The line where it would go: over the next section's first line in sight, else under the one before it, else at the
-- list's top or bottom
local function PlaceMarker(slot, shown, seen)
  local box = socialView.ScrollBox
  local top, bottom = Edges(box)
  local left, right = box:GetLeft(), box:GetRight()
  if not (top and left and right) then marker:Hide() return end
  local ui = UIParent:GetEffectiveScale()
  local boxScale = box:GetEffectiveScale()
  local next = shown[slot + 1] and seen[shown[slot + 1]]
  local previous = shown[slot] and seen[shown[slot]]
  local y
  if next then y = next[1] + 2 * boxScale
  elseif previous then y = previous[2] - 2 * boxScale
  elseif slot >= #shown then y = bottom
  else y = top end
  y = math.min(top, math.max(bottom, y))
  marker:ClearAllPoints()
  marker:SetPoint("LEFT", UIParent, "BOTTOMLEFT", (left * boxScale) / ui + 8, y / ui)
  marker:SetWidth((right - left) * boxScale / ui - 16)
  marker:Show()
end

-- The list scrolled with the cursor near its top or bottom, or pushed past them
local function AutoScroll(y, elapsed)
  local box = socialView.ScrollBox
  local top, bottom = Edges(box)
  if not top or not (box.GetDerivedScrollRange and box.ScrollToOffset) then return end
  local zone = SCROLL_ZONE * box:GetEffectiveScale()
  local push
  if y > top - zone then push = -(y - (top - zone)) elseif y < bottom + zone then push = (bottom + zone) - y end
  if not push then return end
  local range = box:GetDerivedScrollRange()
  if not range or range <= 0 then return end
  local depth = math.min(1, math.abs(push) / (zone * 4))
  local speed = SCROLL_SLOW + (SCROLL_FAST - SCROLL_SLOW) * depth
  local offset = box:GetDerivedScrollOffset() + (push < 0 and -1 or 1) * speed * elapsed
  box:ScrollToOffset(math.max(0, math.min(range, offset)), true)
end

local function StopDrag()
  drag = nil
  if ghost then ghost:Hide() end
  if marker then marker:Hide() end
end

-- Dropped: the section taken out of the order shown and put back where it was let go
local function Drop()
  local d = drag
  StopDrag()
  if not (d and d.slot and d.shown) then return end
  local from = IndexOf(d.shown, d.key)
  if not from then return end
  local order = { unpack(d.shown) }
  table.remove(order, from)
  table.insert(order, d.slot >= from and d.slot or d.slot + 1, d.key)
  KeepShownOrder(order)
  Rearrange()
  Click()
end
AltFriends.DropSection = function(key, slot) drag = { key = key, shown = ShownKeys(), slot = slot }; Drop() end

-- A section a place up (-1) or down (1) among those shown
function AltFriends.MoveSection(key, step)
  local shown = ShownKeys()
  local from = IndexOf(shown, key)
  local to = from and from + step
  if not (to and to >= 1 and to <= #shown) then return end
  shown[from], shown[to] = shown[to], shown[from]
  KeepShownOrder(shown)
  Rearrange()
  Click()
end

local function DragStep(_, elapsed)
  if not drag then return end
  if not IsMouseButtonDown("LeftButton") then return Drop() end
  if not (socialView and socialView:IsVisible()) then return StopDrag() end
  local x, y = GetCursorPosition()
  local ui = UIParent:GetEffectiveScale()
  ghost:ClearAllPoints()
  ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / ui, y / ui)
  AutoScroll(y, elapsed or 0)
  local slot, shown, seen = Slot(y)
  drag.slot, drag.shown = slot, shown
  PlaceMarker(slot, shown, seen)
end

local function StartDrag(key, header)
  if drag or not key then return end
  if not ghost then
    ghost = CreateFrame("Frame", nil, UIParent)
    ghost:SetFrameStrata("TOOLTIP")
    local fill = ghost:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.08, 0.06, 0.02, 0.85)
    -- (a gold edge: top, bottom, left, right)
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", false }, { "BOTTOMLEFT", "BOTTOMRIGHT", false },
      { "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true } }) do
      local edge = ghost:CreateTexture(nil, "BORDER")
      edge:SetColorTexture(1, 0.82, 0, 0.9)
      edge:SetPoint(side[1])
      edge:SetPoint(side[2])
      if side[3] then edge:SetWidth(1) else edge:SetHeight(1) end
    end
    ghost.text = ghost:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    ghost.text:SetPoint("LEFT", 8, 0)
    ghost.text:SetPoint("RIGHT", -8, 0)
    ghost.text:SetJustifyH("LEFT")
    marker = CreateFrame("Frame", nil, UIParent)
    marker:SetFrameStrata("TOOLTIP")
    marker:SetHeight(3)
    local line = marker:CreateTexture(nil, "ARTWORK")
    line:SetAllPoints()
    line:SetColorTexture(1, 0.82, 0, 1)
    marker:Hide()
  end
  local ui = UIParent:GetEffectiveScale()
  local scale = header:GetEffectiveScale() / ui
  ghost:SetSize((header:GetWidth() or 300) * scale, (header:GetHeight() or 24) * scale)
  ghost.text:SetText(header.ButtonText and header.ButtonText:GetText() or key)
  drag = { key = key }
  GameTooltip:Hide()
  ghost:Show()
  Click()
  DragStep(nil, 0)
end

-- The grip over a header (shown while unlocked): the whole header, a move sign before its fold button
local function Grip(frame)
  local grip = grips[frame]
  if grip then return grip end
  grip = CreateFrame("Button", nil, frame)
  grip:SetAllPoints(frame)
  local glow = grip:CreateTexture(nil, "HIGHLIGHT")
  glow:SetAllPoints()
  glow:SetColorTexture(1, 0.82, 0, 0.12)
  local sign = grip:CreateTexture(nil, "OVERLAY")
  sign:SetSize(16, 16)
  sign:SetTexture("Interface\\Cursor\\UI-Cursor-Move")
  if frame.CollapseButton then sign:SetPoint("RIGHT", frame.CollapseButton, "LEFT", -4, 0) else sign:SetPoint("RIGHT", -30, 0) end
  grip:SetScript("OnMouseDown", function(self, button) if button == "LeftButton" then StartDrag(self.key, frame) end end)
  -- (up and down a place without dragging: two arrows before the move sign)
  for i, step in ipairs({ -1, 1 }) do
    local arrow = CreateFrame("Button", nil, grip)
    arrow:SetSize(16, 16)
    local face = step < 0 and "Interface\\Buttons\\Arrow-Up-" or "Interface\\Buttons\\Arrow-Down-"
    arrow:SetNormalTexture(face .. "Up")
    arrow:SetPushedTexture(face .. "Down")
    arrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    arrow:SetPoint("RIGHT", sign, "LEFT", -2 - (2 - i) * 16, step < 0 and 2 or -2)
    arrow:SetScript("OnClick", function() AltFriends.MoveSection(grip.key, step) end)
    arrow:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(step < 0 and L.ALT_MOVE_UP or L.ALT_MOVE_DOWN, 1, 1, 1)
      GameTooltip:Show()
    end)
    arrow:SetScript("OnLeave", function() GameTooltip:Hide() end)
    grip[step < 0 and "up" or "down"] = arrow
  end
  grip:SetScript("OnEnter", function(self)
    if drag then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.ALT_DRAG_TIP, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
  grips[frame] = grip
  return grip
end
function AltFriends.SectionGrip(frame) return grips[frame] end

-- The grips on the headers in sight, while unlocked
local function SyncGrips()
  local box = socialView and socialView.ScrollBox
  local on = {}
  if unlocked and box and box:IsVisible() and box.ForEachFrame then
    box:ForEachFrame(function(frame, node)
      local key = SectionKey(node)
      if key then
        local grip = Grip(frame)
        grip.key = key
        grip:SetFrameLevel(frame:GetFrameLevel() + 10)
        grip:Show()
        on[frame] = true
      end
      return nil
    end)
  end
  for frame, grip in pairs(grips) do
    if not on[frame] then grip:Hide() end
  end
end
AltFriends.SyncSectionGrips = SyncGrips

local function LockLook()
  if not lockButton then return end
  local state = unlocked and "Unlocked-" or "Locked-"
  lockButton:SetNormalTexture(LOCK .. state .. "Up")
  lockButton:SetPushedTexture(LOCK .. state .. "Down")
end

local function SetUnlocked(on)
  unlocked = on and true or false
  if not unlocked then StopDrag() end
  LockLook()
  SyncGrips()
  if driver then driver:SetShown(unlocked) end
end
AltFriends.SetSectionsUnlocked = SetUnlocked
function AltFriends.SectionsUnlocked() return unlocked end

local function LockTip(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(L.ALT_LOCK_TITLE, 1, 1, 1)
  GameTooltip:AddLine(unlocked and L.ALT_UNLOCKED_TIP or L.ALT_LOCKED_TIP, nil, nil, nil, true)
  GameTooltip:Show()
end

-- The sections' options: in the padlock's right-click menu, and in the friends window's own menu (its ≡ button)
local function SectionEntries(root)
  root:CreateTitle(L.ALT_LOCK_TITLE)
  root:CreateCheckbox(L.ALT_OPT_ONLINE_TOP, function() return Above("online") end,
    function() SetAbove("online", not Above("online")) end)
  root:CreateCheckbox(L.ALT_OPT_OFFLINE_TOP, function() return Above("offline") end,
    function() SetAbove("offline", not Above("offline")) end)
  root:CreateButton(unlocked and L.ALT_LOCK or L.ALT_UNLOCK, function() SetUnlocked(not unlocked) end)
  root:CreateButton(L.ALT_OPT_RESET, ResetOrder)
end
AltFriends.SectionEntries = SectionEntries

local function OptionsMenu(owner)
  if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
  MenuUtil.CreateContextMenu(owner, function(_, root) SectionEntries(root) end)
end

-- The padlock, on the friends page (shown with it), beside the window's X
local function MakeLock()
  local close = SocialUIFrame and SocialUIFrame.CloseButton
  if lockButton or not (socialView and close) then return end
  local lock = CreateFrame("Button", nil, socialView)
  local w, h = close:GetSize()
  lock:SetSize(w and w > 0 and w or 24, h and h > 0 and h or 24)
  lock:SetPoint("RIGHT", close, "LEFT", 0, 0)
  lock:SetFrameStrata(close:GetFrameStrata())
  lock:SetFrameLevel(close:GetFrameLevel() + 1)
  lock:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  lock:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  lock:SetScript("OnClick", function(self, button)
    if button == "RightButton" then OptionsMenu(self) return end
    Click()
    SetUnlocked(not unlocked)
    LockTip(self)
  end)
  lock:SetScript("OnEnter", LockTip)
  lock:SetScript("OnLeave", function() GameTooltip:Hide() end)
  lockButton = lock
  AltFriends.lockButton = lock
  LockLook()
  -- (the grips follow the headers as the list scrolls; the dragged section follows the cursor)
  driver = CreateFrame("Frame", nil, socialView)
  driver:Hide()
  local since = 0
  driver:SetScript("OnUpdate", function(_, elapsed)
    if drag then DragStep(nil, elapsed) end
    since = since + elapsed
    if since >= 0.05 then since = 0; SyncGrips() end
  end)
  socialView:HookScript("OnHide", function() SetUnlocked(false) end)
end

function AltFriends.HookSocial()
  if socialView then return true end
  local view = SocialUIFrame and SocialUIFrame.FriendsList
  if not (view and view.InsertFriendsIntoDataProvider and FriendsListSocialCardMixin) then return false end
  socialView = view
  -- (in the list the game builds, before it lays it out: our sections in it, all in the player's order)
  hooksecurefunc(view, "InsertFriendsIntoDataProvider", function(_, provider) Arrange(provider) end)
  -- (our sections' fold, as the game keeps it for its own: kept here too, for the next times)
  if type(view.SaveHeaderCollapsedState) == "function" then
    hooksecurefunc(view, "SaveHeaderCollapsedState", function(_, headerType, collapsed)
      local store = SectionStore()
      if not store then return end
      for key, kind in pairs(OURS) do
        if kind == headerType then store.folded[key] = collapsed and true or nil end
      end
    end)
  end
  -- The game's card-size cache: the game fills it as it lays the list out, a pass that has read our lines (an
  -- addon's) first, so each size is put in it in the addon's name; at its next refresh the game empties it just
  -- before its friend search, and a size of ours found there then has the search refused: the list empty (black,
  -- every other time the window opened) or scrolled back up (a Battle.net friend's news). Taken out again as soon as
  -- the game has read it: the game works each size out again when it needs it (cheaply), and finds nothing of ours
  -- in it when it empties it.
  if type(view.GetTemplateExtent) == "function" and type(view.TemplateExtentCache) == "table" then
    hooksecurefunc(view, "GetTemplateExtent", function(self, name)
      local cache = self.TemplateExtentCache
      if type(cache) == "table" and name ~= nil then cache[name] = nil end
    end)
  end
  -- (each card as the game draws it: after its own drawing, ours dressed; the cards are made after this, from the
  -- game's card with this hook in it)
  hooksecurefunc(FriendsListSocialCardMixin, "Initialize", function(frame, node) SocialCard(nil, frame, node) end)
  MakeLock()
  local menus = _G.Menu -- (the game's menus: "Menu" here is the cards' own right-click menu)
  if type(menus) == "table" and menus.ModifyMenu then
    menus.ModifyMenu("MENU_SOCIAL_UI_BATTLE_NET_BAR", function(_, root)
      root:CreateDivider()
      SectionEntries(root)
    end)
  end
  return true
end

---------------------------------------------------------------------------
-- Coming and going: said in the chat as the game says it of a friend, the list redrawn
---------------------------------------------------------------------------
local wasOnline = {} -- lower-case whole name -> online when last looked
local settled = false -- (the first moments after login: the ones already online heard, not announced)
local function Announce(alt, online)
  local frame = DEFAULT_CHAT_FRAME
  if not (frame and frame.AddMessage) then return end
  local info = ChatTypeInfo and ChatTypeInfo.SYSTEM
  local r, g, b = info and info.r or 1, info and info.g or 1, info and info.b or 0
  local text
  if online then
    text = (ERR_FRIEND_ONLINE_SS or "|Hplayer:%s|h[%s]|h has come online."):format(alt.name, alt.name)
  else
    text = (ERR_FRIEND_OFFLINE_S or "%s has gone offline."):format(alt.name)
  end
  frame:AddMessage(text, r, g, b)
end
local function Look(announce)
  MendKnown()
  local changed = false
  for key, alt in pairs(List() or {}) do
    if not IsMe(alt.name) and AltFriends.Known(alt.name) then
      local on = AltFriends.Online(alt.name) and true or false
      if wasOnline[key] ~= nil and wasOnline[key] ~= on then
        changed = true
        if announce and settled then Announce(alt, on) end
      end
      wasOnline[key] = on
    end
  end
  if changed then AltFriends.Refresh() end
end
AltFriends.Look = Look

---------------------------------------------------------------------------
-- Online or not, for any character. Clara asks the server, one character a second (each one every 10 seconds,
-- every 3 while the friends list is open, at once as it opens), with an addon message whispered to it, which its
-- player never sees: offline (or unknown, or of the other faction) the server answers "No player named ... is
-- currently playing" (that line hidden from the chat when it answers one of our questions, however late); online it
-- says nothing for 2 seconds (longer while the server is slow: its answers' delay learned as they come); a late
-- answer still says offline, and is still hidden. A character heard in the chat by its whole name is online at once. Between two Clara that have
-- each other in their lists it is at once both ways: the question is a hello (asked of everyone at login, the first
-- 8 at once), the answer comes with its level, class and zone, and a goodbye goes at logout (not at a reload). Not
-- asked, never online (one character at a time per WoW account): the character played now, this account's other
-- characters, and another account's while one of its characters is surely online (Elsewhere, above). One of the
-- player's other accounts the sync hears too: the newer word counts (the sync's arrival waits for its channel, 15 to
-- 30 seconds after a login; the server's answer does not).
---------------------------------------------------------------------------
local PROBE_PREFIX = "ClaraFriends"
local PROBE_EVERY = 1     -- seconds between two questions
local PROBE_ROUND = 10    -- seconds at least between two questions to the same character
local PROBE_ROUND_OPEN = 3 -- the same while the friends list is open
local PROBE_WAIT = 2      -- seconds without the server's "no player named": online (longer while the server is slow)
local PROBE_WAIT_MAX = 20 -- the most it waits (a server very slow to answer)
local PROBE_BURST = 8     -- questions asked at once at login, goodbyes said at once at logout
local PROBE_HIDE = 30     -- seconds the server's answer to a question is still taken for it (hidden, offline)
local PROBE_SETTLE = 3    -- seconds after the world shows before asking (answers held in a loading screen came late)
local pausedUntil = math.huge -- (no question before the world shows)
local REPLY_EVERY = 2     -- seconds at least between two answers to the same asker (its hello answered at once)
local replied = {}        -- Key(name) -> when answered last
local slowest = 0         -- seconds: the server's slowest recent answer (forgotten little by little)
local loads = 0           -- loading screens since login (an answer held in one tells nothing of the server's pace)
local lastAsked = 0

-- The list's character a name points to: by its whole name; a first name alone (no surname heard), the one
-- character of the list with that first name
local function Listed(key)
  local byFirst, count = nil, 0
  for _, alt in pairs(List() or {}) do
    local own = Key(alt.name)
    if own == key then return alt, own end
    if not key:find(" ", 1, true) and GameName(own) == key then byFirst, count = alt, count + 1 end
  end
  if count == 1 then return byFirst, Key(byFirst.name) end
end

-- The name as the game writes it, from a name heard whole (its sender's): "Melbeline moon" typed, "Melbeline Moon" heard
local function Respell(alt, heard)
  if issecretvalue(heard) or type(heard) ~= "string" then return end
  local proper = ((heard:match("^([^%-]+)") or heard):gsub("^%s+", ""):gsub("%s+$", ""))
  if proper ~= alt.name and proper:lower() == alt.name:lower() then
    alt.name = proper
    AltFriends.Refresh()
  end
end

local function SetVerdict(key, online, heard)
  local p = probes[key] or {}
  probes[key] = p
  p.sent = nil
  if heard then p.asked = nil end -- (heard from: its questions answered, none left for a late "no player named")
  local changed = p.verdict ~= online
  p.verdict, p.at = online, GetTime()
  if not online then p.heardAt = nil elseif heard then p.heardAt = p.at end -- (surely online: for its account's others)
  local alt = Listed(key)
  if online and alt and time then alt.seen = time() end
  if changed then Look(true) end
end
AltFriends.SetVerdict = SetVerdict

local function Whisper(to, text)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false end
  local ok, result = pcall(C_ChatInfo.SendAddonMessage, PROBE_PREFIX, text, "WHISPER", to)
  if not ok then return false end
  local codes = Enum and Enum.SendAddonMessageResult
  if result == 12 or (codes and codes.TargetOffline ~= nil and result == codes.TargetOffline) then return false, true end
  local success = codes and codes.Success
  return result == nil or result == true or result == 0 or (success ~= nil and result == success)
end

local function ListOpen()
  return (FriendsFrame ~= nil and FriendsFrame:IsVisible()) or (SocialUIFrame ~= nil and SocialUIFrame:IsVisible()) or false
end

-- One question to one character; false when the game refused to send it now (throttled: asked again later)
local function AskOne(alt, now)
  local key = Key(alt.name)
  local p = probes[key] or {}
  probes[key] = p
  local sent, offline = Whisper(alt.name, "?")
  if sent then
    p.tried, p.sent = now, now
    -- (each question kept a while: its answer, however late, is ours)
    p.asked = p.asked or {}
    p.asked[#p.asked + 1] = { at = now, load = loads }
  elseif offline then -- (the game said so at once)
    p.tried = now
    SetVerdict(key, false)
  else
    return false
  end
  return true
end

-- The characters to ask, the longest unasked first
local function Due(now, round)
  local due = {}
  for _, alt in pairs(List() or {}) do
    if not IsMe(alt.name) and not Elsewhere(alt.name) then
      local p = probes[Key(alt.name)]
      local last = p and p.tried or 0
      if not (p and p.sent) and now - last >= round then due[#due + 1] = { alt = alt, last = last } end
    end
  end
  -- (the ones with Clara first: their hello and answer are the fast ones)
  table.sort(due, function(a, b)
    if (a.alt.clara and true or false) ~= (b.alt.clara and true or false) then return a.alt.clara == true end
    return a.last < b.last
  end)
  return due
end

-- How long a question waits for the server's answer: 2 seconds, longer while the server is slow (its slowest recent
-- answer, and the game's own latency)
local function Wait()
  local wait = PROBE_WAIT
  if slowest > 0 then wait = math.max(wait, slowest * 1.5 + 1) end
  if GetNetStats then
    local ok, _, _, home, world = pcall(GetNetStats)
    local ms = ok and math.max(tonumber(home) or 0, tonumber(world) or 0) or 0
    if ms > 0 then wait = math.max(wait, ms * 3 / 1000 + 1) end
  end
  return math.min(wait, PROBE_WAIT_MAX)
end
AltFriends.Wait = Wait -- (for the tests)

local lastTick
local function AskServer()
  local now = GetTime()
  -- (the server's pace forgotten little by little: half of it in two minutes)
  if lastTick and now > lastTick and slowest > 0 then slowest = slowest * 0.5 ^ ((now - lastTick) / 120) end
  lastTick = now
  local wait = Wait()
  for key, p in pairs(probes) do
    -- (questions too old for an answer: let go)
    local asked = p.asked
    while asked and asked[1] and now - asked[1].at > PROBE_HIDE do table.remove(asked, 1) end
    if p.sent and now - p.sent >= wait then SetVerdict(key, true) end -- (unanswered: online)
  end
  if now - lastAsked < PROBE_EVERY or now < pausedUntil then return end
  local due = Due(now, ListOpen() and PROBE_ROUND_OPEN or PROBE_ROUND)
  if due[1] then
    if AskOne(due[1].alt, now) then lastAsked = now else lastAsked = now + 2 end -- (refused: a short pause)
  end
end

-- Everyone asked again at once (login, the friends list opened): the first PROBE_BURST now, the rest a second each
local function AskAll()
  local now = GetTime()
  for _, p in pairs(probes) do if not p.sent then p.tried = 0 end end
  for i, entry in ipairs(Due(now, 0)) do
    if i > PROBE_BURST or not AskOne(entry.alt, now) then break end
  end
  lastAsked = now
end
AltFriends.AskAll = AskAll

-- The ones known to have Clara greeted the moment the world shows (their Clara shows this character online at once,
-- and answers at once): the rest are asked a moment later, when the server's answers come in time
local function HelloClara()
  local now, n = GetTime(), 0
  for _, alt in pairs(List() or {}) do
    if n >= PROBE_BURST then break end
    if alt.clara and not IsMe(alt.name) and not Elsewhere(alt.name) then
      local p = probes[Key(alt.name)]
      if not (p and p.sent) and AskOne(alt, now) then n = n + 1 end
    end
  end
end
AltFriends.HelloClara = HelloClara

-- At logout, a goodbye to the ones online (their Clara shows this character offline at once); not at a reload
local reloading = false
local function Goodbye()
  if reloading then return end
  local n = 0
  for _, alt in pairs(List() or {}) do
    if n >= PROBE_BURST then break end
    if alt.clara and not IsMe(alt.name) and AltFriends.Online(alt.name) then -- (only a Clara hears it)
      Whisper(alt.name, "!")
      n = n + 1
    end
  end
end
AltFriends.AskServer = AskServer -- (not AltFriends.Ask: Add Character's dialog)

-- The name in the server's "No player named '%s' is currently playing", as Key gives it
local notFound
local function NotFoundName(text)
  if issecretvalue(text) or type(text) ~= "string" or type(ERR_CHAT_PLAYER_NOT_FOUND_S) ~= "string" then return nil end
  if not notFound then
    local escaped = ERR_CHAT_PLAYER_NOT_FOUND_S:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    notFound = "^" .. escaped:gsub("%%%%s", "(.+)") .. "$"
  end
  local name = text:match(notFound)
  return name and Key(name)
end

-- A "No player named" line, taken once whoever sees it first (Clara's events, each chat window's filter): the name
-- in it, and whether it answers one of our questions (the oldest still waiting for that name; hidden). Its delay
-- teaches the server's pace (counted from the newest question: a question to one online is never answered).
local lastLine, lastText, lastAt, lastKey, lastOurs
local function TakeAnswer(text, line)
  if issecretvalue(text) or type(text) ~= "string" then return nil, false end
  local now = GetTime()
  local byLine = type(line) == "number" and not issecretvalue(line) and line > 0
  if (byLine and line == lastLine) or (not byLine and text == lastText and now == lastAt) then return lastKey, lastOurs end
  local key = NotFoundName(text)
  local ours = false
  local p = key and probes[key]
  local asked = p and p.asked
  while asked and asked[1] and now - asked[1].at > PROBE_HIDE do table.remove(asked, 1) end
  if asked and asked[1] then
    local newest = asked[#asked]
    if newest.load == loads then slowest = math.max(slowest, now - newest.at) end
    table.remove(asked, 1)
    ours = true
  end
  lastLine, lastText, lastAt, lastKey, lastOurs = byLine and line or nil, text, now, key, ours
  return key, ours
end

local function HideOurs(_, _, text, ...)
  local _, ours = TakeAnswer(text, (select(10, ...)))
  return ours
end

local function Answer(sender)
  local level = UnitLevel and UnitLevel("player") or 0
  local _, class = UnitClass("player")
  local zone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
  if issecretvalue(zone) or type(zone) ~= "string" then zone = "" end
  Whisper(sender, ("I|%d|%s|%s"):format(tonumber(level) or 0, class or "", (zone:gsub("|", ""))))
  local sex = UnitSex and UnitSex("player")
  if sex == 2 or sex == 3 then Whisper(sender, "S|" .. sex) end
end

-- A unit's whole name ("First Surname"), as the game's own names give it
local function WholeName(unit)
  local ok, name, surname = pcall(function()
    if UnitNameUnmodified then return UnitNameUnmodified(unit) end
    return UnitName(unit)
  end)
  if not ok or issecretvalue(name) or type(name) ~= "string" or name == "" then return nil end
  local consts = Constants and Constants.CharacterNameSeparatorConsts
  local sep = consts and consts.CHARACTERNAME_SURNAME_SEPARATOR
  if type(sep) == "string" and not issecretvalue(surname) and type(surname) == "string" and surname ~= ""
    and not name:find(sep, 1, true) then
    return name .. sep .. surname
  end
  return name
end

-- Its class (and level) from the game, for one seen or heard: its class color even without an addon of its own
local function KeepClass(alt, class, level)
  if issecretvalue(class) or issecretvalue(level) then return end
  local changed = false
  if type(class) == "string" and class ~= "" and alt.class ~= class then alt.class, changed = class, true end
  level = tonumber(level)
  if level and level > 0 and alt.level ~= level then alt.level, alt.levelAt, changed = level, time and time() or nil, true end
  if changed then AltFriends.Refresh() end
end

local function KeepSex(alt, own, sex)
  if sex ~= 2 and sex ~= 3 then return end
  local sexes = Sexes()
  if sexes then sexes[own] = sex end
  if alt and alt.sex ~= sex then
    alt.sex = sex
    AltFriends.Refresh()
  end
end

-- One seen (target, under the mouse, in the group): its sex, the game's
local function NoteUnit(unit)
  local ok, player = pcall(UnitIsPlayer, unit)
  if not ok or issecretvalue(player) or not player then return end
  local name = WholeName(unit)
  if not name then return end
  AltFriends.Mend(name)
  local alt, own = Listed(Key(name))
  if not alt then return end
  local okSex, sex = pcall(UnitSex, unit)
  if okSex and not issecretvalue(sex) then KeepSex(alt, own, sex) end
  local okClass, _, class = pcall(UnitClass, unit)
  local okLevel, level = pcall(UnitLevel, unit)
  KeepClass(alt, okClass and class or nil, okLevel and level or nil)
end

local CHAT_PRESENCE = { "CHAT_MSG_WHISPER", "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE",
  "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER" }

local probeEvents = CreateFrame("Frame")
probeEvents:SetScript("OnEvent", function(_, event, a1, a2, a3, a4, ...)
  if event == "PLAYER_LOGOUT" then
    Goodbye()
  elseif event == "PLAYER_ENTERING_WORLD" then
    -- A loading screen held the answers: the questions then unanswered are asked again, a moment after the world
    -- shows (everyone at once after a login or reload), not taken for online.
    for _, p in pairs(probes) do p.sent = nil end
    loads = loads + 1
    pausedUntil = GetTime() + PROBE_SETTLE
    if a1 or a2 then
      HelloClara()
      C_Timer.After(PROBE_SETTLE, AskAll)
    end
  elseif event == "CHAT_MSG_SYSTEM" then
    local key = TakeAnswer(a1, (select(7, ...)))
    if not key then return end
    local alt, own = Listed(key)
    if alt then SetVerdict(own, false) end
  elseif event == "CHAT_MSG_ADDON" then
    local prefix, text, channel, sender = a1, a2, a3, a4
    if prefix ~= PROBE_PREFIX or channel ~= "WHISPER" then return end
    if issecretvalue(text) or issecretvalue(sender) or type(text) ~= "string" or type(sender) ~= "string" then return end
    AltFriends.Mend(sender)
    local alt, own = Listed(Key(sender))
    if not alt then
      -- A player not in this list asking: answered all the same (its level, class and zone are what /who tells
      -- anyone), so that a friend who has this one in their list sees it, even while it has not added them back
      if text == "?" then
        local key, now = Key(sender), GetTime()
        if key and not (replied[key] and now - replied[key] < REPLY_EVERY) then
          replied[key] = now
          Answer(sender)
        end
      end
      return
    end
    Respell(alt, sender)
    alt.clara = true -- (it has Clara: greeted first, told goodbye)
    if text == "!" then SetVerdict(own, false) return end -- (its goodbye)
    SetVerdict(own, true, true)
    if text == "?" then
      local now = GetTime()
      if replied[own] and now - replied[own] < REPLY_EVERY then return end
      replied[own] = now
      Answer(sender)
    else
      local level, class, zone = text:match("^I|(%d+)|(%u*)|(.*)$")
      if level then
        alt.level, alt.class, alt.zone = tonumber(level), class ~= "" and class or nil, zone ~= "" and zone or nil
        alt.levelAt = time and time() or nil
        AltFriends.Refresh()
      end
      local sex = tonumber(text:match("^S|(%d)$") or "")
      if sex then KeepSex(alt, own, sex) end
    end
  elseif event == "PLAYER_TARGET_CHANGED" then
    NoteUnit("target")
  elseif event == "UPDATE_MOUSEOVER_UNIT" then
    NoteUnit("mouseover")
  elseif event == "GROUP_ROSTER_UPDATE" then
    local raid = IsInRaid and IsInRaid()
    for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do NoteUnit((raid and "raid" or "party") .. i) end
  else -- heard in the chat: by its whole name only (a first name alone may be anyone's)
    if issecretvalue(a2) or type(a2) ~= "string" or a2 == "" then return end
    AltFriends.Mend(a2)
    local heard = Key(a2)
    local alt, own = Listed(heard)
    if alt and own == heard then
      Respell(alt, a2)
      SetVerdict(own, true, true)
      -- (its sex, from the game's word on its sender)
      local guid = select(8, ...)
      if type(guid) == "string" and not issecretvalue(guid) and GetPlayerInfoByGUID then
        local okInfo, _, class, _, _, sex = pcall(GetPlayerInfoByGUID, guid)
        if okInfo and not issecretvalue(sex) then KeepSex(alt, own, sex) end
        if okInfo then KeepClass(alt, class, nil) end
      end
    end
  end
end)

local probing = false
function AltFriends.StartProbes()
  if probing then return end
  probing = true
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PROBE_PREFIX) end
  probeEvents:RegisterEvent("CHAT_MSG_SYSTEM")
  probeEvents:RegisterEvent("CHAT_MSG_ADDON")
  for _, event in ipairs(CHAT_PRESENCE) do probeEvents:RegisterEvent(event) end
  local AddFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
  if AddFilter then AddFilter("CHAT_MSG_SYSTEM", HideOurs) end
  probeEvents:RegisterEvent("PLAYER_LOGOUT")
  if type(ReloadUI) == "function" then hooksecurefunc("ReloadUI", function() reloading = true end) end
  if C_UI and type(C_UI.Reload) == "function" then hooksecurefunc(C_UI, "Reload", function() reloading = true end) end
  if FriendsFrame and FriendsFrame.HookScript then
    FriendsFrame:HookScript("OnShow", function() if GetTime() >= pausedUntil then AskAll() end end)
  end
  if SocialUIFrame and SocialUIFrame.HookScript then
    SocialUIFrame:HookScript("OnShow", function() if GetTime() >= pausedUntil then AskAll() end end)
  end
  probeEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
  for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "GROUP_ROSTER_UPDATE" }) do probeEvents:RegisterEvent(event) end
  C_Timer.NewTicker(1, AskServer)
end

---------------------------------------------------------------------------
-- The zone in a character's tooltip over a frame (a party, raid or target frame, a list), as the 1.15 client shows a
-- group member away: from the group's roster (any group member), else from the character's own Clara (one of this
-- list, online). Not over the world (the character is right there, in the zone shown on the minimap).
---------------------------------------------------------------------------
local function FirstWord(name)
  if type(name) ~= "string" or issecretvalue(name) then return nil end
  return ((name:match("^([^%-]+)") or name):match("^(%S+)") or ""):lower()
end

local function RosterZone(unit)
  if not (GetNumGroupMembers and GetRaidRosterInfo) then return nil end
  local okName, name = pcall(UnitName, unit)
  local first = okName and FirstWord(name)
  if not first or first == "" then return nil end
  for i = 1, GetNumGroupMembers() do
    local ok, rosterName, _, _, _, _, _, zone = pcall(GetRaidRosterInfo, i)
    if ok and FirstWord(rosterName) == first and type(zone) == "string" and not issecretvalue(zone) and zone ~= "" then
      return zone
    end
  end
end

local function ListedZone(unit)
  local okName, name, surname = pcall(UnitName, unit)
  if not okName or type(name) ~= "string" or issecretvalue(name) then return nil end
  local whole = name
  if type(surname) == "string" and not issecretvalue(surname) and surname ~= "" then whole = name .. " " .. surname end
  local alt = Listed(Key(whole))
  if alt and AltFriends.Online(alt.name) then return AltFriends.Facts(alt.name).zone end
end

local function HasLine(tooltip, text)
  local ok, lines = pcall(tooltip.NumLines, tooltip)
  if not ok or type(lines) ~= "number" then return true end
  for i = 1, lines do
    local fs = _G[tooltip:GetName() .. "TextLeft" .. i]
    local okText, line = pcall(function() return fs and fs:GetText() end)
    if not okText or issecretvalue(line) then return true end
    if line == text then return true end
  end
  return false
end

local function AddZone(tooltip)
  if tooltip ~= GameTooltip or not tooltip.GetOwner then return end
  local owner = tooltip:GetOwner()
  if owner == nil or owner == UIParent or owner == WorldFrame then return end
  local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
  if not ok or type(unit) ~= "string" or issecretvalue(unit) then return end
  local okPlayer, isPlayer = pcall(UnitIsPlayer, unit)
  if not okPlayer or not isPlayer or issecretvalue(isPlayer) or UnitIsUnit(unit, "player") then return end
  local zone = RosterZone(unit) or ListedZone(unit)
  if type(zone) ~= "string" or zone == "" or HasLine(tooltip, zone) then return end
  tooltip:AddLine(zone, 1, 1, 1)
  tooltip:Show()
end
-- (never in the way of the other addons' tooltip lines)
function AltFriends.AddZone(tooltip) pcall(AddZone, tooltip) end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  startedAt = GetTime()
  -- (this character's sex kept for the whole account: its other characters show its class's name as it is)
  local me, sexes = WholeName("player"), Sexes()
  if me and sexes and UnitSex then sexes[Key(me)] = UnitSex("player") end
  -- (this character kept as one of this WoW account's: never shown online while another of them plays)
  local mine = me and AccountChars()
  if mine then mine[Key(me)] = time and time() or true end
  List()
  Hook()
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip) AltFriends.AddZone(tooltip) end)
  end
  local dressed, social = AltFriends.DressAddFriend(), AltFriends.HookSocial()
  if not (dressed and social) then
    -- (the game's Add Friend window and its social window load with their friends windows: dressed as they come)
    local wait = CreateFrame("Frame")
    wait:RegisterEvent("ADDON_LOADED")
    wait:SetScript("OnEvent", function(waiter)
      dressed = dressed or AltFriends.DressAddFriend()
      social = social or AltFriends.HookSocial()
      if dressed and social then waiter:UnregisterAllEvents() end
    end)
  end
  Look(false)
  AltFriends.StartProbes()
  C_Timer.After(20, function() settled = true end)
  if ns.Sync and ns.Sync.OnPresence then ns.Sync.OnPresence(function() Look(true) end) end
  -- (one that left without a word: gone once not heard for a while)
  C_Timer.NewTicker(20, function() Look(true) end)
end)
