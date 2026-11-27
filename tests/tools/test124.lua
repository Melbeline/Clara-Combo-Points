-- (The game's windows: the old lines put back above this session's with BackFillMessage, the newest first, 400 a frame.)
-- Leatrix Plus's chat (Clara's): Increase chat history (each window keeps 10000 lines, the game 128; what it holds
-- kept), Restore chat messages after a reload or a relog (the character's own saved variables, ClaraChatHistoryDB:
-- every line each window holds, in its color; the previous session's, a notice, then this one's)
local out = function(s) io.write(tostring(s), "\n") end
do local f = io.open(ADDON_DIR .. "/Modules/LeatrixPlus/Leatrix_Plus.lua", "rb")
  if not f then out("  ok   not in this version (Leatrix Plus: not in Light)"); out("0 failure(s)"); return 0 end
  f:close() end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local f = assert(io.open(ADDON_DIR .. "/Modules/LeatrixPlus/Leatrix_Plus.lua", "rb"))
local src = f:read("*a"); f:close()
local a = src:find("-- Increase chat history (Clara Combo Points", 1, true)
local b = src:find("--	More chat font sizes", 1, true)
check(a and b and a < b, "its code found")
local block = src:sub(src:sub(1, a):match(".*()\n") + 1, b - 1):gsub("\n[\t ]*%-+\n[\t ]*$", "\n")

