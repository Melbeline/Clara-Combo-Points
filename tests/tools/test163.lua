-- The target's name into a macro (TargetMacro.lua): a double click on the target frame's name writes it in the macro
-- ClaraTarget, made the first time ("/tm8" then "/tar <name>"); its /tar line takes the new name, the player's other
-- lines kept; a double middle click: its first word only; two clicks apart, a right click: nothing; in a fight:
-- written as it ends; the box off: nothing; a macro too long: nothing changed; on the name's own button (GameFixes).
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

out("== the first double click: the macro made")
Double("LeftButton")
check(Body() == "/tm8\n/tar Hatefury Felsworn", "ClaraTarget: /tm8, /tar the whole name: " .. tostring(Body()))
check(macros[1] and not macros[1].perChar, "the account's")
check(said[#said]:find("/tar Hatefury Felsworn", 1, true), "said in the chat")
out("== the player's own line kept")
macros[1].body = "/tm8\n/tar Hatefury Felsworn\n/cast Shadow Word: Pain"
targetName = "Gorefang Ravager"
Double("LeftButton")
check(Body() == "/tm8\n/tar Gorefang Ravager\n/cast Shadow Word: Pain", "the /tar line changed, /cast kept: " .. Body():gsub("\n", " | "))
out("== a double middle click: its first word only")
targetName = "Hatefury Felsworn"
Double("MiddleButton")
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
Double("LeftButton")
check(Body() == "/cast Renew\n/tar Someone Else", "its /target line: " .. Body():gsub("\n", " | "))
macros[1].body = "/tm 8\n/cast Renew"
Double("LeftButton")
check(Body() == "/tm 8\n/tar Someone Else\n/cast Renew", "no /tar line: one after /tm: " .. Body():gsub("\n", " | "))
out("== in a fight: written as it ends")
S.inCombat = true
targetName = "Fight Mob"
local ok = pcall(Double, "LeftButton")
check(ok and not Body():find("Fight Mob", 1, true) and said[#said]:find("Fight Mob", 1, true), "nothing changed in it, said")
S.inCombat = false
M.Fire("PLAYER_REGEN_ENABLED")
check(Body():find("/tar Fight Mob", 1, true) ~= nil, "the fight over: written")
out("== too long for a macro: nothing changed")
macros[1].body = "/tm8\n/tar x\n/cast " .. ("a"):rep(240)
local before = macros[1].body
targetName = "Long Name Here"
Double("LeftButton")
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
out("")
out(fails .. " failure(s)")
