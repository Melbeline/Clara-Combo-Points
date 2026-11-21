-- LFG Forever built in, without its auto-whispers (the player's rule: no addon sends a message without being asked).
-- "Auto-whisper on Ask to Join" and "Auto-whisper on Invite" gone entirely: no setting, no message, no placeholder,
-- no talent read for %talents%, no file of the module able to send a chat message; Ask to Join opens a whisper box
-- (the game's SendTell, nothing sent, no cooldown), Invite only invites; the old saved keys cleared on load; its
-- words and Clara's say so.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function readfile(p) local f = io.open(p, "rb"); if not f then return nil end local s = f:read("*a"); f:close(); return s end
local DIR = ADDON_DIR .. "/Modules/LFGForever/"
local toc = readfile(ADDON_DIR .. "/ClaraComboPoints.toc")
if not readfile(DIR .. "main.lua") then -- (the Light version: not built in)
  check(not toc:find("LFGForever", 1, true), "the Light version: LFG Forever not built in")
  out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
  return
end

out("== no file of the module can send a chat message")
local FILES = {}
for file in toc:gmatch("Modules\\LFGForever\\([%w_]+%.%a+)") do FILES[#FILES + 1] = file end
check(#FILES >= 15, "its files from the TOC (" .. #FILES .. ")")
local sends = {}
for _, file in ipairs(FILES) do
  local src = readfile(DIR .. file) or ""
  for _, call in ipairs({ "SendChatMessage%s*%(", "BNSendWhisper%s*%(", "BNSendConversationMessage%s*%(",
    "LFGF%.Whisper%s*%(", "SendAddonMessage%s*%(" }) do
    for line in src:gmatch("[^\n]+") do
      if not line:match("^%s*%-%-") and line:find(call) then sends[#sends + 1] = file .. ": " .. line end
    end
  end
end
check(#sends == 0, "no send of any kind: " .. table.concat(sends, " | "))

out("== the two options gone, with all that served them")
check(not readfile(DIR .. "talents.lua") and not toc:find("talents.lua", 1, true), "the talent read (only for %talents%): gone")
check(not readfile(DIR .. "settings.xml") and not toc:find("LFGForever\\settings.xml", 1, true), "the message rows' template: gone")
local all = ""
for _, file in ipairs(FILES) do all = all .. (readfile(DIR .. file) or "") end
for _, word in ipairs({ "AskToJoinMessage", "InviteWhisperMessage", "ASK_TO_JOIN_DEFAULT_MESSAGE",
  "INVITE_WHISPER_DEFAULT_MESSAGE", "SETTINGS_ASK_TO_JOIN_AUTO_WHISPER", "SETTINGS_INVITE_AUTO_WHISPER",
  "SETTINGS_ASK_TO_JOIN_MESSAGE", "SETTINGS_INVITE_MESSAGE", "SETTINGS_PLACEHOLDER", "LFGFOREVER_ASK_TO_JOIN_AUTO_WHISPER",
  "LFGFOREVER_INVITE_AUTO_WHISPER", "SetInviteActivitySource", "LoadTalentPoints", "MessageRow" }) do
  check(not all:find(word, 1, true), "no " .. word)
end

-- its saved keys (db.lua, run on its own)
local LFGF = { L = setmetatable({}, { __index = function(_, k) return k end }) }
local ClaraNS = { LFGForeverRuns = true, LFGForeverPrivate = LFGF }
local chunk = assert(loadstring(readfile(DIR .. "db.lua"), "@db.lua"))
chunk("ClaraComboPoints", ClaraNS)
local keys = {}
for _, entry in ipairs(LFGF.SAVED_KEYS) do keys[entry.key] = true end
check(not keys.askToJoinAutoWhisper and not keys.askToJoinMessage and not keys.inviteAutoWhisper and not keys.inviteMessage,
  "none of the four among its saved keys")
check(keys.whisperLogSize and keys.showAllLevelRanges and keys.markGuildmates, "its other settings kept")
local removed = {}
for _, k in ipairs(LFGF.REMOVED_KEYS or {}) do removed[k] = true end
check(removed.askToJoinAutoWhisper and removed.askToJoinMessage and removed.inviteAutoWhisper and removed.inviteMessage,
  "the four listed to be cleared")

-- the old keys cleared from both saved tables on load (settings.lua's ADDON_LOADED part, run here on its own)
local settings = readfile(DIR .. "settings.lua")
local body = settings:match("(\tlocal account, character = LFGF%.SavedTable%(\"account\"%), LFGF%.SavedTable%(\"character\"%)\n.-\tend\n)")
check(body ~= nil, "the clearing on load")
if body then
  ClaraLFGForeverDB = { askToJoinAutoWhisper = true, inviteAutoWhisper = true, whisperLogSize = 300 }
  ClaraLFGForeverCharDB = { askToJoinMessage = "Hi! I am a %talents% %class%, %level%. Inv please", inviteMessage = "Hey!", sortOrder = 1 }
  local run = assert(loadstring("local LFGF = ...\n" .. body))
  run(LFGF)
  check(ClaraLFGForeverDB.askToJoinAutoWhisper == nil and ClaraLFGForeverDB.inviteAutoWhisper == nil
    and ClaraLFGForeverCharDB.askToJoinMessage == nil and ClaraLFGForeverCharDB.inviteMessage == nil, "cleared from the account's and the character's")
  check(ClaraLFGForeverDB.whisperLogSize == 300 and ClaraLFGForeverCharDB.sortOrder == 1, "the rest kept")
end

out("== the row buttons: Ask to Join opens a whisper box, Invite only invites")
local list = readfile(DIR .. "listpanel.lua")
local ask = list:match("local function UpdateAskToJoinButton.-\nend\n")
check(ask and ask:find("ChatFrameUtil.SendTell(leaderName)", 1, true) and ask:find("return false", 1, true), "Ask to Join: the game's whisper box, no cooldown")
local inv = list:match("local function UpdateInviteButton.-\nend\n")
check(inv and inv:find("button.action = function()\n\t\t\tinviteFunc()\n\t\tend", 1, true), "Invite: the invite only")

-- the two actions run, with the game's calls stood in for
if ask then
  local told, sent = {}, 0
  ChatFrameUtil = ChatFrameUtil or {}
  local oldTell = ChatFrameUtil.SendTell
  ChatFrameUtil.SendTell = function(name) told[#told + 1] = name end
  C_ChatInfo = C_ChatInfo or {}
  local oldSend = C_ChatInfo.SendChatMessage
  C_ChatInfo.SendChatMessage = function() sent = sent + 1 end
  canaccessvalue = canaccessvalue or function() return true end
  local env = setmetatable({ LFGF = LFGF, ApplyLockTo = function() end }, { __index = _G })
  local fn = assert(loadstring(ask .. "\nreturn UpdateAskToJoinButton"))
  setfenv(fn, env)
  local Update = fn()
  local shown = false
  local button = { Hide = function() end, Show = function() shown = true end }
  local row = { LFGFAskToJoin = button, hasSelf = false }
  env.CanActOnRow = function() return true end
  Update(row, { leaderName = "Elle Woods" }, false, false)
  local r = button.action and button.action()
  check(shown and #told == 1 and told[1] == "Elle Woods" and r == false and sent == 0,
    "clicked: a whisper box to the leader, nothing sent, no cooldown")
  ChatFrameUtil.SendTell, C_ChatInfo.SendChatMessage = oldTell, oldSend
end

out("== the words")
local locales = readfile(ADDON_DIR .. "/Locales.lua")
check(not locales:find("Invite that whisper your message", 1, true) and locales:find("nothing is ever sent for you", 1, true),
  "Clara's card says nothing is sent")
check(locales:find("rien n'est jamais envoyé à ta place", 1, true), "in French too")
out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
