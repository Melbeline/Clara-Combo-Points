-- The target's name into a macro (TargetMacro.lua): a double click on the target frame's name writes it in the macro
-- ClaraTarget, made the first time ("/tm8" then "/tar <name>"): its first word (a double middle click: the whole
-- name); its /tar line takes the new name, the player's other lines kept; two clicks apart, a right click: nothing; in a fight:
-- written as it ends; the box off: nothing; a macro too long: nothing changed; on the name's own button (GameFixes).
-- The icon a file number (134400). The game's own event for a release, the name under the mouse, takes the click too
-- (another frame over the name), the same release seen twice counted once; a secret name, an error, a change the game
-- did not keep: said, in the report.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local macros = {} -- index -> { name, icon, body, perChar }
function GetMacroIndexByName(name) for i, m in pairs(macros) do if m.name == name then return i end end return 0 end
function GetMacroInfo(i) local m = macros[i] if m then return m.name, m.icon, m.body end end
function EditMacro(i, name, icon, body)
  assert(not S.inCombat, "EditMacro in combat")
  macros[i] = { name = name, icon = icon, body = body, perChar = macros[i].perChar }
  return i
end
function CreateMacro(name, icon, body, perChar)
  assert(not S.inCombat, "CreateMacro in combat")
  local i = perChar and 121 or 1
  while macros[i] do i = i + 1 end
  macros[i] = { name = name, icon = icon, body = body, perChar = perChar }
  return i
end
function GetNumMacros()
  local a, c = 0, 0
  for i in pairs(macros) do if i > 120 then c = c + 1 else a = a + 1 end end
  return a, c
