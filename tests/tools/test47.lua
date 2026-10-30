-- The boxes over the game's target and focus frames (UnitBoxes.lua): the threat percent in a fight,
-- in Era's box, the game's own out of sight; the distance beside it (WeaponSwingTimer's bands),
-- the pair over the name bar; the option in the game's settings page; the focus too
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, mail = false, classicui = false } }

-- the game's frames: the name bar (ReputationColor) and its own threat box
local function GameFrame(name)
  local f = CreateFrame("Frame", name, UIParent)
  f:SetSize(232, 100)
  f.TargetFrameContent = CreateFrame("Frame", nil, f)
  local main = CreateFrame("Frame", nil, f.TargetFrameContent)
  local contextual = CreateFrame("Frame", nil, f.TargetFrameContent)
  f.TargetFrameContent.TargetFrameContentMain = main
  f.TargetFrameContent.TargetFrameContentContextual = contextual
  main.ReputationColor = main:CreateTexture(nil, "BACKGROUND")
  main.ReputationColor:SetSize(135, 20)
  main.ReputationColor:SetPoint("TOPRIGHT", f, "TOPRIGHT", -75, -25)
  contextual.NumericalThreat = CreateFrame("Frame", nil, contextual)
  return f
end
TargetFrame = GameFrame("TargetFrame")
FocusFrame = GameFrame("FocusFrame")

-- threat
local THREAT = {} -- [unit] = { tanking, status, raw, lead }
function UnitDetailedThreatSituation(_, unit)
  local t = THREAT[unit]
  if t then return t[1], t[2], nil, t[3] end
end
function UnitThreatPercentageOfLead(_, unit) return THREAT[unit] and THREAT[unit][4] end
function GetThreatStatusColor(status) return ({ [0] = { .69, .69, .69 }, { 1, 1, .47 }, { 1, .6, 0 }, { 1, 0, 0 } })[status][1],
  ({ [0] = { .69, .69, .69 }, { 1, 1, .47 }, { 1, .6, 0 }, { 1, 0, 0 } })[status][2], ({ [0] = { .69, .69, .69 }, { 1, 1, .47 }, { 1, .6, 0 }, { 1, 0, 0 } })[status][3] end
function UnitClassification() return "normal" end
local EXISTS = { target = true, focus = false }
local realExists = UnitExists
function UnitExists(u) if EXISTS[u] ~= nil then return EXISTS[u] end return realExists(u) end

-- WeaponSwingTimer's range (the module, its API in short)
local RANGE = {} -- [unit] = { short, key, r, g, b }
local rangeOn = true
local WST = {
  RangeBoxOn = function() return rangeOn end,
  RangeBand = function(unit) local r = RANGE[unit]; if r then return r[1], r[2], r[3], r[4], r[5] end end,
}

