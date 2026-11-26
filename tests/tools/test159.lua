-- Pet feeding's floating numbers (Modules/PetFeed/PetFeedText.lua): each happiness tick of Feed Pet Effect rises over
-- the pet frame as "+8"; the last one, cut short as happiness tops out, as what it really gave ("+3.75"); the game's
-- two words on a tick (its energize, its happiness power) in either order; another energize (focus) not shown; where
-- the power cannot be read, the energize while the pet is fed; the zone moved (/petfeed, its card's boxes), kept;
-- the numbers turned off; rising and fading, gone; not a hunter: nothing.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
ClaraComboPointsDB = { qol = setmetatable({ petfeed = true }, { __index = function() return false end }) }
function CombatFeedback_OnCombatEvent() end -- (the game's number on a unit frame's portrait)
COMBATLOG = { AddMessage = function() end } -- (the combat log's window, Blizzard_CombatLog)
C_AddOns = C_AddOns or {}
local isLoaded = C_AddOns.IsAddOnLoaded
C_AddOns.IsAddOnLoaded = function(name) if name == "Blizzard_CombatLog" then return true, true end return isLoaded and isLoaded(name) end
local oldUN = UnitName
function UnitName(u) if u == "pet" then return "The Rake" end return oldUN(u) end
PetFrame = CreateFrame("Button", "PetFrame", UIParent)
PetFrame:SetSize(120, 49)
PetFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -200)
local petUp, feeding = true, false
local happy, happyMax, unreadable = 500000, 1050000, false
local oldUE, oldUP, oldUPM = UnitExists, UnitPower, UnitPowerMax
function UnitExists(u) if u == "pet" then return petUp end return oldUE(u) end
function UnitPower(u, p) if u == "pet" and p == 27 then if unreadable then return M.Secret(happy) end return happy end return oldUP(u, p) end
function UnitPowerMax(u, p) if u == "pet" and p == 27 then return happyMax end return oldUPM(u, p) end
C_UnitAuras.GetAuraDataByIndex = function(unit, i)
  if unit == "pet" and i == 1 and feeding then
    return { spellId = 1539, name = "Feed Pet Effect", duration = 20, expirationTime = 1015, icon = 132165, auraInstanceID = 9 }
  end
end
S.class = "HUNTER"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
if not ns.PetFeedShow then out("(no floating numbers in this version)"); out(""); out("0 failure(s)"); return end

local function Timers() local n = #(M.timers or {}) for _ = 1, n do M.RunTimer() end end
-- one tick: the game's energize and the happiness power, in the order asked
local function Tick(amount, gain, powerFirst)
  ns.PetFeedLastShown = nil
  local function power() happy = math.min(happyMax, happy + gain) M.Fire("UNIT_POWER_UPDATE", "pet", "HAPPINESS") end
  local function combat() M.Fire("UNIT_COMBAT", "pet", "ENERGIZE", "", amount, 1) end
  if powerFirst then power() if amount then combat() end else if amount then combat() end power() end
  Timers()
  local shown = ns.PetFeedLastShown
  if issecretvalue(shown) then return "secret:" .. tostring(M.reveal(shown)) end
  return shown
end

out("== Format: as the combat log tells it")
local F = ns.PetFeedFormat
check(F(8) == "8" and F(3.75) == "3.75" and F(3.5) == "3.5" and F(2.999) == "3" and F(0.25) == "0.25", "8, 3.75, 3.5, 3, 0.25")

out("== a whole tick: +8")
feeding = true
check(Tick(8, 8000) == "+8", "shown: " .. tostring(ns.PetFeedLastShown))
check(math.abs((ns.sv.petFeed.ratio or 0) - 0.001) < 1e-9, "one point of happiness power learned: " .. tostring(ns.sv.petFeed.ratio))
check(Tick(8, 8000, true) == "+8", "the power told first: the same")
out("== the last tick, cut short at the top: what it really gave")
happy = happyMax - 3750
M.Fire("UNIT_PET", "player") -- (its happiness as it stands, read)
check(Tick(8, 8000) == "+3.75", "+3.75: " .. tostring(ns.PetFeedLastShown))
check(Tick(8, 8000, true) == nil, "already full: nothing gained, nothing shown")
out("== another energize on the pet (its focus): not happiness, not shown")
happy = 300000
check(Tick(50, 0) == nil, "focus +50: nothing")
out("== the power cannot be read: the game's number while the pet is fed")
unreadable = true
check(Tick(8, 8000) == "+8", "fed: +8")
feeding = false
check(Tick(25, 0) == nil, "not fed: nothing")
unreadable, feeding = false, true
M.Fire("UNIT_POWER_UPDATE", "pet", "HAPPINESS"); Timers()

out("== WoW 12: the game's number a secret: shown as the game gives it, while the pet is fed")
feeding = true
check(Tick(M.Secret(13.6), 13600) == "secret:+13.6", "fed, its happiness up: the game's number: " .. tostring(ns.PetFeedLastShown))
local r0 = ns:PetFeedTextReport()
check(not issecretvalue(r0) and r0:find("secret 1", 1, true) ~= nil, "the report says so, never the secret: " .. r0)
unreadable = true
check(Tick(M.Secret(13.6), 13600) == "secret:+13.6", "its power unreadable too, fed: shown")
feeding = false
check(Tick(M.Secret(50), 0) == nil, "not fed (its focus): nothing")
out("== the game's own number on the pet's portrait (its UNIT_COMBAT, seen from the game's side)")
feeding = true
ns.PetFeedLastShown = nil
CombatFeedback_OnCombatEvent(PetFrame, "ENERGIZE", "", M.Secret(0.7), 1); Timers()
check(issecretvalue(ns.PetFeedLastShown) and M.reveal(ns.PetFeedLastShown) == "+0.7", "fed: the portrait's number shown: " .. tostring(M.reveal(ns.PetFeedLastShown)))
ns.PetFeedLastShown = nil
CombatFeedback_OnCombatEvent(PetFrame, "WOUND", "", M.Secret(30), 1); Timers()
check(ns.PetFeedLastShown == nil, "a hit on the pet: nothing")
ns.PetFeedLastShown = nil
CombatFeedback_OnCombatEvent(PlayerFrame or UIParent, "ENERGIZE", "", M.Secret(5), 1); Timers()
check(ns.PetFeedLastShown == nil, "another frame's number: nothing")
ns.PetFeedLastShown = nil
CombatFeedback_OnCombatEvent(PetFrame, M.Secret("ENERGIZE"), "", M.Secret(0.7), 1); Timers()
check(M.reveal(ns.PetFeedLastShown) == "+0.7", "its kind unreadable, fed: shown")
feeding = false
ns.PetFeedLastShown = nil
CombatFeedback_OnCombatEvent(PetFrame, M.Secret("WOUND"), "", M.Secret(30), 1); Timers()
check(ns.PetFeedLastShown == nil, "its kind unreadable, not fed: nothing")
feeding = true
local rep = ns:PetFeedTextReport()
check(rep:find("the portrait's own numbers 4", 1, true) and rep:find("WOUND 1", 1, true) and rep:find("feedback ok", 1, true)
  and rep:find("UNIT_COMBAT ok", 1, true), "the report: what the game told\n" .. rep)

out("== the combat log's own line, where the game lets it be read")
ns.PetFeedLastShown = nil
COMBATLOG:AddMessage("|cffffffff03:22:36>|r Your |Hspell:1539:0|h|cff71d5ffFeed Pet Effect|r|h energized |Hunit:Pet-0-1|hThe Rake|h 0.7.", 1, 1, 1); Timers()
check(ns.PetFeedLastShown == "+0.7", "read: its number, +0.7 (" .. tostring(ns.PetFeedLastShown) .. ")")
ns.PetFeedLastShown = nil
COMBATLOG:AddMessage("Your Feed Pet Effect energized The Rake 13.6.", 1, 1, 1); Timers()
check(ns.PetFeedLastShown == "+13.6", "+13.6 (" .. tostring(ns.PetFeedLastShown) .. ")")
ns.PetFeedLastShown = nil
COMBATLOG:AddMessage("Bob's Feed Pet Effect energized Fluffy 8.", 1, 1, 1); Timers()
check(ns.PetFeedLastShown == nil, "another hunter's pet: nothing")
ns.PetFeedLastShown = nil
COMBATLOG:AddMessage("|Kq12|k", 1, 1, 1); Timers()
check(ns.PetFeedLastShown == nil, "a protected line: nothing (counted)")
COMBATLOG:AddMessage("Your Arcane Shot hit Boar 22.", 1, 1, 1); Timers()
out("== the same line by the game's event (COMBAT_LOG_MESSAGE): another addon in the window's place changes nothing")
ns.PetFeedLastShown = nil
M.Fire("COMBAT_LOG_MESSAGE", "Your Feed Pet Effect energized The Rake 4.25.", 1, 1, 1, 0); Timers()
check(ns.PetFeedLastShown == "+4.25", "by its event: +4.25 (" .. tostring(ns.PetFeedLastShown) .. ")")
ns.PetFeedLastShown = nil
M.Fire("COMBAT_LOG_MESSAGE", "Your Feed Pet Effect energized The Rake 8.", 1, 1, 1, 1); Timers()
check(ns.PetFeedLastShown == nil, "a line filled back (the log refiltered): nothing")
ns.PetFeedLastShown = nil
M.Fire("COMBAT_LOG_MESSAGE", "Your Feed Pet Effect energized The Rake 2.5.", 1, 1, 1, 0)
COMBATLOG:AddMessage("Your Feed Pet Effect energized The Rake 2.5.", 1, 1, 1); Timers()
check(ns.PetFeedLastShown == "+2.5", "the same line both ways: shown once")
local lr = ns:PetFeedTextReport()
check(lr:find("the combat log's lines: by its event 2, by its window 6 (protected 1, secret 0, readable 7; Feed Pet Effect on the pet 5", 1, true)
  and lr:find("the last line read: Your Feed Pet Effect energized The Rake 2.5.", 1, true), "the report: " .. lr)

out("== its auras hidden (a fight): fed while the effect read last has time left")
feeding = true
M.Fire("UNIT_AURA", "pet")
check(ns.PetFeedOn() == true, "fed, read")
S.secretAuras = true
check(ns.PetFeedOn() == true, "hidden, time left: fed")
check(Tick(M.Secret(13.6), 0) == "secret:+13.6", "a tick then: shown")
GetTime = function() return 2000 end
check(ns.PetFeedOn() == nil, "hidden, its time over: cannot tell")
GetTime = function() return M.now or 0 end
S.secretAuras = false
unreadable, feeding = false, true
M.Fire("UNIT_POWER_UPDATE", "pet", "HAPPINESS"); Timers()

out("== rising, fading, gone")
local item
check(Tick(8, 8000) == "+8", "a tick")
for _, f in ipairs(M.frames) do if f.label and f.sparks and f:IsShown() then item = f end end
check(item ~= nil and #item.sparks == 3, "its number and three sparkles")
M.Frame(0.6)
local _, _, _, _, y = item:GetPoint(1)
check(item:IsShown() and y and y > 10 and item:GetAlpha() > 0.5, "risen, still seen: " .. tostring(y))
local shown = 0
for _, s in ipairs(item.sparks) do if (s:GetAlpha() or 0) > 0 then shown = shown + 1 end end
check(shown >= 1, "its sparkles twinkling: " .. shown)
M.Frame(0.6); M.Frame(0.6)
check(not item:IsShown(), "gone after its time")

out("== the zone: /petfeed unlocks it, its card's box follows; dragged spot kept; right-click back; /petfeed locks")
local zone, mover = ns.PetFeedTextZone, ns.PetFeedTextMover
local p, rel, rp, x, yy = zone:GetPoint(1)
check(rel == PetFrame and p == "CENTER" and rp == "TOPLEFT" and x == 26 and yy == 6, "over the portrait: " .. tostring(x) .. "," .. tostring(yy))
local sw = ns.qolSwitches.petfeed
local swText, swMove
for _, s in ipairs(sw) do if s.label == "PF_SW_TEXT" then swText = s elseif s.label == "PF_SW_TEXT_MOVE" then swMove = s end end
check(swText and swMove and ns.L.PF_SW_TEXT and ns.L.PF_SW_TEXT_MOVE, "its card's two boxes, named")
check(swText.get() == true and swMove.get() == false, "on, locked by default")
SlashCmdList.CLARAPETFEED("")
check(mover:IsShown() and swMove.get() == true, "/petfeed: unlocked, the box ticked")
ns.sv.petFeed.textX, ns.sv.petFeed.textY = 80, 40
ns.PetFeedTextApply()
p, rel, rp, x, yy = zone:GetPoint(1)
check(x == 80 and yy == 40, "its spot kept: " .. tostring(x) .. "," .. tostring(yy))
mover._scripts.OnMouseUp(mover, "RightButton")
p, rel, rp, x, yy = zone:GetPoint(1)
check(x == 26 and yy == 6 and ns.sv.petFeed.textX == nil, "right-click: back to its own spot")
SlashCmdList.CLARAPETFEED("")
check(not mover:IsShown() and swMove.get() == false, "/petfeed again: locked")
swMove.set(true)
check(mover:IsShown(), "its card's box: unlocked")
swMove.set(false)
check(not mover:IsShown(), "and locked")
out("== the numbers turned off (its card's box)")
swText.set(false)
check(Tick(8, 8000) == nil, "off: nothing shown: " .. tostring(ns.PetFeedLastShown) .. " " .. tostring(ns.sv.petFeed.text))
swText.set(true)
check(Tick(8, 8000) == "+8", "on again")
out("== the mouse report says what the last tick was")
local r = ns:PetFeedTextReport()
check(r:find("the game's number 8", 1, true) and r:find("happiness gained 8000", 1, true), r)

out("")
out(fails .. " failure(s)")