end
local targetName = "Hatefury Felsworn"
local oldName = UnitName
function UnitName(u) if u == "target" then return targetName end return oldName(u) end
local said = {}
local oldAdd = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(self, t, ...) said[#said + 1] = t if oldAdd then return oldAdd(self, t, ...) end end

local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
if not ns.TargetMacroClick then out("(no target macro in this version)"); out(""); out("0 failure(s)"); return end
local now = 100
GetTime = function() return now end
local Click = ns.TargetMacroClick
local function Double(button) Click(nil, button); now = now + 0.2; Click(nil, button); now = now + 2 end
local function Body() local i = GetMacroIndexByName("ClaraTarget") return i > 0 and macros[i].body or nil end

out("== the first double click (middle): the macro made, the whole name")
Double("MiddleButton")
check(Body() == "/tm8\n/tar Hatefury Felsworn", "ClaraTarget: /tm8, /tar the whole name: " .. tostring(Body()))
check(macros[1] and not macros[1].perChar, "the account's")
check(macros[1] and macros[1].icon == 134400, "the question mark icon, as a file number: " .. tostring(macros[1] and macros[1].icon))
check(said[#said]:find("/tar Hatefury Felsworn", 1, true), "said in the chat")
out("== the player's own line kept")
macros[1].body = "/tm8\n/tar Hatefury Felsworn\n/cast Shadow Word: Pain"
targetName = "Gorefang Ravager"
Double("MiddleButton")
check(Body() == "/tm8\n/tar Gorefang Ravager\n/cast Shadow Word: Pain", "the /tar line changed, /cast kept: " .. Body():gsub("\n", " | "))
out("== a double left click: its first word only")
targetName = "Hatefury Felsworn"
Double("LeftButton")
check(Body() == "/tm8\n/tar Hatefury\n/cast Shadow Word: Pain", "/tar Hatefury: " .. Body():gsub("\n", " | "))
out("== not a double click: nothing")
targetName = "Someone Else"
Click(nil, "LeftButton"); now = now + 1; Click(nil, "LeftButton"); now = now + 2
check(Body():find("/tar Hatefury\n", 1, true), "two clicks a second apart: nothing")
Click(nil, "LeftButton"); now = now + 0.1; Click(nil, "MiddleButton"); now = now + 2
check(Body():find("/tar Hatefury\n", 1, true), "a left then a middle: nothing")
Double("RightButton")
check(Body():find("/tar Hatefury\n", 1, true), "a right double click (the menu): nothing")
out("== a macro the player changed: /target line taken, or one put after /tm")
macros[1].body = "/cast Renew\n/target Old Name"
Double("MiddleButton")
check(Body() == "/cast Renew\n/tar Someone Else", "its /target line: " .. Body():gsub("\n", " | "))
macros[1].body = "/tm 8\n/cast Renew"
Double("MiddleButton")
check(Body() == "/tm 8\n/tar Someone Else\n/cast Renew", "no /tar line: one after /tm: " .. Body():gsub("\n", " | "))
out("== in a fight: written as it ends")
S.inCombat = true
targetName = "Fight Mob"
local ok = pcall(Double, "MiddleButton")
check(ok and not Body():find("Fight Mob", 1, true) and said[#said]:find("Fight Mob", 1, true), "nothing changed in it, said")
S.inCombat = false
M.Fire("PLAYER_REGEN_ENABLED")
check(Body():find("/tar Fight Mob", 1, true) ~= nil, "the fight over: written")
out("== too long for a macro: nothing changed")
macros[1].body = "/tm8\n/tar x\n/cast " .. ("a"):rep(240)
local before = macros[1].body
targetName = "Long Name Here"
Double("MiddleButton")
check(macros[1].body == before and said[#said]:find("255", 1, true), "left as it was, said")
out("== the box off: nothing")
macros[1].body = "/tm8\n/tar x"
ns:SetTargetMacro(false)
Double("LeftButton")
check(Body() == "/tm8\n/tar x" and not ns:TargetMacro(), "off: nothing")
ns:SetTargetMacro(true)
out("== the account's macros full: this character's")
macros = {}
for i = 1, 120 do macros[i] = { name = "M" .. i, body = "" } end
Double("LeftButton")
check(macros[121] and macros[121].name == "ClaraTarget" and macros[121].perChar, "made as this character's")
out("== the game's event for a release over the name (another frame on top): a double click")
macros = { [1] = { name = "ClaraTarget", icon = 134400, body = "/tm8\n/tar x" } }
local over, visible = false, true
TargetFrame = { IsVisible = function() return visible end,
  TargetFrameContent = { TargetFrameContentMain = { Name = { IsMouseOver = function() return over end } } } }
targetName = "Event Mob"
local function Up(button) M.Fire("GLOBAL_MOUSE_UP", button) end
Up("LeftButton"); now = now + 0.2; Up("LeftButton"); now = now + 2
check(Body() == "/tm8\n/tar x", "the mouse elsewhere: nothing")
over = true
Up("MiddleButton"); now = now + 0.2; Up("MiddleButton"); now = now + 2
check(Body() == "/tm8\n/tar Event Mob", "over the name: written: " .. Body():gsub("\n", " | "))
visible = false
targetName = "Hidden Frame"
Up("MiddleButton"); now = now + 0.2; Up("MiddleButton"); now = now + 2
check(Body() == "/tm8\n/tar Event Mob", "the target frame hidden: nothing")
visible = true
out("== one release seen by the button and by the event: counted once")
targetName = "Once Only"
Click(nil, "MiddleButton", "button"); Up("MiddleButton") -- (the same moment: one release)
now = now + 3
check(Body() == "/tm8\n/tar Event Mob", "a single click seen twice: not a double one")
Click(nil, "MiddleButton", "button"); Up("MiddleButton"); now = now + 0.2; Up("MiddleButton"); Click(nil, "MiddleButton", "button"); now = now + 2
check(Body() == "/tm8\n/tar Once Only", "a double click seen twice: written once: " .. Body():gsub("\n", " | "))
over = false
out("== a secret name: said, nothing written")
targetName = M.Secret("Secret Mob")
local n = #said
Double("MiddleButton")
check(Body() == "/tm8\n/tar Once Only" and #said == n + 1 and said[#said]:find(ns.L.TM_SECRET, 1, true), "said: " .. tostring(said[#said]))
out("== an error from the game: said")
targetName = "Error Mob"
local oldEdit = EditMacro
EditMacro = function() error("Invalid macro") end
Double("MiddleButton")
check(said[#said]:find("Invalid macro", 1, true) ~= nil, "said: " .. tostring(said[#said]))
out("== a change the game did not keep: said a moment later, in the report")
EditMacro = function() end
M.timers = {}
targetName = "Lost Mob"
n = #said
Double("MiddleButton")
check(#said == n and #(M.timers or {}) == 1, "nothing said at once, looked at again later")
M.RunTimer()
check(said[#said] and said[#said]:find(ns.L.TM_NOT_KEPT, 1, true), "then said: " .. tostring(said[#said]))
local r = ns:TargetMacroReport()
check(r:find("not kept by the game: Lost Mob", 1, true) and r:find("macro #1 /tm8 | /tar Once Only", 1, true), r)
EditMacro = oldEdit
out("")
out(fails .. " failure(s)")