local function Window(maxLines)
  local w = { lines = {}, max = maxLines or 128 }
  function w:AddMessage(t, r, g, b) table.insert(self.lines, { t, r, g, b }); while #self.lines > self.max do table.remove(self.lines, 1) end end
  function w:GetNumMessages() return #self.lines end
  function w:GetMessageInfo(i) local m = self.lines[i]; if m then return m[1], m[2], m[3], m[4] end end
  function w:SetMaxLines(n) self.max = n; self.lines = {} end -- (the game's: cleared)
  function w:GetMaxLines() return self.max end
  function w:Clear() self.lines = {} end
  return w
end
local function Run(LC, saved, setup)
  local env = setmetatable({}, { __index = _G })
  env._G = env -- (its windows looked up by name: these)
  local handlers = {}
  env.LeaPlusLC, env.LeaLockList, env.LeaPlusDB, env.ClaraNS = LC, {}, { ChatHistory1 = { "old" }, ChatHistoryName = "x" }, {}
  env.L = setmetatable({}, { __index = function(_, k) return k end })
  env.canaccessvalue = function() return true end
  env.RGBToColorCode = function(r, g, b) return ("|cff%02x%02x%02x"):format(math.floor(r * 255 + .5), math.floor(g * 255 + .5), math.floor(b * 255 + .5)) end
  env.GetServerTime = function() return 1000 end
  env.FCF_IsChatWindowIndexActive = function(i) return i <= 2 end
  env.ChatFrame1, env.ChatFrame2, env.NUM_CHAT_WINDOWS = Window(), Window(500), 2
  env.CreateFrame = function() return { RegisterEvent = function() end, SetScript = function(_, _, fn) handlers[#handlers + 1] = fn end } end
  env.hooksecurefunc = function() end
  env.FCF_OpenTemporaryWindow = function() end
  env.ClaraChatHistoryDB = saved
  -- (Leatrix's own panel helpers: its settings panel made, its gear's click kept)
  local function Panel() local p = { h = { Hide = function() end }, b = { SetScript = function() end }, r = { SetScript = function() end } } return p end
  env.LeaPlusLC.CreatePanel = function() return Panel() end
  env.LeaPlusLC.MakeTx = function() end
  env.LeaPlusLC.MakeSL = function(_, _, key, _, low, high) env.slider = { key = key, low = low, high = high } end
  env.LeaPlusCB = { MaxChatHstoryBtn = { SetScript = function(_, _, fn) env.gear = fn end } }
  if setup then setup(env) end
  local fn = assert(loadstring("return function() " .. block .. " end", "@chat"))()
  setfenv(fn, env)
  fn()
  return env, handlers
end
local function Texts(w) local t = {} for _, m in ipairs(w.lines) do t[#t + 1] = m[1] end return t end

out("== the game's 128 lines; Increase chat history: 10000, what the window held kept")
local env = Run({ MaxChatHstory = "Off", RestoreChatMessages = "Off" })
check(env.slider and env.slider.key == "MaxChatHstoryLines" and env.slider.low == 1000 and env.slider.high == 100000 and env.gear,
  "its settings: a slider, 1000 to 100000 lines, behind its gear")
for i = 1, 200 do env.ChatFrame1:AddMessage("line " .. i) end
check(#env.ChatFrame1.lines == 128, "off: the game's 128 lines (" .. #env.ChatFrame1.lines .. ")")
env = Run({ MaxChatHstory = "On", RestoreChatMessages = "Off" })
check(env.ChatFrame1:GetMaxLines() == 50000, "on, nothing chosen: 50000 lines a window")
env = Run({ MaxChatHstory = "On", MaxChatHstoryLines = 10000, RestoreChatMessages = "Off" }, nil, function(e) e.ChatFrame1:AddMessage("Welcome to World of Warcraft!", 1, 1, 0) end)
check(env.ChatFrame1:GetMaxLines() == 10000 and env.ChatFrame2:GetMaxLines() == 500, "10000 chosen: 10000 lines a window (the combat log left as it is)")
check(Texts(env.ChatFrame1)[1] == "Welcome to World of Warcraft!" and env.ChatFrame1.lines[1][2] == 1, "the line it held kept, in its color")
for i = 1, 5000 do env.ChatFrame1:AddMessage("line " .. i) end
check(#env.ChatFrame1.lines == 5001, "5000 more: all kept (" .. #env.ChatFrame1.lines .. ")")
check(env.ClaraNS.ChatRestoring == nil, "the restoring mark off again")

out("== restored at login: the previous session's lines, in their colors, a notice, then this session's")
local saved = { time = 900, [1] = { "|cffffff00Hello from yesterday", "|cff40c7ebElle whispers: hi |cffff0000red|r end" } }
env = Run({ MaxChatHstory = "On", RestoreChatMessages = "On" }, saved, function(e) e.ChatFrame1:AddMessage("Welcome to World of Warcraft!", 1, 1, 0) end)
local t = Texts(env.ChatFrame1)
check(t[1] == "Hello from yesterday" and t[2] == "Elle whispers: hi |cffff0000red|r end", "the old lines first, as they were (" .. tostring(t[1]) .. ")")
local l2 = env.ChatFrame1.lines[2]
check(math.abs(l2[2] - 0x40 / 255) < 0.01 and math.abs(l2[3] - 0xc7 / 255) < 0.01 and math.abs(l2[4] - 0xeb / 255) < 0.01, "each in its color (the whole line)")
check(t[3]:find("Restored 2 messages from previous session", 1, true) ~= nil, "the notice: " .. tostring(t[3]))
check(t[4] == "Welcome to World of Warcraft!", "this session's lines after")
check(env.ClaraChatHistoryDB == nil, "back in the windows: the saved copy let go (made again as the session ends)")
check(env.ClaraNS.ChatRestoring == nil, "the restoring mark off again")
check(env.LeaPlusDB.ChatHistory1 == nil and env.LeaPlusDB.ChatHistoryName == nil, "Leatrix's own single slot, from before: cleared")
env.ChatFrame1:AddMessage("A new line", 1, 1, 1)
out("== the game's windows (BackFillMessage): put back above this session's lines, the newest first, a batch each frame")
do
  local many = { time = 900, [1] = {} }
  for i = 1, 1000 do many[1][i] = "|cffffffffold " .. i end
  local queue, adds = {}, 0
  local envB = Run({ MaxChatHstory = "On", RestoreChatMessages = "On" }, many, function(e)
    local w = e.ChatFrame1
    function w:BackFillMessage(t, r, g, b) table.insert(self.lines, 1, { t, r, g, b }) end
    local add = w.AddMessage
    w:AddMessage("Welcome to World of Warcraft!", 1, 1, 0)
    function w:AddMessage(t, ...) if tostring(t):find("^old ") then adds = adds + 1 end return add(self, t, ...) end -- (another addon's hook on it)
    e.C_Timer = { After = function(_, fn) queue[#queue + 1] = fn end }
  end)
  local w = envB.ChatFrame1
  local tB = Texts(w)
  check(#tB == 402 and tB[1] == "old 601" and tB[400] == "old 1000" and tB[401]:find("Restored 1000 messages", 1, true)
    and tB[402] == "Welcome to World of Warcraft!", ("at once: the 400 newest, above the notice and this session's lines (%d, %s)"):format(#tB, tostring(tB[1])))
  check(#queue == 1, "the rest left for the next frame")
  while #queue > 0 do table.remove(queue, 1)() end
  tB = Texts(w)
  check(#tB == 1002 and tB[1] == "old 1" and tB[1000] == "old 1000" and tB[1002] == "Welcome to World of Warcraft!", "frame by frame: all of them, in their order (" .. #tB .. ")")
  check(adds == 0, "the windows' AddMessage not run again for them (another addon's hook on it: " .. adds .. ")")
  check(math.abs(w.lines[1][2] - 1) < 0.01, "in their color")
  check(envB.ClaraNS.ChatRestoring == nil and envB.ClaraChatHistoryDB == nil, "the restoring mark off, the saved copy let go")
end
out("== saved at logout: every line, the notice left out")
local env2, hs = Run({ MaxChatHstory = "On", RestoreChatMessages = "On" }, saved)
env2.ChatFrame1:AddMessage("Said today", 1, 0.5, 0)
hs[#hs](env2.ChatFrame1)
local db = env2.ClaraChatHistoryDB
check(type(db) == "table" and db.time == 1000 and #db[1] == 3, "its 3 lines (" .. (db and db[1] and #db[1] or 0) .. ")")
check(db[1][3] == "|cffff8000Said today", "each with its color before it")
for _, line in ipairs(db[1]) do if line:find("Restored", 1, true) then check(false, "a notice saved") end end
out("== Restore chat messages off: its saved chat cleared")
env = Run({ MaxChatHstory = "On", RestoreChatMessages = "Off" }, saved)
check(env.ClaraChatHistoryDB == nil, "cleared")
out(string.format("\n%d failure(s)", fails))
return fails