local ns = {}
S.class = "HUNTER"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
ns.WST = WST
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local function Run() while M.timers and #M.timers > 0 do M.RunTimer() end end
local function Boxes(frame)
  local list = {}
  for _, f in ipairs(M.frames) do
    if f._parent == frame.TargetFrameContent.TargetFrameContentContextual and f ~= frame.TargetFrameContent.TargetFrameContentContextual.NumericalThreat then
      list[#list + 1] = f
    end
  end
  return list[1], list[2]
end
local function Tick() for _ = 1, 15 do M.Frame(1 / 60) end end

-- out of combat: no threat; a hunter's distance
RANGE.target = { "8-15", "close", .95, .75, .1 }
M.Fire("PLAYER_TARGET_CHANGED")
Tick()
local threat, range = Boxes(TargetFrame)
check(threat and range, "two boxes on the target frame")
check(not threat:IsShown(), "no threat out of a fight")
check(range:IsShown() and range.text:GetText() == "8-15 yd", "the distance, with its unit: " .. tostring(range.text:GetText()))
check(range.fill._vc and math.abs(range.fill._vc[1] - .95) < .01, "in its band's color")
check(range.border._file == "Interface\\TargetingFrame\\NumericThreatBorder" and range.fill._file == "Interface\\TargetingFrame\\UI-StatusBar",
  "Era's threat box: its border, its fill")
local _, rel, _, x1 = threat:GetPoint(1)
local _, _, _, x2 = range:GetPoint(1)
check(rel == TargetFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor and x1 == -32 and x2 == 26.5 and math.floor(range:GetWidth() + .5) == 60,
  "the pair over the name bar (" .. tostring(x1) .. ", " .. tostring(x2) .. ")")

-- a fight: the threat percent, in its color; the game's own box out of sight
THREAT.target = { false, 1, 63.4, nil }
M.Fire("UNIT_THREAT_LIST_UPDATE", "target")
check(threat:IsShown() and threat.text:GetText() == "63%" and threat.fill._vc[2] == 1, "63%, in the threat color: " .. tostring(threat.text:GetText()))
check(TargetFrame.TargetFrameContent.TargetFrameContentContextual.NumericalThreat:GetAlpha() == 0, "the game's own box out of sight")
THREAT.target = { true, 3, 100, 415 }
M.Fire("UNIT_THREAT_SITUATION_UPDATE", "player")
check(threat.text:GetText() == "415%", "tanking: the lead, 415%")
-- a long band: no room for the unit
RANGE.target = { "35-100", "far", .35, .55, .9 }
Tick()
check(range.text:GetText():find("^35%-100") and range.text:GetStringWidth() <= 54, "a long band: within the fill (" .. tostring(range.text:GetText()) .. ")")
-- no band known (a friend, out of sight): no box
RANGE.target = nil
Tick()
check(not range:IsShown(), "no band: no box")

-- the focus too
EXISTS.focus = true
THREAT.focus = { false, 2, 20, nil }
RANGE.focus = { "0-5", "melee", .85, .2, .2 }
M.Fire("PLAYER_FOCUS_CHANGED")
Tick()
local fthreat, frange = Boxes(FocusFrame)
check(fthreat:IsShown() and fthreat.text:GetText() == "20%" and frange:IsShown() and frange.text:GetText() == "0-5 yd", "the focus: 20%, 0-5 yd")

-- the distance off (a warrior's default): the threat alone, in the game's place
rangeOn = false
ns.RefreshUnitBoxes()
local _, _, _, x3 = threat:GetPoint(1)
check(not range:IsShown() and not frange:IsShown() and x3 == 0, "distance off: the threat alone, centered")
rangeOn = true
ns.RefreshUnitBoxes()

-- nothing to read: the watch rests
EXISTS.target, EXISTS.focus = false, false
M.Fire("PLAYER_TARGET_CHANGED")
Tick()
local resting = true
for _, f in ipairs(M.frames) do
  if f._scripts and f._scripts.OnUpdate and f:IsShown() and debug.getinfo(f._scripts.OnUpdate, "S").short_src:find("UnitBoxes") then resting = false end
end
check(resting, "no target nor focus: its watch rests")
EXISTS.target = true

-- the game's settings page: the threat box off and on
THREAT.target = { false, 1, 50, nil }
M.Fire("PLAYER_TARGET_CHANGED")
check(threat:IsShown(), "back: 50%")
local page = ns.settingsPage or ns.SettingsPage
ns:SetThreatBox(false)
check(not threat:IsShown() and ClaraComboPointsDB.threatBox == false
  and TargetFrame.TargetFrameContent.TargetFrameContentContextual.NumericalThreat:GetAlpha() == 1, "off: no box, the game's own back")
ns:SetThreatBox(true)
check(threat:IsShown() and ClaraComboPointsDB.threatBox == nil and ns:ThreatBox(), "on again")

-- the attack speed (a hunter's): on the left, the three never past the name bar's right end
local SPEED = { target = 1.2 }
function UnitCanAttack(_, unit) return unit == "target" or unit == "focus" end
function UnitIsDead() return false end
function UnitAttackSpeed(unit) return SPEED[unit] end
local PLAYERS = {}
function UnitIsPlayer(unit) return PLAYERS[unit] or false end
function UnitPlayerControlled(unit) return PLAYERS[unit] or false end
local speedOn, flashOn, flashTime = true, true, 5
WST.SpeedBoxOn = function() return speedOn end
WST.SpeedFlash = function() return flashOn, flashTime end
WST.SPEED_FAST, WST.SPEED_SLOW = 1.2, 2.0
ns.lang = "enUS"
M.now = 2000
M.Fire("PLAYER_TARGET_CHANGED")
Tick()
local speedBox
for _, f in ipairs(M.frames) do
  if f._parent == TargetFrame.TargetFrameContent.TargetFrameContentContextual and f ~= threat and f ~= range
    and f ~= TargetFrame.TargetFrameContent.TargetFrameContentContextual.NumericalThreat and f.text and math.floor(f:GetWidth() + .5) == 49 then speedBox = f end
end
check(speedBox and speedBox:IsShown() and speedBox.text:GetText() == "1.2s", "the attack speed: " .. tostring(speedBox and speedBox.text:GetText()))
check(speedBox.fill._vc and speedBox.fill._vc[1] == 1 and speedBox.fill._vc[2] == .5, "1.2 s against an NPC: orange")
local _, _, _, sx = speedBox:GetPoint(1)
local _, _, _, tx = threat:GetPoint(1)
local _, _, _, rx = range:GetPoint(1)
check(rx + 30 == 67.5 and tx == rx - 30 - 4 - 24.5 and sx == tx - 49 - 4, "speed, threat, distance; the distance's right end on the bar's (" .. sx .. ", " .. tx .. ", " .. rx .. ")")
-- it pulses the first 5 seconds, then rests
local alphas = {}
for i = 1, 8 do M.now = M.now + .125; M.Frame(.125); alphas[#alphas + 1] = speedBox.glow:GetAlpha() end
local varied = false
for i = 2, #alphas do if math.abs(alphas[i] - alphas[1]) > .1 then varied = true end end
check(speedBox.glow._blend == "ADD" and varied, "pulsing")
M.now = M.now + 6; M.Frame(.016)
check(speedBox.glow:GetAlpha() == 0 and speedBox:GetScript("OnUpdate") == nil, "after 5 s: still")
-- slow: dark yellow, flashing; between: plain
SPEED.target = 2.4
Tick()
check(speedBox.text:GetText() == "2.4s" and speedBox.fill._vc[1] == .72 and speedBox:GetScript("OnUpdate") ~= nil, "2.4 s: dark yellow, flashing")
SPEED.target = 1.6
Tick()
check(speedBox.text:GetText() == "1.6s" and speedBox.fill._vc[1] == .5 and speedBox.glow:GetAlpha() == 0, "1.6 s: plain")
-- a player: no colors, no flash
PLAYERS.target = true
SPEED.target = 1.0
Tick()
check(speedBox.text:GetText() == "1.0s" and speedBox.fill._vc[1] == .5 and speedBox:GetScript("OnUpdate") == nil, "a player: plain, no flash")
PLAYERS.target = nil
-- the flash off: colors, no flash
flashOn = false
M.Fire("PLAYER_TARGET_CHANGED")
Tick()
check(speedBox.fill._vc[1] == 1 and speedBox:GetScript("OnUpdate") == nil, "flash off: orange, still")
flashOn = true
speedOn = false
ns.RefreshUnitBoxes()
check(not speedBox:IsShown(), "the attack speed off")
speedOn = true
ns.RefreshUnitBoxes()

-- a boss's swing timer: a mark across its name bar, from the hits seen on its target
local bossClass = "worldboss"
function UnitClassification(unit) return unit == "target" and bossClass or "normal" end
function UnitLevel() return 60 end
local realIsUnit = UnitIsUnit
function UnitIsUnit(a, b) if b == "targettarget" then return a == "player" end return realIsUnit(a, b) end
local bossOn, front = true, true
WST.BossSwing = function() return bossOn, 1, 0, 0, .8, front end
M.Fire("PLAYER_TARGET_CHANGED")
local main = TargetFrame.TargetFrameContent.TargetFrameContentMain
main.Name = main:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
SPEED.target = 2.0
M.now = 3000
M.Fire("UNIT_COMBAT", "player", "WOUND", "", 120, 1)
local mark
M.Frame(.016)
local function FindMark()
  for _, r in ipairs(M.regions) do if r._parent == main and r._color and r ~= main.ReputationColor then return r end end
end
mark = FindMark()
check(mark and mark:IsShown() and mark._color[1] == 1 and mark._color[2] == 0 and mark:GetAlpha() == .8 and mark._layer == "OVERLAY",
  "a hit on its target: the mark, red, 0.8, before the name")
M.now = M.now + 1
M.Frame(.016)
local _, rel2, _, mx = mark:GetPoint(1)
check(rel2 == main.ReputationColor and math.abs(mx - main.ReputationColor:GetWidth() / 2) < 3, "halfway through its 2 s swing: mid-bar (" .. tostring(mx) .. ")")
M.now = M.now + 2.5
M.Frame(.016)
check(not mark:IsShown(), "no swing seen since: gone")
front = false
ns.RefreshUnitBoxes()
M.Fire("UNIT_COMBAT", "player", "PARRY", "", 0, 1)
M.Frame(.016)
check(mark:IsShown() and mark._layer == "ARTWORK", "behind the name: under its layer")
M.Fire("UNIT_COMBAT", "party1", "WOUND", "", 50, 1)
check(true, "(a hit on someone else: not its swing)")
bossClass = "elite"
M.Fire("PLAYER_TARGET_CHANGED")
M.Frame(.016)
check(not mark:IsShown(), "not a boss: no mark")

-- French: meters
ns.lang = "frFR"
RANGE.target = { "8-15", "close", .95, .75, .1 }
Tick()
check(range.text:GetText() == "8-15 m", "in French, meters: " .. tostring(range.text:GetText()))
out("")
out(fails .. " failure(s)")
