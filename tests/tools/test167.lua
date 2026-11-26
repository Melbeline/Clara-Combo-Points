-- Bestial Wrath (Modules/PetFeed): its icon on the pet frame as the Feed Pet one, in its place when there is no feeding,
-- beside it when there is; from the cast (the player's own, read in a fight too): 18 s counting down; from the aura
-- while the game shows it: its own times; in a fight (auras hidden): the countdown goes on, gone as it ends; the
-- game's duration object when the aura's times are secret (its numbers drawn by the game); no pet: gone; the box off:
-- nothing; not Bestial Wrath: nothing.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
ClaraComboPointsDB = { qol = setmetatable({ petfeed = true }, { __index = function() return false end }) }
PetFrame = CreateFrame("Button", "PetFrame", UIParent)
PetFrame:SetSize(120, 49)
PetFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -200)
local petUp, wrathOn, feeding, hidden, secretTimes = true, false, false, false, false
local oldUE = UnitExists
function UnitExists(u) if u == "pet" then return petUp end return oldUE(u) end
local now = 1000
function GetTime() return now end
C_Secrets = C_Secrets or {}
C_Secrets.ShouldAurasBeSecret = function() return hidden end
C_UnitAuras.GetAuraDataByIndex = function(unit, i)
  if unit == "pet" and i == 1 and feeding then
    return { spellId = 1539, name = "Feed Pet Effect", duration = 20, expirationTime = now + 15, icon = 132165, auraInstanceID = 9 }
  end
end
C_UnitAuras.GetAuraDataBySpellName = function(unit, name)
  if unit ~= "pet" or hidden or not wrathOn or name ~= "Bestial Wrath" then return nil end
  if secretTimes then return { name = name, duration = M.Secret(18), expirationTime = M.Secret(1018), auraInstanceID = 21 } end
  return { name = name, duration = 18, expirationTime = 1012, auraInstanceID = 21, icon = 132127 }
end
local durationAsked
C_UnitAuras.GetAuraDuration = function(unit, id) durationAsked = id return { _start = 1000, _duration = 18 } end
local oldName = C_Spell.GetSpellName
C_Spell.GetSpellName = function(id) if id == 19574 then return "Bestial Wrath" end return oldName(id) end
S.class = "HUNTER"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local wrath, feed = ns.PetWrathIcon, ns.PetFeedIcon
if not wrath then out("(no Bestial Wrath icon in this version)"); out(""); out("0 failure(s)"); return end
local function Text() return wrath.text._text end
out("== cast: shown in the Feed Pet icon's place, 18 s counting down")
check(not wrath:IsShown(), "hidden at first")
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 19574)
local p, rel, _, x, y = wrath:GetPoint(1)
check(wrath:IsShown() and rel == PetFrame and x == 44 and y == -37, "shown, under the pet frame's bars: " .. tostring(x) .. "," .. tostring(y))
M.Frame(0.2)
check(Text() == "18", "its seconds: " .. tostring(Text()))
out("== in a fight, auras hidden: the countdown goes on")
hidden = true
M.Fire("UNIT_AURA", "pet")
now = 1010.2
M.Frame(0.2)
check(wrath:IsShown() and Text() == "8", "still there: " .. tostring(Text()))
now = 1018.5
M.Frame(0.2)
check(not wrath:IsShown(), "18 s later: gone")
hidden = false
out("== the aura shown by the game: its own times")
now = 1000
wrathOn = true
M.Fire("UNIT_AURA", "pet")
M.Frame(0.2)
check(wrath:IsShown() and Text() == "12", "from the aura: " .. tostring(Text()))
out("== the Feed Pet icon shown too: Bestial Wrath beside it")
feeding = true
M.Fire("UNIT_AURA", "pet")
p, rel = wrath:GetPoint(1)
check(feed:IsShown() and rel == feed and p == "LEFT", "beside the Feed Pet icon")
feeding = false
M.Fire("UNIT_AURA", "pet")
p, rel = wrath:GetPoint(1)
check(not feed:IsShown() and rel == PetFrame, "the feeding over: back in its place")
out("== secret times: the game's duration object, its numbers drawn by the game")
secretTimes = true
M.Fire("UNIT_AURA", "pet")
check(durationAsked == 21 and wrath:IsShown() and Text() == "", "the duration asked for its aura, our seconds left out: " .. tostring(durationAsked) .. " " .. tostring(wrath:IsShown()) .. " [" .. tostring(Text()) .. "]")
secretTimes = false
out("== the aura gone, the pet gone: gone")
wrathOn = false
M.Fire("UNIT_AURA", "pet")
check(not wrath:IsShown(), "no aura: gone")
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 19574)
petUp = false
M.Fire("UNIT_PET", "player")
check(not wrath:IsShown(), "no pet: gone")
petUp = true
out("== another spell, the box off: nothing")
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3", 1978)
check(not wrath:IsShown(), "another spell: nothing")
local sw
for _, s in ipairs(ns.qolSwitches.petfeed or {}) do if s.label == "PF_SW_BESTIAL" then sw = s end end
check(sw and sw.get() and ns.L.PF_SW_BESTIAL, "its box on the card, on by default")
sw.set(false)
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-4", 19574)
check(not wrath:IsShown(), "off: nothing")
sw.set(true)
out("")
out(fails .. " failure(s)")
