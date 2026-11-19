-- Clara Combo Points - a quiet chat while the character logs in: every line an addon writes to
-- the chat from the loading screen until 10 seconds after the world shows is taken out again
-- at once; the game's own lines stay. On by default; a box in the game's options (Esc >
-- Options > AddOns > Clara Combo Points) turns it off.
-- The game's chat frames are not changed: a hook after each line added reads where it came from
-- (the call stack: an addon's file, or only the game's).
-- Also the game's own notice at each login, "Remember to act responsibly, protect your personal
-- information, and report anything offensive. View our In-Game Code of Conduct on
-- https://support.blizzard.com/article/42673..." (Blizzard_CodeOfConduct): taken out of the chat, that
-- line alone, by default; a box on the same page shows it again. Known by the game's own text
-- (ONLINE_SAFETY_NOTICE: any language) or its link, whatever a chat addon puts before it (a time).
-- The chat of the session before, which Leatrix Plus puts back at login, is left as it is.

local ADDON, ns = ...

local QUIET_FOR = 10 -- seconds after the world shows
local quietUntil     -- when the quiet ends (nil: the world is not shown yet)
local issecretvalue = issecretvalue or function() return false end

function ns:QuietLogin() return not self.sv or self.sv.quietLogin ~= false end

function ns:SetQuietLogin(on)
  if on then self.sv.quietLogin = nil else self.sv.quietLogin = false end
end

function ns:MuteConduct() return not self.sv or self.sv.muteConduct ~= false end

function ns:SetMuteConduct(on)
  if on then self.sv.muteConduct = nil else self.sv.muteConduct = false end
end

local CONDUCT_LINK = "support.blizzard.com/article/42673"
local function Conduct(text)
  if type(text) ~= "string" or issecretvalue(text) then return false end
  local notice = ONLINE_SAFETY_NOTICE
  if type(notice) == "string" and #notice > 20 and text:find(notice, 1, true) then return true end
  return text:find(CONDUCT_LINK, 1, true) ~= nil
end
ns.IsConductNotice = Conduct -- (for the tests)

local function Quiet()
  if quietUntil and GetTime() > quietUntil then return false end
  return ns:QuietLogin()
end

-- Did an addon write this line? (an addon's file in the call stack: the game's own addons
-- aside, and this file, which reads it; the modules embedded in Clara Combo Points count)
local function FromAddon()
  if not debugstack then return false end
  local ok, stack = pcall(debugstack, 2, 40, 0)
  if not ok or type(stack) ~= "string" then return false end
  for line in stack:gmatch("[^\n]+") do
    local name = line:match("AddOns[/\\]([^/\\%]]+)[/\\]")
    if name and not name:find("^Blizzard_") and not line:find("QuietLogin.lua", 1, true) then return true end
  end
  return false
end

local function Added(frame, message)
  if ns:MuteConduct() and Conduct(message) then
    frame:RemoveMessagesByPredicate(Conduct)
    return
  end
  if ns.ChatRestoring then return end -- (Leatrix Plus putting the chat of the session before back: left as it is)
  if not Quiet() or type(message) ~= "string" or issecretvalue(message) or not FromAddon() then return end
  frame:RemoveMessagesByPredicate(function(text) return not issecretvalue(text) and text == message end)
end

local hooked = {}
local function Hook(frame)
  if type(frame) ~= "table" or hooked[frame] or type(frame.AddMessage) ~= "function"
    or not frame.RemoveMessagesByPredicate or not hooksecurefunc then return end
  hooked[frame] = true
  hooksecurefunc(frame, "AddMessage", Added)
end

local function HookAll()
  for i = 1, NUM_CHAT_WINDOWS or 10 do Hook(_G["ChatFrame" .. i]) end
  Hook(DEFAULT_CHAT_FRAME)
end
HookAll() -- now: the addons loading after this one, and their login messages
if hooksecurefunc and FCF_OpenTemporaryWindow then hooksecurefunc("FCF_OpenTemporaryWindow", HookAll) end

-- (the notice, should a chat window the hooks missed show it: looked for again a little after the world shows)
local function SweepConduct()
  if not ns:MuteConduct() then return end
  for i = 1, NUM_CHAT_WINDOWS or 10 do
    local frame = _G["ChatFrame" .. i]
    if type(frame) == "table" and frame.RemoveMessagesByPredicate then frame:RemoveMessagesByPredicate(Conduct) end
  end
end

local watch = CreateFrame("Frame")
watch:RegisterEvent("PLAYER_ENTERING_WORLD")
watch:SetScript("OnEvent", function(self)
  if not quietUntil then quietUntil = GetTime() + QUIET_FOR end
  if C_Timer and C_Timer.After then
    C_Timer.After(1, SweepConduct)
    C_Timer.After(5, SweepConduct)
  end
end)
