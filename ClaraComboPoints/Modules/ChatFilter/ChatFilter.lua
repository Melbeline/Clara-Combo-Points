-- Clara Combo Points - Chat blacklist: the chat lines holding a word or a phrase of its list hidden, from everyone but
-- you, your friends and the game's staff. A word added with "every variant" (on by default) hides it whatever its
-- accents, case, look-alike letters (Cyrillic or Greek ones in a Latin word, full-width letters), digits for letters
-- (0 o, 3 e, 4 a, 5 s, 7 t, 1 i, @ a, $ s) and symbols put inside it ("rested", "rêstéd", "reStEd", "r.e.s.t.e.d",
-- "r e s t e d", "r3$ted"); unticked, the word as written only. As a whole word by default ("rested" leaves
-- "interested" alone); "inside other words" ticked, anywhere. The raid symbols ({rt8}, {skull}, {crâne}...) count as
-- one: added with its buttons, a symbol matches every way of writing it.
-- Also, each with its box: the same message from the same player again within a minute (the copies hidden), the
-- lines in Cyrillic, the lines in Chinese. Public channels, say, yell and emotes always; whispers (on by default),
-- group, raid, guild and communities each with its own box.
-- Its window, from the button under the chat's channel button (right-click: the blacklist turned off or on): a box to
-- write in, the eight raid symbols to put in it, the list (each word with its box, its count of lines hidden, a click
-- to change it, its cross to take it out), the options, and the lines hidden lately (a click: the line to copy).
-- Saved for the account with Clara's settings (ClaraComboPointsDB.chatFilter).

local ADDON, ns = ...
local L = ns.L

local issecret = issecretvalue or function() return false end
local function Plain(v) return v ~= nil and not issecret(v) end

