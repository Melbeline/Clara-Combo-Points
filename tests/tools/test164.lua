-- Following the target from its portrait (TargetMacro.lua): a double left click on the target frame's portrait follows
-- it (no macro); Shift + double click: its first word in the macro ClaraFollow ("/follow <name>", made the first
-- time), Ctrl + double click: its whole name, the player's other lines kept, a "/f" line taken; a middle or right
-- double click: nothing; the box off: nothing. The name's spot and the portrait's never share a point: the mouse
-- over both, a double click does nothing; over the portrait only, the follow; over the name only, the ClaraTarget
-- macro. The report names both.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local macros = {}
function GetMacroIndexByName(name) for i, m in pairs(macros) do if m.name == name then return i end end return 0 end
function GetMacroInfo(i) local m = macros[i] if m then return m.name, m.icon, m.body end end
function EditMacro(i, name, icon, body)
  assert(not S.inCombat, "EditMacro in combat")
  local m = macros[i]
  macros[i] = { name = name or m.name, icon = icon or m.icon, body = body or m.body, perChar = m.perChar }
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
local followed = {}
function FollowUnit(u) followed[#followed + 1] = u end
local shift, ctrl = false, false
function IsShiftKeyDown() return shift end
function IsControlKeyDown() return ctrl end
local targetName = "Hatefury Felsworn"
local oldName = UnitName
function UnitName(u) if u == "target" then return targetName end return oldName(u) end

local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
if not ns.FollowClickUp then out("(no follow click in this version)"); out(""); out("0 failure(s)"); return end
local now = 100
GetTime = function() return now end
local Up = ns.FollowClickUp
local function Double(button) Up(nil, button); now = now + 0.2; Up(nil, button); now = now + 2 end
local function Body(name) local i = GetMacroIndexByName(name or "ClaraFollow") return i > 0 and macros[i].body or nil end

out("== a double left click on the portrait: followed, no macro")
Double("LeftButton")
check(#followed == 1 and followed[1] == "target", "FollowUnit(\"target\"): " .. tostring(followed[1]))
check(Body() == nil and Body("ClaraTarget") == nil, "no macro made")
out("== Shift + double click: its first word in ClaraFollow")
shift = true
Double("LeftButton")
shift = false
check(Body() == "/follow Hatefury" and #followed == 1, "ClaraFollow: " .. tostring(Body()))
check(macros[1].icon == 134400, "made with the question mark")
out("== Ctrl + double left click: its whole name, the player's own lines kept")
macros[1].body = "/follow Hatefury\n/script print('hi')"
ctrl = true
Double("LeftButton")
check(Body() == "/follow Hatefury Felsworn\n/script print('hi')", "the /follow line changed: " .. Body():gsub("\n", " | "))
out("== a \"/f\" line taken, a /focus line left")
macros[1].body = "/focus\n/f Somebody"
targetName = "Lia Moon"
Double("LeftButton")
check(Body() == "/focus\n/follow Lia Moon", "the /f line taken, /focus left: " .. Body():gsub("\n", " | "))
ctrl = false
out("== a middle or right double click: nothing")
local n = #followed
Double("MiddleButton"); Double("RightButton")
check(#followed == n, "not followed")
out("== the box off: nothing")
ns:SetFollowClick(false)
Double("LeftButton")
check(#followed == n and not ns:FollowClick(), "off: not followed")
ns:SetFollowClick(true)

out("== the spots: the mouse over the portrait, the name, or both")
macros = {}
local overName, overPortrait, visible = false, false, true
TargetFrame = { IsVisible = function() return visible end,
  TargetFrameContent = { TargetFrameContentMain = { Name = { IsMouseOver = function() return overName end } } },
  TargetFrameContainer = { Portrait = { IsMouseOver = function() return overPortrait end } } }
targetName = "Event Mob"
local function Rel(button) M.Fire("GLOBAL_MOUSE_UP", button) end
local function EvDouble(button) Rel(button); now = now + 0.2; Rel(button); now = now + 2 end
n = #followed
overName, overPortrait = true, true
EvDouble("LeftButton"); EvDouble("MiddleButton")
check(#followed == n and Body("ClaraTarget") == nil, "over both (where they would overlap): nothing at all")
overName, overPortrait = false, true
EvDouble("LeftButton")
check(#followed == n + 1 and Body("ClaraTarget") == nil, "over the portrait only: followed, ClaraTarget untouched")
overName, overPortrait = true, false
EvDouble("LeftButton")
check(#followed == n + 1 and Body("ClaraTarget") == "/tm 8\n/tar Event", "over the name only: ClaraTarget, not followed: " .. tostring(Body("ClaraTarget")))
overName, overPortrait = false, false
EvDouble("LeftButton")
check(#followed == n + 1, "over neither: nothing")
out("== one release on each spot: not a double click")
overName, overPortrait = false, true
Rel("LeftButton"); now = now + 0.2
overName, overPortrait = true, false
Rel("LeftButton"); now = now + 2
check(#followed == n + 1 and Body("ClaraTarget") == "/tm 8\n/tar Event", "a portrait then a name release: nothing")
out("== in a fight: Shift + double click written as it ends; the follow at once")
overName, overPortrait = false, true
S.inCombat = true
shift = true
targetName = "Fight Mob"
local ok = pcall(EvDouble, "LeftButton")
check(ok and Body() == nil, "not written in the fight")
S.inCombat = false
M.Fire("PLAYER_REGEN_ENABLED")
check(Body() == "/follow Fight", "the fight over: /follow Fight: " .. tostring(Body()))
shift = false
out("== the report")
local r = ns:TargetMacroReport()
check(r:find("follow on true", 1, true) and r:find("ClaraFollow #", 1, true) and r:find("over the portrait 1", 1, true), r)
out("")
out(fails .. " failure(s)")
