-- A system message the game repeats while you do nothing (WoW Forever's idle logout warning, sent again and again):
-- shown once, in every chat window; anything you do, or ten minutes, and it may show again. Other messages untouched.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local filters = {}
ChatFrameUtil = { AddMessageEventFilter = function(event, fn) filters[event] = filters[event] or {} table.insert(filters[event], fn) end }
S.class = "ROGUE"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.now = 1000
local IDLE = "You have been inactive for some time and will be logged out of the game.\n   If you wish to remain logged in, hit the cancel button."
-- shown in a chat window: no filter discards it (the line ID is the 11th argument)
local function Shows(text, line, frame)
  for _, fn in ipairs(filters.CHAT_MSG_SYSTEM or {}) do
    if fn(frame or "ChatFrame1", "CHAT_MSG_SYSTEM", text, "", "", "", "", "", 0, 0, "", 0, line) then return false end
  end
  return true
end
check(filters.CHAT_MSG_SYSTEM and #filters.CHAT_MSG_SYSTEM > 0, "a filter on the system messages")
check(Shows(IDLE, 101), "the warning the first time: shown")
check(Shows(IDLE, 101, "ChatFrame3"), "the same line in another chat window: shown there too")
M.now = 1030
check(not Shows(IDLE, 102), "again 30 s later, nothing done: not shown")
M.now = 1060
check(not Shows(IDLE, 103) and not Shows(IDLE, 103, "ChatFrame3"), "and again: not shown in any window")
check(Shows("Dinanu has come online.", 104), "another system message: shown")
check(Shows("Dinanu has come online.", 104, "ChatFrame3"), "in each window")
out("== something done: the warning may show again")
M.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
check(Shows(IDLE, 105), "after a click: shown once more")
check(not Shows(IDLE, 106), "then quiet again")
M.Fire("PLAYER_STARTED_MOVING")
check(Shows(IDLE, 107), "after moving: shown")
M.now = 1060 + 601
check(Shows(IDLE, 108), "ten minutes later, nothing done: shown again")
check(not Shows(IDLE, 109), "and quiet after it")
check(Shows("", 110) and Shows("", 111), "empty lines left as they are")
out(string.format("\n%d failure(s)", fails))
return fails
