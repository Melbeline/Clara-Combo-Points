-- Following the target from its portrait (TargetMacro.lua). The game refuses FollowUnit to an addon: a first plain left
-- click on the target frame's portrait makes, from the next frame and for half a second, the target frame's own next
-- plain left click run "/follow" (its type1 a macro), as the game's menu Follow; then the frame as it was (another
-- addon's type1 given back). Never FollowUnit. Shift + double left click: its first word in the macro ClaraFollow
-- ("/follow <name>", made the first time); Shift + double right click: its whole name ("First Surname" for a player),
-- the player's other lines kept, a "/f" line taken; a plain double right click, a middle one: nothing; the box off:
-- nothing; in a fight: the frame left alone, undone as one starts. The name's spot and the portrait's never share a
-- point: over both, nothing; over the portrait only, the follow; over the name only, the ClaraTarget macro. The report
-- names both.
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
local followUnitCalls = 0
function FollowUnit() followUnitCalls = followUnitCalls + 1 end
local shift = false
function IsShiftKeyDown() return shift end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end
local targetName, targetSurname = "Hatefury Felsworn", nil
local oldName = UnitName
function UnitName(u) if u == "target" then return targetName, targetSurname end return oldName(u) end
Constants = Constants or {}
Constants.CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " ", CHARACTERNAME_REALMNAME_SEPARATOR = "-" }

-- The target frame: its attributes (as SecureUnitButton_OnLoad leaves them, plus another addon's type1), the mouse
-- over its name or portrait
local overName, overPortrait, visible = false, true, true
local attrs = { ["*type1"] = "target", ["*type2"] = "menu", type1 = "spell", unit = "target" }
local sets = 0
TargetFrame = { IsVisible = function() return visible end,
  GetAttribute = function(_, k) return attrs[k] end,
  SetAttribute = function(_, k, v) assert(not S.inCombat, "SetAttribute in combat"); sets = sets + 1; attrs[k] = v end,
  TargetFrameContent = { TargetFrameContentMain = { Name = { IsMouseOver = function() return overName end } } },
  TargetFrameContainer = { Portrait = { IsMouseOver = function() return overPortrait end } } }

local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
if not ns.TargetFollowArmed then out("(no follow by the frame's click in this version)"); out(""); out("0 failure(s)"); return end
local now = 100
GetTime = function() return now end
M.timers = {}
local function Timers() local n = #(M.timers or {}) for _ = 1, n do M.RunTimer() end end
local function Rel(button) M.Fire("GLOBAL_MOUSE_UP", button) end
local function Body(name) local i = GetMacroIndexByName(name or "ClaraFollow") return i > 0 and macros[i].body or nil end

out("== a first plain left click on the portrait: the frame's next left click follows, from the next frame")
Rel("LeftButton")
check(attrs.type1 == "spell", "not at once (this release's own click targets first)")
M.RunTimer() -- (the next frame)
check(attrs.type1 == "macro" and attrs.macrotext1 == "/follow" and ns.TargetFollowArmed(), "then: type1 macro, /follow")
check(attrs["*type1"] == "target" and attrs["*type2"] == "menu", "its other clicks as they were")
now = now + 0.2
Rel("LeftButton") -- (the second: the frame's own click ran /follow)
check(followUnitCalls == 0, "FollowUnit never called (the game refuses it to an addon)")
check(ns:TargetMacroReport():find("followed (the target frame's own click", 1, true) ~= nil, "the report: followed")
Timers() -- (half a second later)
check(attrs.type1 == "spell" and attrs.macrotext1 == nil and not ns.TargetFollowArmed(), "then the frame as it was (the other addon's type1 back)")
now = now + 2
out("== a single click, nothing after: the frame given back")
Rel("LeftButton"); M.RunTimer()
check(attrs.type1 == "macro", "armed")
Timers()
check(attrs.type1 == "spell", "half a second later: as it was")
now = now + 2

out("== Shift + double left click: its first word in ClaraFollow, the frame left alone")
shift = true
sets = 0
Rel("LeftButton"); Timers(); now = now + 0.2; Rel("LeftButton"); Timers(); now = now + 2
check(Body() == "/follow Hatefury" and sets == 0, "ClaraFollow: " .. tostring(Body()) .. ", attributes set " .. sets)
check(macros[1].icon == 134400, "made with the question mark")
out("== Shift + double right click: its whole name (a player's surname too), the player's own lines kept")
macros[1].body = "/focus\n/f Somebody\n/script print('hi')"
targetName, targetSurname = "Xxjeanne", "Darkxx"
Rel("RightButton"); now = now + 0.2; Rel("RightButton"); now = now + 2
check(Body() == "/focus\n/follow Xxjeanne Darkxx\n/script print('hi')", "the /f line taken, /focus left: " .. Body():gsub("\n", " | "))
Rel("LeftButton"); now = now + 0.2; Rel("LeftButton"); now = now + 2
check(Body() == "/focus\n/follow Xxjeanne\n/script print('hi')", "Shift + double left: the first name: " .. Body():gsub("\n", " | "))
shift = false
targetName, targetSurname = "Hatefury Felsworn", nil
out("== a plain double right click, a middle one: nothing")
local before = Body()
Rel("RightButton"); now = now + 0.2; Rel("RightButton"); now = now + 2
Rel("MiddleButton"); now = now + 0.2; Rel("MiddleButton"); now = now + 2
check(Body() == before and attrs.type1 == "spell", "nothing written, the frame left alone")
out("== the box off: nothing")
ns:SetFollowClick(false)
Rel("LeftButton"); Timers()
check(attrs.type1 == "spell" and not ns:FollowClick(), "off: the frame left alone")
ns:SetFollowClick(true)
now = now + 2

out("== in a fight: the frame left alone; armed then a fight: undone as it starts")
S.inCombat = true
local ok = pcall(function() Rel("LeftButton"); Timers() end)
check(ok and attrs.type1 == "spell", "in a fight: not armed")
S.inCombat = false
now = now + 2
Rel("LeftButton"); M.RunTimer()
check(attrs.type1 == "macro", "armed")
M.Fire("PLAYER_REGEN_DISABLED")
check(attrs.type1 == "spell", "the fight starting: as it was")
S.inCombat = true; Timers(); S.inCombat = false
M.Fire("PLAYER_REGEN_ENABLED")
now = now + 2

out("== the spots: over both, nothing; the portrait only, the follow; the name only, ClaraTarget")
macros = {}
targetName = "Event Mob"
overName, overPortrait = true, true
Rel("LeftButton"); Timers(); now = now + 0.2; Rel("MiddleButton"); now = now + 0.2; Rel("MiddleButton"); now = now + 2
check(attrs.type1 == "spell" and Body("ClaraTarget") == nil, "over both (where they would overlap): nothing at all")
overName, overPortrait = true, false
Rel("LeftButton"); Timers(); now = now + 0.2; Rel("LeftButton"); now = now + 2
check(attrs.type1 == "spell" and Body("ClaraTarget") == "/tm 8\n/tar Event", "over the name only: ClaraTarget, the frame left alone: " .. tostring(Body("ClaraTarget")))
overName, overPortrait = false, true
Rel("LeftButton"); M.RunTimer()
check(attrs.type1 == "macro", "over the portrait only: armed")
Timers()
out("== the report")
local r = ns:TargetMacroReport()
check(r:find("follow on true", 1, true) and r:find("over the portrait 1", 1, true), r)
out("")
out(fails .. " failure(s)")
