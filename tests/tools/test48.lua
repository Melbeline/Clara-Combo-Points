-- ClassicUI's frames (branch with ClassicUI): Clara's boxes in ClassicUI's art beside its threat percent
-- (Modules/ClassicUI/Units/ClaraUnitBoxes.lua over a stand-in of ClassicUI), Clara's own boxes not shown there
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function readfile(p) local f = io.open(p, "rb"); if not f then return nil end local s = f:read("*a"); f:close(); return s end
local SRC = readfile(ADDON_DIR .. "/Modules/ClassicUI/Units/ClaraUnitBoxes.lua")
if not SRC then out("(no ClassicUI on this branch)"); out(""); out("0 failure(s)"); return end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, mail = false, classicui = false } }
local function GameFrame(name)
  local f = CreateFrame("Frame", name, UIParent)
  f:SetSize(232, 100)
  f.TargetFrameContent = CreateFrame("Frame", nil, f)
  local main = CreateFrame("Frame", nil, f.TargetFrameContent)
  local contextual = CreateFrame("Frame", nil, f.TargetFrameContent)
  f.TargetFrameContent.TargetFrameContentMain = main
  f.TargetFrameContent.TargetFrameContentContextual = contextual
  main.ReputationColor = main:CreateTexture(nil, "BACKGROUND")
  contextual.NumericalThreat = CreateFrame("Frame", nil, contextual)
  return f
end
TargetFrame = GameFrame("TargetFrame")
FocusFrame = GameFrame("FocusFrame")
function UnitDetailedThreatSituation() return false, 1, nil, 40 end
function GetThreatStatusColor() return 1, 1, .47 end
function UnitClassification() return "normal" end
function UnitCanAttack(_, unit) return unit == "target" or unit == "focus" end
function UnitIsDead() return false end
function UnitAttackSpeed(unit) if unit == "target" then return 1.1 end end
function UnitIsPlayer() return false end

-- a stand-in for ClassicUI: its unit frames on, its threat box, the name placement
local threatBox = CreateFrame("Frame", nil, TargetFrame)
threatBox:SetPoint("BOTTOM", TargetFrame, "TOP", -30, -26)
local placedName = {}
local UF = { active = true, THREAT_BOX_X = -30, THREAT_BOX_Y = -26, BAR_W = 119 }
function UF.On() return true end
function UF.ThreatBox(unit) return unit == "target" and threatBox or nil end
function UF.ThreatShown(unit) return false end
function UF.PlaceTargetName(unit) placedName[#placedName + 1] = unit end
local cui = { UF = UF, db = { threatNumber = true } }
local texSet = {}
function cui.SetTex(t, key) t:SetTexture("CUI:" .. key); texSet[key] = (texSet[key] or 0) + 1 end
function cui.NewFrame(kind, name, parent) return CreateFrame(kind, name, parent) end

local RANGE = { target = { "8-15", "close", .95, .75, .1 } }
local rangeOn, speedOn = true, true
S.target = { hostile = true, name = "Murloc" }
local ns = {}
S.class = "HUNTER"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
ns.ClassicUIRuns, ns.ClassicUIPrivate = true, cui
assert(loadstring(SRC, "@ClaraUnitBoxes.lua"))("ClaraComboPoints", ns)
ns.WST = { RangeBoxOn = function() return rangeOn end, SpeedBoxOn = function() return speedOn end,
  SpeedFlash = function() return true, 5 end, SPEED_FAST = 1.2, SPEED_SLOW = 2.0,
  BossSwing = function() return true, 1, 1, 1, .9, true end,
  RangeBand = function(unit) local r = RANGE[unit]; if r then return r[1], r[2], r[3], r[4], r[5] end end }
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
for _ = 1, 15 do M.Frame(1 / 60) end

local speed, range
for _, f in ipairs(M.frames) do
  if f._parent == TargetFrame and f ~= threatBox and f.text then
    if math.floor(f:GetWidth() + .5) == 60 then range = f else speed = f end
  end
end
check(range and range:IsShown() and range.text:GetText() == "8-15 yd", "the distance on ClassicUI's target frame: " .. tostring(range and range.text:GetText()))
check(speed and speed:IsShown() and speed.text:GetText() == "1.1s" and speed.fill._vc and speed.fill._vc[1] == 1,
  "the attack speed, orange: " .. tostring(speed and speed.text:GetText()))
check(texSet.threatBorder == 4 * 2 and texSet.statusBar == 2 * 2,
  "in ClassicUI's art, target and focus, the distance's border in three: " .. tostring(texSet.threatBorder) .. ", " .. tostring(texSet.statusBar))
local _, _, _, sx, sy = speed:GetPoint(1)
local _, _, _, tx = threatBox:GetPoint(1)
local _, _, _, rx = range:GetPoint(1)
check(rx + 30 == -30 + 59.5 and tx == rx - 30 - 4 - 24.5 and sx == tx - 49 - 4 and sy == -26,
  "speed, threat, distance over the name box, its right end kept (" .. sx .. ", " .. tx .. ", " .. rx .. ")")
check(UF.ThreatShown("target") == true and placedName[1] == "target", "the name steps up for them")
local contextual = TargetFrame.TargetFrameContent.TargetFrameContentContextual
local own = 0
for _, f in ipairs(M.frames) do if f._parent == contextual and f ~= contextual.NumericalThreat and f:IsShown() then own = own + 1 end end
check(own == 0, "Clara's own boxes not shown on ClassicUI's frame")
-- both off: the threat percent back in its place, the boxes gone, the name down
rangeOn, speedOn = false, false
ns.RefreshUnitBoxes()
local _, _, _, tx2 = threatBox:GetPoint(1)
check(not range:IsShown() and not speed:IsShown() and tx2 == -30 and UF.ThreatShown("target") == false,
  "both off: threat back at -30, the boxes gone")
out("")
out(fails .. " failure(s)")
