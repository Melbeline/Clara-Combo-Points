-- FriendsXP (Modules/FriendsXP): the group members with Clara send each other their level, experience and rested
-- experience (an addon message, at most one every 5 seconds; "H" asks everyone's); the experience bar's tooltip gets,
-- under its first line, yourself then each member heard in the group's order: the name in the class's color and the
-- level, "xp / max (%)", and under it the rested experience still to come ("amount (%)" of the level, never cut at
-- 150%: 180% with the Legacy talent); the game's lines after them, kept; not twice; nobody heard: nothing; a member
-- gone from the group: forgotten.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
RAID_CLASS_COLORS = RAID_CLASS_COLORS or {}
RAID_CLASS_COLORS.HUNTER = { r = 0.67, g = 0.83, b = 0.45 }
RAID_CLASS_COLORS.WARLOCK = { r = 0.53, g = 0.53, b = 0.93 }
RAID_CLASS_COLORS.PRIEST = { r = 1, g = 1, b = 1 }
function BreakUpLargeNumbers(n)
  local s = tostring(math.floor(n))
  local r = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (r:gsub("^,", ""))
end
local sent = {}
C_ChatInfo.SendAddonMessage = function(prefix, text, channel) sent[#sent + 1] = { prefix = prefix, text = text, channel = channel } return 0 end
C_ChatInfo.RegisterAddonMessagePrefix = function() return true end
local names = { player = "Elle Woods", party1 = "Xxjeanne Darkxx", party2 = "Lia Moon" }
local classes = { player = "HUNTER", party1 = "WARLOCK", party2 = "PRIEST" }
function UnitClass(u) return "x", classes[u] end
function UnitXP() return 26071 end
function UnitXPMax() return 90700 end
local oldLevel = UnitLevel
function UnitLevel(u) if u == "player" then return 40 end return oldLevel(u) end
function GetXPExhaustion() return 30806 end
S.group = "party"
function GetNumSubgroupMembers() return 2 end
function IsInRaid() return false end

ClaraComboPointsDB = { qol = setmetatable({ friendsxp = true }, { __index = function() return false end }) }
local ns = {}
S.class = "HUNTER"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
ns.FullName = function(_, unit) return names[unit] end
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
local F = ns.FriendsXP
if not F then out("(no FriendsXP in this version)"); out(""); out("0 failure(s)"); return end
local function Timers() local n = #(M.timers or {}) for _ = 1, n do M.RunTimer() end end
local now = 100
GetTime = function() return now end

out("== in a group at login: everyone's asked for, ours sent")
M.Fire("PLAYER_ENTERING_WORLD", true, false)
Timers(); Timers()
check(sent[1] and sent[1].text == "H" and sent[1].channel == "PARTY" and sent[1].prefix == "ClaraFriendsXP", "asked: H")
check(sent[2] and sent[2].text == "X^40^26071^90700^30806^HUNTER", "ours: " .. tostring(sent[2] and sent[2].text))
out("== the experience moving in a fight: one message, 5 seconds apart at most")
local before = #sent
UnitXP = function() return 26500 end
for _ = 1, 5 do M.Fire("PLAYER_XP_UPDATE", "player") end
check(#(M.timers or {}) == 1, "one wait for five changes")
now = now + 5; Timers()
check(#sent == before + 1 and sent[#sent].text:find("^X%^40%^26500%^"), "one message: " .. tostring(sent[#sent].text))
UnitXP = function() return 26071 end

out("== heard from the members")
F.Heard("X^41^50000^94300^24000^WARLOCK", "PARTY", "Xxjeanne Darkxx-Forever")
F.Heard("X^39^38000^84500^0^PRIEST", "PARTY", "Lia Moon")
F.Heard("X^41^1^2^3^ROGUE", "WHISPER", "Somebody")
F.Heard("X^41^1^2^3^ROGUE", "PARTY", "Elle Woods") -- (ours, back)
local count = 0
for _ in pairs(F.members) do count = count + 1 end
check(count == 2, "two members heard (a whisper, ours: left out)")
before = #sent
F.Heard("H", "PARTY", "Lia Moon")
now = now + 5; Timers()
check(sent[#sent].text:find("^X%^40%^26071%^") ~= nil and #sent == before + 1, "asked by a member: ours sent again")

out("== the experience bar's tooltip")
local function FS()
  local o = { c = { 1, 1, 1 }, shown = true }
  function o:GetText() return self.t end
  function o:SetText(t) self.t = t end
  function o:GetTextColor() return self.c[1], self.c[2], self.c[3] end
  function o:IsShown() return self.shown end
  function o:CanWordWrap() return self.wrap end
  return o
end
local tip = { lines = 0 }
function tip:GetName() return "FXPTip" end
function tip:NumLines() return self.lines end
function tip:IsShown() return true end
function tip:Show() self.shown = (self.shown or 0) + 1 end
function tip:ClearLines()
  for i = 1, self.lines do _G["FXPTipTextLeft" .. i].t = nil; _G["FXPTipTextRight" .. i].t = nil; _G["FXPTipTextRight" .. i].shown = false end
  self.lines = 0
end
function tip:AddLine(t, r, g, b, wrap)
  self.lines = self.lines + 1
  local i = self.lines
  _G["FXPTipTextLeft" .. i] = _G["FXPTipTextLeft" .. i] or FS()
  _G["FXPTipTextRight" .. i] = _G["FXPTipTextRight" .. i] or FS()
  local l, rr = _G["FXPTipTextLeft" .. i], _G["FXPTipTextRight" .. i]
  l.t, l.c, l.wrap = t, { r or 1, g or 1, b or 1 }, wrap
  rr.t, rr.shown = nil, false
end
function tip:AddDoubleLine(lt, rt, lr, lg, lb, rr, rg, rb)
  self:AddLine(lt, lr, lg, lb)
  local r = _G["FXPTipTextRight" .. self.lines]
  r.t, r.shown, r.c = rt, true, { rr or 1, rg or 1, rb or 1 }
end
local function Game()
  tip:ClearLines()
  tip:AddLine("26,071 / 90,700 (29%)", 1, 1, 1)
  tip:AddLine("Rested  xp: 30,806 - 34%", 1, 0.82, 0)
  tip:AddLine("200% of normal experience gained from monsters.", 1, 1, 1, true)
end
local function L_(i) return _G["FXPTipTextLeft" .. i].t, _G["FXPTipTextRight" .. i].shown and _G["FXPTipTextRight" .. i].t or nil end
Game()
F.AddTo(tip)
check(tip.lines == 3 + 2 + 2 + 1, "under the first line: you (2 lines), Xxjeanne (2), Lia (1, no rested): " .. tip.lines)
local t1 = L_(1)
check(t1 == "26,071 / 90,700 (29%)", "the first line kept first")
local l2, r2 = L_(2)
check(l2:find("Elle Woods", 1, true) and l2:find("|cffaad372", 1, true) and l2:find("40", 1, true) and r2 == "26,071 / 90,700 (29%)",
  "you: the hunter's green, the level, xp / max (%): " .. tostring(l2) .. " | " .. tostring(r2))
local l3, r3 = L_(3)
check(l3:find("Rested", 1, true) and r3 == "30,806 (34%)", "your rested: " .. tostring(r3))
local l4, r4 = L_(4)
check(l4:find("Xxjeanne Darkxx", 1, true) and l4:find("|cff8787ed", 1, true) and r4 == "50,000 / 94,300 (54%)", "Xxjeanne: the warlock's purple: " .. tostring(l4) .. " | " .. tostring(r4))
local _, r5 = L_(5)
check(r5 == "24,000 (25%)", "her rested: " .. tostring(r5))
local l6, r6 = L_(6)
check(l6:find("Lia Moon", 1, true) and r6 == "38,000 / 84,500 (45%)", "Lia: no rested line")
local l7, l8 = L_(7), L_(8)
check(l7 == "Rested  xp: 30,806 - 34%" and l8 == "200% of normal experience gained from monsters." and _G.FXPTipTextLeft8.wrap,
  "the game's lines after, as they were (the long one still wrapped)")
F.AddTo(tip)
check(tip.lines == 8, "hovered again, the same build: not twice")
out("== rested past 150% (the Legacy talent: up to 180%): never cut")
F.Heard("X^41^50000^94300^169740^WARLOCK", "PARTY", "Xxjeanne Darkxx")
Game(); F.AddTo(tip)
local _, r = L_(5)
check(r == "169,740 (180%)", "180%: " .. tostring(r))
out("== nobody heard, or alone: nothing added")
wipe(F.members)
Game(); F.AddTo(tip)
check(tip.lines == 3, "nobody heard: the game's tooltip as it was")
F.Heard("X^41^50000^94300^24000^WARLOCK", "PARTY", "Xxjeanne Darkxx")
names.party1 = "Someone Else"
M.Fire("GROUP_ROSTER_UPDATE")
check(next(F.members) == nil, "a member gone from the group: forgotten")
out("== the report")
check(ns:FriendsXPReport():find("FriendsXP:", 1, true) ~= nil, ns:FriendsXPReport())
out("")
out(fails .. " failure(s)")