local FOLD = {
  ["À"]="a",["Á"]="a",["Â"]="a",["Ã"]="a",["Ä"]="a",["Å"]="a",["Æ"]="ae",["Ç"]="c",["È"]="e",["É"]="e",
  ["Ê"]="e",["Ë"]="e",["Ì"]="i",["Í"]="i",["Î"]="i",["Ï"]="i",["Ð"]="d",["Ñ"]="n",["Ò"]="o",["Ó"]="o",["Ô"]="o",
  ["Õ"]="o",["Ö"]="o",["Ø"]="o",["Ù"]="u",["Ú"]="u",["Û"]="u",["Ü"]="u",["Ý"]="y",["Þ"]="th",["ß"]="ss",
  ["à"]="a",["á"]="a",["â"]="a",["ã"]="a",["ä"]="a",["å"]="a",["æ"]="ae",["ç"]="c",["è"]="e",["é"]="e",
  ["ê"]="e",["ë"]="e",["ì"]="i",["í"]="i",["î"]="i",["ï"]="i",["ð"]="d",["ñ"]="n",["ò"]="o",["ó"]="o",["ô"]="o",
  ["õ"]="o",["ö"]="o",["ø"]="o",["ù"]="u",["ú"]="u",["û"]="u",["ü"]="u",["ý"]="y",["þ"]="th",["ÿ"]="y",
  ["Ā"]="a",["ā"]="a",["Ă"]="a",["ă"]="a",["Ą"]="a",["ą"]="a",["Ć"]="c",["ć"]="c",["Ĉ"]="c",["ĉ"]="c",["Ċ"]="c",
  ["ċ"]="c",["Č"]="c",["č"]="c",["Ď"]="d",["ď"]="d",["Đ"]="d",["đ"]="d",["Ē"]="e",["ē"]="e",["Ĕ"]="e",["ĕ"]="e",
  ["Ė"]="e",["ė"]="e",["Ę"]="e",["ę"]="e",["Ě"]="e",["ě"]="e",["Ĝ"]="g",["ĝ"]="g",["Ğ"]="g",["ğ"]="g",["Ġ"]="g",
  ["ġ"]="g",["Ģ"]="g",["ģ"]="g",["Ĥ"]="h",["ĥ"]="h",["Ĩ"]="i",["ĩ"]="i",["Ī"]="i",["ī"]="i",["Ĭ"]="i",["ĭ"]="i",
  ["Į"]="i",["į"]="i",["İ"]="i",["ı"]="i",["Ĵ"]="j",["ĵ"]="j",["Ķ"]="k",["ķ"]="k",["Ĺ"]="l",["ĺ"]="l",["Ļ"]="l",
  ["ļ"]="l",["Ľ"]="l",["ľ"]="l",["Ł"]="l",["ł"]="l",["Ń"]="n",["ń"]="n",["Ņ"]="n",["ņ"]="n",["Ň"]="n",["ň"]="n",
  ["Ō"]="o",["ō"]="o",["Ŏ"]="o",["ŏ"]="o",["Ő"]="o",["ő"]="o",["Œ"]="oe",["œ"]="oe",["Ŕ"]="r",["ŕ"]="r",
  ["Ŗ"]="r",["ŗ"]="r",["Ř"]="r",["ř"]="r",["Ś"]="s",["ś"]="s",["Ŝ"]="s",["ŝ"]="s",["Ş"]="s",["ş"]="s",["Š"]="s",
  ["š"]="s",["Ţ"]="t",["ţ"]="t",["Ť"]="t",["ť"]="t",["Ũ"]="u",["ũ"]="u",["Ū"]="u",["ū"]="u",["Ŭ"]="u",["ŭ"]="u",
  ["Ů"]="u",["ů"]="u",["Ű"]="u",["ű"]="u",["Ų"]="u",["ų"]="u",["Ŵ"]="w",["ŵ"]="w",["Ŷ"]="y",["ŷ"]="y",["Ÿ"]="y",
  ["Ź"]="z",["ź"]="z",["Ż"]="z",["ż"]="z",["Ž"]="z",["ž"]="z",["Ơ"]="o",["ơ"]="o",["Ư"]="u",["ư"]="u",["Ǎ"]="a",
  ["ǎ"]="a",["Ǐ"]="i",["ǐ"]="i",["Ǒ"]="o",["ǒ"]="o",["Ǔ"]="u",["ǔ"]="u",["Ǖ"]="u",["ǖ"]="u",["Ǘ"]="u",["ǘ"]="u",
  ["Ǚ"]="u",["ǚ"]="u",["Ǜ"]="u",["ǜ"]="u",["Ǟ"]="a",["ǟ"]="a",["Ǡ"]="a",["ǡ"]="a",["Ǧ"]="g",["ǧ"]="g",["Ǩ"]="k",
  ["ǩ"]="k",["Ǫ"]="o",["ǫ"]="o",["Ǭ"]="o",["ǭ"]="o",["ǰ"]="j",["Ǵ"]="g",["ǵ"]="g",["Ǹ"]="n",["ǹ"]="n",["Ǻ"]="a",
  ["ǻ"]="a",["Ȁ"]="a",["ȁ"]="a",["Ȃ"]="a",["ȃ"]="a",["Ȅ"]="e",["ȅ"]="e",["Ȇ"]="e",["ȇ"]="e",["Ȉ"]="i",["ȉ"]="i",
  ["Ȋ"]="i",["ȋ"]="i",["Ȍ"]="o",["ȍ"]="o",["Ȏ"]="o",["ȏ"]="o",["Ȑ"]="r",["ȑ"]="r",["Ȓ"]="r",["ȓ"]="r",["Ȕ"]="u",
  ["ȕ"]="u",["Ȗ"]="u",["ȗ"]="u",["Ș"]="s",["ș"]="s",["Ț"]="t",["ț"]="t",["Ȟ"]="h",["ȟ"]="h",["Ȧ"]="a",["ȧ"]="a",
  ["Ȩ"]="e",["ȩ"]="e",["Ȫ"]="o",["ȫ"]="o",["Ȭ"]="o",["ȭ"]="o",["Ȯ"]="o",["ȯ"]="o",["Ȱ"]="o",["ȱ"]="o",["Ȳ"]="y",
  ["ȳ"]="y",["ɡ"]="g",["Α"]="a",["Β"]="b",["Ε"]="e",["Ζ"]="z",["Η"]="h",["Ι"]="i",["Κ"]="k",["Μ"]="m",["Ν"]="n",
  ["Ο"]="o",["Ρ"]="p",["Τ"]="t",["Υ"]="y",["Χ"]="x",["α"]="a",["ε"]="e",["ι"]="i",["κ"]="k",["ν"]="v",["ο"]="o",
  ["ρ"]="p",["τ"]="t",["υ"]="u",["І"]="i",["А"]="a",["В"]="b",["Е"]="e",["К"]="k",["М"]="m",["Н"]="h",["О"]="o",
  ["Р"]="p",["С"]="c",["Т"]="t",["У"]="y",["Х"]="x",["а"]="a",["в"]="b",["е"]="e",["к"]="k",["м"]="m",["н"]="h",
  ["о"]="o",["р"]="p",["с"]="c",["т"]="t",["у"]="y",["х"]="x",["ѕ"]="s",["і"]="i",["ј"]="j",["ԁ"]="d",["０"]="0",
  ["１"]="1",["２"]="2",["３"]="3",["４"]="4",["５"]="5",["６"]="6",["７"]="7",["８"]="8",["９"]="9",["Ａ"]="a",["Ｂ"]="b",
  ["Ｃ"]="c",["Ｄ"]="d",["Ｅ"]="e",["Ｆ"]="f",["Ｇ"]="g",["Ｈ"]="h",["Ｉ"]="i",["Ｊ"]="j",["Ｋ"]="k",["Ｌ"]="l",["Ｍ"]="m",
  ["Ｎ"]="n",["Ｏ"]="o",["Ｐ"]="p",["Ｑ"]="q",["Ｒ"]="r",["Ｓ"]="s",["Ｔ"]="t",["Ｕ"]="u",["Ｖ"]="v",["Ｗ"]="w",["Ｘ"]="x",
  ["Ｙ"]="y",["Ｚ"]="z",["ａ"]="a",["ｂ"]="b",["ｃ"]="c",["ｄ"]="d",["ｅ"]="e",["ｆ"]="f",["ｇ"]="g",["ｈ"]="h",["ｉ"]="i",
  ["ｊ"]="j",["ｋ"]="k",["ｌ"]="l",["ｍ"]="m",["ｎ"]="n",["ｏ"]="o",["ｐ"]="p",["ｑ"]="q",["ｒ"]="r",["ｓ"]="s",["ｔ"]="t",
  ["ｕ"]="u",["ｖ"]="v",["ｗ"]="w",["ｘ"]="x",["ｙ"]="y",["ｚ"]="z",
}

