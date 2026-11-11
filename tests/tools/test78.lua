-- /played always answered (GameFixes.lua): shown by the game: nothing more; not shown (in a fight): written by
-- the game's own function in the main chat window
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function Run() local n = 0 while M.timers and #M.timers > 0 and n < 50 do M.RunTimer() n = n + 1 end end
TIME_PLAYED_TOTAL = "Total time played: %s"
TIME_PLAYED_LEVEL = "Time played this level: %s"
local shown = 0
ChatFrameUtil = ChatFrameUtil or {}
ChatFrameUtil.DisplayTimePlayed = function(frame, total, level)
  shown = shown + 1
  frame:AddMessage(TIME_PLAYED_TOTAL:format(total .. "s")); frame:AddMessage(TIME_PLAYED_LEVEL:format(level .. "s"))
end
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); Run()
local function Count() local n = 0 for _, l in ipairs(M.chat) do if tostring(l):find("Total time played", 1, true) then n = n + 1 end end return n end

-- the game shows it (out of a fight)
M.chat = {}
M.Fire("TIME_PLAYED_MSG", 3600, 60)
ChatFrameUtil.DisplayTimePlayed(ChatFrame1, 3600, 60) -- (the chat window's own handler)
Run()
check(Count() == 1, "shown by the game: not written twice")
-- in a fight: no chat window shows it
M.chat = {}
S.inCombat = true
M.Fire("TIME_PLAYED_MSG", 7200, 120); Run()
check(Count() == 1, "not shown by the game: written in the main chat window")
S.inCombat = false
out(string.format("\n%d failure(s)", fails))
return fails
