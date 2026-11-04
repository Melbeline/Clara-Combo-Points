-- Names (Modules/Names, not in Light): surnames hidden on the target/focus/party frames, nameplates,
-- tooltips, pets' owners, chat; one's own name and surname = the game's settings; the box per place
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function readfile(p) local f = io.open(p, "rb"); if not f then return nil end local s = f:read("*a"); f:close(); return s end
if not readfile(ADDON_DIR .. "/Modules/Names/Names.lua") then out("(no Names on this branch)"); out(""); out("0 failure(s)"); return end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, mail = false, classicui = false, tullarange = false } }

-- the game's settings and console
local CVARS = { UnitNameOwn = "1", UnitSurnameOwn = "1", UnitSurnameOther = "1" }
local cvarWrites = {}
C_CVar = { GetCVar = function(n) return CVARS[n] end,
  SetCVar = function(n, v) CVARS[n] = tostring(v); cvarWrites[#cvarWrites + 1] = n .. "=" .. tostring(v) end }
C_Console = { GetAllCommands = function()
  return { { command = "UnitNameOwn" }, { command = "UnitSurnameOwn" }, { command = "UnitSurnameOther" }, { command = "nameplateShowAll" } }
end }

-- units
local UNITS = {
  player = { name = "Clara", player = true },
  target = { name = "Anna Lea", player = true },
  focus = { name = "Bram Stone", player = true },
  party1 = { name = "Cora Vale", player = true },
  nameplate1 = { name = "Dorn Ash", player = true },
  nameplate2 = { name = "Defias Pillager", player = false },
  pet = { name = "Big Wolf", player = false },
}
function UnitName(u) local x = UNITS[u]; return x and x.name end
function UnitIsPlayer(u) local x = UNITS[u]; return x and x.player or false end
function UnitExists(u) return UNITS[u] ~= nil end
local me = "target-is-not-me"
function UnitIsUnit(a, b) return a == b or (b == "player" and a == me) end
function UnitPlayerControlled(u) return u == "pet" end
function GetUnitName(u) return UNITS[u] and UNITS[u].name end
function UnitClassification() return "normal" end
function UnitLevel() return 10 end
function UnitCanAttack() return false end
function UnitIsDead() return false end

-- the game's unit frames (UnitFrame_Update writes the name), compact frames, tooltip, chat
local function Frame(globalName, unit)
  local f = CreateFrame("Frame", globalName, UIParent)
  f.unit = unit
  f.name = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  return f
end
TargetFrame, FocusFrame, PlayerFrame = Frame("TargetFrame", "target"), Frame("FocusFrame", "focus"), Frame("PlayerFrame", "player")
TargetFrame.totFrame = Frame(nil, "targettarget")
function UnitFrame_Update(self)
  if self.unit == "player" or (UnitIsUnit(self.unit, "player") and CVARS.UnitSurnameOwn == "0") then return end -- (Forever's bug)
  self.name:SetText(GetUnitName(self.unit))
end
function CompactUnitFrame_UpdateName(frame) frame.name:SetText(GetUnitName(frame.unit)) end
local party = Frame(nil, "party1")
local plate, npcPlate = Frame(nil, "nameplate1"), Frame(nil, "nameplate2")

UNITNAME_TITLE_PET = "%s's Pet"
local postCalls = {}
Enum = Enum or {}
Enum.TooltipDataType = { Unit = 2 }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) postCalls[#postCalls + 1] = fn end }
local tipLines = {}
for i = 1, 4 do tipLines[i] = UIParent:CreateFontString("GameTooltipTextLeft" .. i, "ARTWORK", "GameFontNormal"); _G["GameTooltipTextLeft" .. i] = tipLines[i] end
local tipUnit
function GameTooltip:GetUnit() return UNITS[tipUnit] and UNITS[tipUnit].name, tipUnit end
function GameTooltip:NumLines() return 3 end
local function ShowTip(unit, line1, line2)
  tipUnit = unit
  tipLines[1]:SetText(line1); tipLines[2]:SetText(line2 or "")
  for _, fn in ipairs(postCalls) do fn(GameTooltip) end
end
function ChatFrame1:TransformMessages(pred, fn)
  for i, m in ipairs(M.chat) do if pred(m) then M.chat[i] = fn(m) end end
end

local ns = {}
S.class = "HUNTER"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
for _ = 1, 3 do M.Frame(1 / 60) end
while M.timers and #M.timers > 0 do M.RunTimer() end

check(ns:QolRuns("names") and ns.Names ~= nil, "the module runs")
UnitFrame_Update(TargetFrame)
check(TargetFrame.name:GetText() == "Anna", "target frame: Anna (" .. tostring(TargetFrame.name:GetText()) .. ")")
UnitFrame_Update(FocusFrame)
check(FocusFrame.name:GetText() == "Bram", "focus frame: Bram")
UNITS.targettarget = { name = "Cora Vale", player = true }
UnitFrame_Update(TargetFrame.totFrame)
check(TargetFrame.totFrame.name:GetText() == "Cora", "its target too: Cora")
CompactUnitFrame_UpdateName(party)
check(party.name:GetText() == "Cora", "party/raid frames: Cora")
CompactUnitFrame_UpdateName(plate)
CompactUnitFrame_UpdateName(npcPlate)
check(plate.name:GetText() == "Dorn" and npcPlate.name:GetText() == "Defias Pillager", "nameplates: Dorn; an NPC kept whole")

-- a box off: the full name back at once, and kept
local sw = ns.qolSwitches.names
check(sw and #sw == 10, "ten boxes on its page of the Improvements tab")
ns.Names.SetHidden("target", false)
check(TargetFrame.name:GetText() == "Anna Lea", "target box off: Anna Lea back (" .. tostring(TargetFrame.name:GetText()) .. ")")
UnitFrame_Update(TargetFrame)
check(TargetFrame.name:GetText() == "Anna Lea", "and kept")
ns.Names.SetHidden("target", true)
check(TargetFrame.name:GetText() == "Anna", "on again: Anna")

-- tooltips
ShowTip("target", "Anna Lea")
check(tipLines[1]:GetText() == "Anna", "a player's tooltip: Anna (" .. tostring(tipLines[1]:GetText()) .. ")")
ShowTip("target", "Sergeant Anna Lea")
check(tipLines[1]:GetText() == "Sergeant Anna", "with a title: Sergeant Anna")
ShowTip("pet", "Big Wolf", "Anna Lea's Pet")
check(tipLines[1]:GetText() == "Big Wolf" and tipLines[2]:GetText() == "Anna's Pet", "a pet: its name whole, its owner Anna (" .. tostring(tipLines[2]:GetText()) .. ")")
ns.Names.SetHidden("tooltip", false)
ShowTip("target", "Anna Lea")
check(tipLines[1]:GetText() == "Anna Lea", "tooltip box off: whole")

-- chat
local line = "|Hplayer:Anna Lea-Realm:12:CHANNEL:1|h[|cffc79c6eAnna Lea|r]|h: hello Bram Stone"
ChatFrame1:AddMessage(line)
local shown = M.chat[#M.chat]
check(shown == "|Hplayer:Anna Lea-Realm:12:CHANNEL:1|h[|cffc79c6eAnna|r]|h: hello Bram Stone",
  "chat: [Anna], the link still to Anna Lea (" .. shown .. ")")
check(ns.NamesShortLinks("|Hplayer:Bram Stone-Far|h[Bram Stone-Far]|h") == "|Hplayer:Bram Stone-Far|h[Bram-Far]|h", "another realm: [Bram-Far]")

-- over the heads: the other players' surname setting off, given back when unticked
check(CVARS.UnitSurnameOther == "0" and ClaraNamesDB.savedCVars.UnitSurnameOther == "1", "over the heads: UnitSurnameOther off, its value kept")
ns.Names.SetHidden("overhead", false)
check(CVARS.UnitSurnameOther == "1" and ClaraNamesDB.savedCVars == nil, "unticked: given back")

-- one's own: the game's settings themselves
check(sw[9].get() == false and sw[10].get() == false, "my surname and my name shown (the game's settings)")
sw[9].set(true)
check(CVARS.UnitSurnameOwn == "0", "hide my surname: the game's own setting turned off")
me = "target"
UNITS.target = { name = "Clara", player = true }
TargetFrame.name:SetText("Bram Stone") -- (the last unit's name, left by the game)
UnitFrame_Update(TargetFrame)
check(TargetFrame.name:GetText() == "Clara", "targeting yourself: your name, not the last one's (" .. tostring(TargetFrame.name:GetText()) .. ")")
sw[10].set(true)
check(CVARS.UnitNameOwn == "0" and sw[10].get() == true, "hide my name over my head: the game's setting")
CVARS.UnitSurnameOwn = "1"
M.Fire("CVAR_UPDATE", "UnitSurnameOwn", "1")
check(sw[9].get() == false, "turned back on in the game's options: the box follows")

-- its page
local category
for _, c in ipairs(M.settingsCategories) do if c.name == "Names" then category = c end end
check(category ~= nil and category == ns.namesCategory, "its own entry in Esc > Options > AddOns: Names")
M.ShowSettingsPage(category)
local boxes = 0
for _, c in ipairs(M.frames) do if c._parent == category.frame and c._kind == "CheckButton" then boxes = boxes + 1 end end
check(boxes == 10, "ten boxes on it (" .. boxes .. ")")
ns:OpenQol("names")
check(M.openedCategory == category:GetID(), "opened from the Improvements tab")
out("")
out(fails .. " failure(s)")