-- Digits and signs written for letters
local LEET = { ["0"] = "o", ["1"] = "i", ["3"] = "e", ["4"] = "a", ["5"] = "s", ["7"] = "t", ["@"] = "a", ["$"] = "s" }

---------------------------------------------------------------------------
-- The settings: { words = { { text, variants, inword, off, hits } }, repeats, cyrillic, chinese, whisper (false: not
-- filtered), party, raid, guild, communities, off }
---------------------------------------------------------------------------
local function Store()
  local sv = ns.sv
  if not sv then return { words = {} } end
  if type(sv.chatFilter) ~= "table" then sv.chatFilter = {} end
  local s = sv.chatFilter
  if type(s.words) ~= "table" then s.words = {} end
  if s.group then -- (the first version's one box for all of them)
    s.party, s.raid, s.guild, s.communities, s.group = true, true, true, true, nil
  end
  return s
end
ns.ChatFilterStore = Store -- (for the tests)

---------------------------------------------------------------------------
-- The raid symbols: every way of writing them, as {rtN}
---------------------------------------------------------------------------
local SYMBOLS = {
  star = 1, circle = 2, diamond = 3, triangle = 4, moon = 5, square = 6, cross = 7, x = 7, skull = 8,
  etoile = 1, cercle = 2, losange = 3, lune = 5, carre = 6, croix = 7, crane = 8,
  stern = 1, kreis = 2, diamant = 3, dreieck = 4, mond = 5, quadrat = 6, kreuz = 7, totenschadel = 8, totenkopf = 8,
}

-- A text's letters folded: lower case, no accents, look-alike letters made Latin (UTF-8 aware)
local function Letters(text)
  return (text:gsub("[%z\1-\127\194-\244][\128-\191]*", function(ch)
    if #ch == 1 then return ch:lower() end
    return FOLD[ch] or ch
  end))
end

local function Symbol(name)
  name = Letters(name):gsub("[^%w]", "")
  local n = name:match("^rt([1-8])$") or SYMBOLS[name]
  if not n then
    for i = 1, 8 do
      local g = _G["RAID_TARGET_" .. i]
      if type(g) == "string" and Letters(g):gsub("[^%w]", "") == name then n = i break end
    end
  end
  return n and tonumber(n)
end

-- The raid symbols written {rtN}, the game's links and colors taken out (their visible text kept)
local function Clean(text)
  text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", " "):gsub("|A.-|a", " ")
  return (text:gsub("{([^{}]+)}", function(name)
    local n = Symbol(name)
    return n and ("{rt" .. n .. "}") or nil
  end))
end

-- Every variant folded: letters, digits for letters, symbols and spaces between letters; the words kept apart
local function Fold(text)
  text = Letters(Clean(text))
  text = text:gsub("{rt(%d)}", " rt%1 ")
  text = text:gsub("[%d@%$]", function(c)
    return LEET[c] or c
  end)
  -- (a sign inside a word taken out: "re.sted", "r-e-s-t-e-d")
  text = text:gsub("(%w)[^%w%s]+(%w)", "%1%2"):gsub("(%w)[^%w%s]+(%w)", "%1%2")
  text = text:gsub("[^%w]+", " ")
  -- (letters written one by one: "r e s t e d")
  text = text:gsub("%f[%w]%w%f[%W]", function(c) return "\1" .. c end)
  local n
  repeat text, n = text:gsub("\1(%w) +\1", "\1%1\1") until n == 0
  text = text:gsub("\1", "")
  return " " .. strtrim((text:gsub("%s+", " "))) .. " "
end
ns.ChatFilterFold = Fold -- (for the tests)

-- A word's match: folded (whole word, or inside others with its box), or as written
local function Boundary(text, s, e)
  local before, after = text:sub(s - 1, s - 1), text:sub(e + 1, e + 1)
  local function Word(c) return c ~= "" and (c:find("[%w\128-\255]") ~= nil) end
  return not Word(before) and not Word(after)
end
local folds = setmetatable({}, { __mode = "k" }) -- (each word folded once: not saved)
local function Folded(entry)
  local f = folds[entry]
  if not f or f.text ~= entry.text then
    local fold = Fold(entry.text)
    f = { text = entry.text, fold = fold, compact = (fold:gsub(" ", "")) }
    folds[entry] = f
  end
  return f
end
local function Matches(entry, raw, folded, compact)
  if entry.off or type(entry.text) ~= "string" or entry.text == "" then return false end
  if entry.variants ~= false then
    local f = Folded(entry)
    if f.compact == "" then return false end
    if entry.inword then return compact:find(f.compact, 1, true) ~= nil end
    return folded:find(f.fold, 1, true) ~= nil
  end
  local word = Clean(entry.text)
  local from = 1
  while true do
    local s, e = raw:find(word, from, true)
    if not s then return false end
    if entry.inword or Boundary(raw, s, e) then return true end
    from = s + 1
  end
end
ns.ChatFilterMatches = Matches -- (for the tests)

---------------------------------------------------------------------------
-- Scripts
---------------------------------------------------------------------------
local function Cyrillic(text) return text:find("[\208-\211][\128-\191]") ~= nil or text:find("\212[\128-\175]") ~= nil end
local HAN = { { 0x3400, 0x4DBF }, { 0x4E00, 0x9FFF }, { 0xF900, 0xFAFF }, { 0x20000, 0x2FA1F } }
local function Chinese(text)
  for ch in text:gmatch("[\224-\244][\128-\191]+") do
    local a, b, c, d = ch:byte(1, 4)
    local code
    if #ch == 3 and a < 240 then code = (a - 224) * 4096 + (b - 128) * 64 + c - 128
    elseif #ch == 4 then code = (a - 240) * 262144 + (b - 128) * 4096 + (c - 128) * 64 + d - 128 end
    if code then
      for _, r in ipairs(HAN) do if code >= r[1] and code <= r[2] then return true end end
    end
  end
  return false
end

---------------------------------------------------------------------------
-- The filter
---------------------------------------------------------------------------
-- Each chat and the box it goes by (public: always)
local SCOPE = { CHAT_MSG_CHANNEL = "public", CHAT_MSG_SAY = "public", CHAT_MSG_YELL = "public", CHAT_MSG_EMOTE = "public",
  CHAT_MSG_TEXT_EMOTE = "public", CHAT_MSG_WHISPER = "whisper",
  CHAT_MSG_PARTY = "party", CHAT_MSG_PARTY_LEADER = "party", CHAT_MSG_INSTANCE_CHAT = "party", CHAT_MSG_INSTANCE_CHAT_LEADER = "party",
  CHAT_MSG_RAID = "raid", CHAT_MSG_RAID_LEADER = "raid", CHAT_MSG_RAID_WARNING = "raid",
  CHAT_MSG_GUILD = "guild", CHAT_MSG_OFFICER = "guild", CHAT_MSG_COMMUNITIES_CHANNEL = "communities" }
local function Covered(s, event)
  local scope = SCOPE[event]
  if scope == "public" then return true end
  if scope == "whisper" then return s.whisper ~= false end
  return scope ~= nil and s[scope] == true
end
local REPEAT = 60 -- seconds: the same message from the same player again, hidden
local seen = {}   -- player .. message -> when last seen
local hidden = {} -- the lines hidden lately (newest last): { at, who, text, why, where }
local HIDDEN_MAX = 60
local last = { id = nil, result = false } -- (each window asks for the same line: decided once)
local Changed = function() end -- (the window's list and count, once built)

local function Friend(guid)
  if not (Plain(guid) and type(guid) == "string" and guid ~= "") then return false end
  if guid == UnitGUID("player") then return true end
  if C_FriendList and C_FriendList.IsFriend then
    local ok, yes = pcall(C_FriendList.IsFriend, guid)
    if ok and yes then return true end
  end
  if C_BattleNet and C_BattleNet.GetGameAccountInfoByGUID then
    local ok, info = pcall(C_BattleNet.GetGameAccountInfoByGUID, guid)
    if ok and info then return true end
  end
  return false
end

local function Decide(event, message, author, flags, guid)
  local s = Store()
  if s.off then return nil end
  if not Covered(s, event) then return nil end
  if flags == "GM" or flags == "DEV" or Friend(guid) then return nil end
  local raw = Clean(message)
  if s.cyrillic and Cyrillic(raw) then return "cyrillic" end
  if s.chinese and Chinese(raw) then return "chinese" end
  local words = s.words
  if #words > 0 then
    local folded = Fold(message)
    local compact = folded:gsub(" ", "")
    for _, entry in ipairs(words) do
      if Matches(entry, raw, folded, compact) then
        entry.hits = (entry.hits or 0) + 1
        return entry
      end
    end
  end
  if s.repeats then
    local key = tostring(author) .. "\0" .. Fold(message)
    local now = GetTime()
    local at = seen[key]
    seen[key] = now
    if at and now - at < REPEAT then return "repeat" end
  end
  return nil
end
ns.ChatFilterDecide = Decide -- (for the tests)

local function Filter(_, event, message, author, _, channel, _, flags, _, _, _, _, lineID, guid)
  if not (Plain(message) and Plain(author) and Plain(lineID)) or type(message) ~= "string" then return false end
  if lineID ~= 0 and lineID == last.id and event == last.event then return last.result end
  local why = Decide(event, message, author, Plain(flags) and flags or nil, Plain(guid) and guid or nil)
  last.id, last.event, last.result = lineID, event, why ~= nil
  if why then
    hidden[#hidden + 1] = { at = date and date("%H:%M") or "", who = author, text = message, where = Plain(channel) and channel or event,
      why = type(why) == "table" and why.text or why }
    if #hidden > HIDDEN_MAX then table.remove(hidden, 1) end
    Changed()
  end
  return why ~= nil
end
ns.ChatFilterFilter = Filter -- (for the tests)

-- (an old entry of the repeats forgotten now and then)
local function Forget()
  local now = GetTime()
  for k, at in pairs(seen) do if now - at > REPEAT then seen[k] = nil end end
end

---------------------------------------------------------------------------
-- The list
---------------------------------------------------------------------------
local function Add(text, variants, inword)
  if type(text) ~= "string" then return nil end
  text = strtrim(text)
  if text == "" or #text > 120 then return nil end
  local words = Store().words
  for _, e in ipairs(words) do
    if e.text == text and (e.variants ~= false) == (variants ~= false) and (not e.inword) == (not inword) then return nil end
  end
  local entry = { text = text, inword = inword and true or nil }
  if variants == false then entry.variants = false end
  words[#words + 1] = entry
  Changed()
  return entry
end
ns.ChatFilterAdd = Add -- (for the tests)

local function Edit(entry, text, variants, inword)
  if type(text) ~= "string" or strtrim(text) == "" then return end
  entry.text = strtrim(text)
  if variants == false then entry.variants = false else entry.variants = nil end
  entry.inword = inword and true or nil
  Changed()
end

local function Remove(entry)
  local words = Store().words
  for i, e in ipairs(words) do
    if e == entry then table.remove(words, i) break end
  end
  Changed()
end
ns.ChatFilterRemove = Remove -- (for the tests)

---------------------------------------------------------------------------
-- Its window
---------------------------------------------------------------------------
local ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d"
local function Shown(text) -- (the raid symbols drawn)
  return (Clean(text):gsub("{rt(%d)}", function(n) return "|T" .. ICON:format(n) .. ":0|t" end))
end

local win, Refresh
local editing -- the word being changed

local function Check(parent, label, x, y, get, set)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetSize(22, 22)
  c:SetPoint("TOPLEFT", x, y)
  local fs = c.Text or c.text or c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  if fs.SetFontObject then fs:SetFontObject("GameFontHighlightSmall") end
  fs:ClearAllPoints()
  fs:SetPoint("LEFT", c, "RIGHT", 2, 1)
  fs:SetText(label)
  c.label = fs
  c:SetScript("OnShow", function(self) self:SetChecked(get() and true or false) end)
  c:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
  return c
end

local ROW_H, ROWS = 22, 11
local function Build()
  if win then return win end
  win = CreateFrame("Frame", "ClaraChatFilter", UIParent, "BackdropTemplate")
  win:SetSize(500, 530)
  win:SetPoint("CENTER")
  win:SetFrameStrata("DIALOG")
  win:SetToplevel(true)
  win:EnableMouse(true)
  win:SetMovable(true)
  win:SetClampedToScreen(true)
  win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving)
  win:SetScript("OnDragStop", win.StopMovingOrSizing)
  if win.SetBackdrop then
    win:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    win:SetBackdropColor(0, 0, 0, .92)
    win:SetBackdropBorderColor(.72, .58, .34, 1)
  end
  if UISpecialFrames then table.insert(UISpecialFrames, "ClaraChatFilter") end
  local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", 14, -12)
  title:SetText(L.CF_TITLE)
  local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -2)
  -- (an opaque ground under the dialog's own fill: the world not seen through it)
  local ground = win:CreateTexture(nil, "BACKGROUND", nil, -7)
  ground:SetColorTexture(0.03, 0.03, 0.04, 0.93)
  ground:SetPoint("TOPLEFT", 6, -6)
  ground:SetPoint("BOTTOMRIGHT", -6, 6)
  if ns.DressDialog then ns:DressDialog(win, { close = close, fill = true, dark = true }) end

  -- the box to write in, Add (Save while a word is changed), Cancel
  local box = CreateFrame("EditBox", nil, win, "InputBoxTemplate")
  box:SetSize(360, 22)
  box:SetPoint("TOPLEFT", 20, -40)
  box:SetAutoFocus(false)
  box:SetMaxLetters(120)
  win.box = box
  local add = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
  add:SetSize(90, 22)
  add:SetPoint("LEFT", box, "RIGHT", 8, 0)
  win.add = add
  local cancel = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
  cancel:SetSize(22, 22)
  cancel:SetPoint("LEFT", add, "RIGHT", 2, 0)
  cancel:SetText("x")
  cancel:Hide()
  win.cancel = cancel

  -- the eight raid symbols, put in the box at its cursor
  for i = 1, 8 do
    local b = CreateFrame("Button", nil, win)
    b:SetSize(20, 20)
    b:SetPoint("TOPLEFT", 18 + (i - 1) * 24, -68)
    b:SetNormalTexture(ICON:format(i))
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnClick", function()
      box:Insert("{rt" .. i .. "}")
      box:SetFocus()
    end)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(_G["RAID_TARGET_" .. i] or ("{rt" .. i .. "}"))
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
  end

  -- the new word's boxes
  local opts = { variants = true, inword = false }
  win.opts = opts
  win.variants = Check(win, L.CF_VARIANTS, 16, -92, function() return opts.variants end, function(on) opts.variants = on end)
  win.inword = Check(win, L.CF_INWORD, 16, -114, function() return opts.inword end, function(on) opts.inword = on end)

  local function Commit()
    local text = box:GetText()
    if editing then Edit(editing, text, opts.variants, opts.inword) else Add(text, opts.variants, opts.inword) end
    editing = nil
    box:SetText("")
    box:ClearFocus()
    Refresh()
  end
  add:SetScript("OnClick", Commit)
  box:SetScript("OnEnterPressed", Commit)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  cancel:SetScript("OnClick", function()
    editing = nil
    box:SetText("")
    Refresh()
  end)

  -- the list: on/off, the word, its count, its cross; a click on the word: changed in the box above
  local listTop = -142
  local header = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  header:SetPoint("TOPLEFT", 18, listTop)
  win.header = header
  local scroll = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, listTop - 14)
  scroll:SetSize(440, ROW_H * ROWS)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(440, ROW_H)
  scroll:SetScrollChild(content)
  win.scroll, win.content = scroll, content
  win.rows = {}
  local function Row(i)
    local row = win.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, content)
    row:SetSize(440, ROW_H)
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * ROW_H)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.on = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.on:SetSize(20, 20)
    row.on:SetPoint("LEFT", 2, 0)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.text:SetPoint("LEFT", row.on, "RIGHT", 4, 0)
    row.text:SetPoint("RIGHT", -110, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row.tag = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.tag:SetPoint("RIGHT", -26, 0)
    row.tag:SetJustifyH("RIGHT")
    row.del = CreateFrame("Button", nil, row, "UIPanelCloseButton")
    row.del:SetSize(22, 22)
    row.del:SetPoint("RIGHT", 0, 0)
    row:SetScript("OnClick", function(self)
      local e = self.entry
      if not e then return end
      editing = e
      box:SetText(e.text)
      opts.variants, opts.inword = e.variants ~= false, e.inword and true or false
      box:SetFocus()
      Refresh()
    end)
    row.on:SetScript("OnClick", function(self)
      local e = self:GetParent().entry
      if e then e.off = (not self:GetChecked()) or nil end
      Refresh()
    end)
    row.del:SetScript("OnClick", function(self)
      local e = self:GetParent().entry
      if e == editing then editing = nil box:SetText("") end
      if e then Remove(e) end
    end)
    win.rows[i] = row
    return row
  end
  win.Row = Row

  -- the options
  local y = listTop - 18 - ROW_H * ROWS - 6
  local s = Store
  win.optRepeats = Check(win, L.CF_REPEATS, 16, y, function() return s().repeats end, function(on) s().repeats = on or nil end)
  win.optCyrillic = Check(win, L.CF_CYRILLIC, 186, y, function() return s().cyrillic end, function(on) s().cyrillic = on or nil end)
  win.optChinese = Check(win, L.CF_CHINESE, 336, y, function() return s().chinese end, function(on) s().chinese = on or nil end)
  -- (the chats filtered besides the public ones, each on its own)
  local also = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  also:SetPoint("TOPLEFT", 18, y - 30)
  also:SetText(L.CF_ALSO)
  local function Scope(key, label, x)
    return Check(win, label, x, y - 44, function()
      if key == "whisper" then return s().whisper ~= false end
      return s()[key] == true
    end, function(on)
      if key ~= "whisper" then s()[key] = on or nil
      elseif on then s().whisper = nil
      else s().whisper = false end
    end)
  end
  win.optWhisper = Scope("whisper", L.CF_WHISPER, 16)
  win.optParty = Scope("party", L.CF_PARTY, 136)
  win.optRaid = Scope("raid", L.CF_RAID, 226)
  win.optGuild = Scope("guild", L.CF_GUILD, 306)
  win.optCommunities = Scope("communities", L.CF_COMMUNITIES, 386)

  -- the lines hidden lately: a click, the line to copy
  local recent = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
  recent:SetSize(200, 22)
  recent:SetPoint("BOTTOMLEFT", 16, 12)
  recent:SetScript("OnClick", function()
    local out = {}
    for i = #hidden, 1, -1 do
      local h = hidden[i]
      out[#out + 1] = ("%s  [%s] %s: %s   (%s)"):format(h.at, tostring(h.where), tostring(h.who), Clean(h.text), tostring(h.why))
    end
    if ns.ShowCopyText then ns:ShowCopyText(L.CF_RECENT_TITLE, nil, #out > 0 and table.concat(out, "\n") or L.CF_RECENT_NONE) end
  end)
  win.recent = recent
  local onoff = Check(win, L.CF_ON, 240, -0, function() return not s().off end, function(on) s().off = (not on) or nil Refresh() end)
  onoff:ClearAllPoints()
  onoff:SetPoint("BOTTOMLEFT", 240, 12)
  win.onoff = onoff
  win:SetScript("OnShow", function() Refresh() end)
  win:Hide()
  return win
end

Refresh = function()
  if ns.ChatFilterButtonUpdate then ns.ChatFilterButtonUpdate() end
  if not (win and win:IsShown()) then return end
  local words = Store().words
  win.header:SetText(L.CF_LIST:format(#words))
  win.add:SetText(editing and L.CF_SAVE or L.CF_ADD)
  win.cancel:SetShown(editing ~= nil)
  win.variants:SetChecked(win.opts.variants)
  win.inword:SetChecked(win.opts.inword)
  win.recent:SetText(L.CF_RECENT:format(#hidden))
  win.onoff:SetChecked(not Store().off)
  win.content:SetHeight(math.max(ROW_H, #words * ROW_H))
  for i = 1, math.max(#words, #win.rows) do
    local row = win.Row(i)
    local e = words[i]
    row.entry = e
    if e then
      row.text:SetText(Shown(e.text))
      row.text:SetTextColor(e.off and .5 or 1, e.off and .5 or 1, e.off and .5 or 1)
      local tags = {}
      if e.variants ~= false then tags[#tags + 1] = L.CF_TAG_VARIANTS end
      if e.inword then tags[#tags + 1] = L.CF_TAG_INWORD end
      tags[#tags + 1] = tostring(e.hits or 0)
      row.tag:SetText(table.concat(tags, " · "))
      row.on:SetChecked(not e.off)
      if e == editing then row:LockHighlight() else row:UnlockHighlight() end
      row:Show()
    else
      row:Hide()
    end
  end
end
Changed = function() Refresh() end

local function Open()
  Build()
  if win:IsShown() then win:Hide() else win:Show() end
end
ns.ChatFilterOpen = Open -- (for the tests)

---------------------------------------------------------------------------
-- The module: its switch, its opener, its filters, its button
---------------------------------------------------------------------------
local function ButtonOn() return not (ns.sv and ns.sv.chatFilter and ns.sv.chatFilter.noButton) end
ns:SetQolSwitches("chatfilter", {
  { label = "CF_BUTTON", get = ButtonOn, set = function(on)
    Store().noButton = (not on) or nil
    if ns.ChatFilterButtonUpdate then ns.ChatFilterButtonUpdate() end
  end },
})
ns:SetQolOpener("chatfilter", Open)
if not ns:QolRuns("chatfilter") then return end

local AddFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
if AddFilter then
  for event in pairs(SCOPE) do pcall(AddFilter, event, Filter) end
end
if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(300, Forget) end

-- The button, under the chat's channel button (the voice buttons, when shown, kept above it)
local button
local function Place()
  if not button then return end
  local above = ChatFrameChannelButton
  for _, name in ipairs({ "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton" }) do
    local b = _G[name]
    if b and b.IsShown and b:IsShown() then above = b end
  end
  button:ClearAllPoints()
  if above then button:SetPoint("TOP", above, "BOTTOM", 0, -2) else button:SetPoint("TOPRIGHT", ChatFrame1, "TOPLEFT", -4, -60) end
end
function ns.ChatFilterButtonUpdate()
  if not button then return end
  button:SetShown(ButtonOn())
  local off = Store().off
  if button.icon.SetDesaturated then button.icon:SetDesaturated(off and true or false) end
  button.icon:SetAlpha(off and .5 or 1)
end
local function MakeButton()
  if button then return end
  local parent = ChatFrameChannelButton and ChatFrameChannelButton:GetParent() or UIParent
  button = CreateFrame("Button", "ClaraChatFilterButton", parent)
  local w, h = 27, 26
  if ChatFrameChannelButton and ChatFrameChannelButton.GetSize then w, h = ChatFrameChannelButton:GetSize() end
  button:SetSize(w > 0 and w or 27, h > 0 and h or 26)
  button:SetFrameStrata("MEDIUM")
  if button.SetNormalAtlas then
    button:SetNormalAtlas("chatframe-button-up")
    button:SetPushedAtlas("chatframe-button-down")
    button:SetHighlightAtlas("chatframe-button-highlight")
  end
  button.icon = button:CreateTexture(nil, "OVERLAY")
  button.icon:SetSize(15, 15)
  button.icon:SetPoint("CENTER", 0, 0)
  button.icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:SetScript("OnClick", function(_, which)
    if which == "RightButton" then
      Store().off = (not Store().off) or nil
      Refresh()
      if GameTooltip:IsOwned(button) then button:GetScript("OnEnter")(button) end
    else
      Open()
    end
  end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.CF_TITLE)
    GameTooltip:AddLine(L.CF_TIP:format(#Store().words, Store().off and L.CF_OFF or L.CF_ON_SHORT), 1, 1, 1, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", GameTooltip_Hide)
  Place()
  for _, name in ipairs({ "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton" }) do
    local b = _G[name]
    if b and b.HookScript then
      b:HookScript("OnShow", Place)
      b:HookScript("OnHide", Place)
    end
  end
  ns.ChatFilterButtonUpdate()
end
ns.ChatFilterButton = function() return button end -- (for the tests)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  MakeButton()
end)
