-- Clara Combo Points - a quiet chat while the character logs in: every line an addon writes to
-- the chat from the loading screen until 10 seconds after the world shows is taken out again
-- at once; the game's own lines stay. On by default; a box in the game's options (Esc >
-- Options > AddOns > Clara Combo Points) turns it off.
-- The game's chat frames are not changed: a hook after each line added reads where it came from
-- (the call stack: an addon's file, or only the game's).

local ADDON, ns = ...

local QUIET_FOR = 10 -- seconds after the world shows
local quietUntil     -- when the quiet ends (nil: the world is not shown yet)
local issecretvalue = issecretvalue or function() return false end

function ns:QuietLogin() return not self.sv or self.sv.quietLogin ~= false end

function ns:SetQuietLogin(on)
  if on then self.sv.quietLogin = nil else self.sv.quietLogin = false end
end

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

local watch = CreateFrame("Frame")
watch:RegisterEvent("PLAYER_ENTERING_WORLD")
watch:SetScript("OnEvent", function(self)
  quietUntil = GetTime() + QUIET_FOR
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)
