-- Pet feeding (Modules/PetFeed): a hunter's Feed Pet Effect on the pet as an icon on the game's pet frame, under its
-- bars, its seconds counting down, gone as it ends; its mover (its card's box): dragged spot kept, right-click back;
-- a secret aura (in a fight): kept as it was, no error; not a hunter, or ClassicUI's own: nothing
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
ClaraComboPointsDB = { qol = setmetatable({ petfeed = true }, { __index = function() return false end }) }
PetFrame = CreateFrame("Button", "PetFrame", UIParent)
PetFrame:SetSize(120, 49)
PetFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -200)
local petUp, feeding, secret = true, false, false
local oldUE = UnitExists
function UnitExists(u) if u == "pet" then return petUp end return oldUE(u) end
local now = 1000
function GetTime() return now end
C_UnitAuras.GetAuraDataByIndex = function(unit, i, filter)
  if unit ~= "pet" then return nil end
  if i == 1 and feeding then
    return { spellId = secret and M.Secret(1539) or 1539, name = "Feed Pet Effect", duration = 20, expirationTime = 1015,
      icon = 132165, auraInstanceID = 9 }
  end
end
S.class = "HUNTER"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local feed, mover = ns.PetFeedIcon, ns.PetFeedMover
out("== the pet fed: its icon under the pet frame's bars, its seconds")
check(ns:QolRuns("petfeed") and feed ~= nil and not feed:IsShown(), "made, hidden while the pet is not fed")
local p, rel, rp, x, y = feed:GetPoint(1)
check(rel == PetFrame and p == "TOPLEFT" and x == 44 and y == -37, "under the bars: " .. tostring(x) .. "," .. tostring(y))
feeding = true
M.Fire("UNIT_AURA", "pet")
check(feed:IsShown() and feed.icon:GetTexture() == 132165, "fed: shown, the effect's own icon")
M.Frame(0.2)
check(feed.text._text == "15", "its seconds: " .. tostring(feed.text._text))
now = 1010.5
M.Frame(0.2)
check(feed.text._text == "5", "counting down: " .. tostring(feed.text._text))
now = 1016
M.Frame(0.2)
check(not feed:IsShown(), "ended: gone")
out("== a secret aura (in a fight): kept as it was, no error")
now = 1000
M.Fire("UNIT_AURA", "pet")
check(feed:IsShown(), "fed again")
secret = true
local ok, e = pcall(M.Fire, "UNIT_AURA", "pet")
check(ok and feed:IsShown(), "secret: no error, kept" .. (ok and "" or (": " .. tostring(e))))
secret = false
out("== moved: its card's box, dragged, kept; right-click: back")
local sw = ns.qolSwitches.petfeed
check(sw and sw[1].label == "PF_SW_MOVE", "its card's box")
sw[1].set(true)
check(mover:IsShown(), "the mover shown")
ns.sv.petFeed.x, ns.sv.petFeed.y = 130, -10
sw[1].set(true)
p, rel, rp, x, y = feed:GetPoint(1)
check(x == 130 and y == -10, "its spot kept: " .. tostring(x) .. "," .. tostring(y))
mover:GetScript("OnMouseUp")(mover, "RightButton")
p, rel, rp, x, y = feed:GetPoint(1)
check(x == 44 and y == -37 and ns.sv.petFeed.x == nil, "right-click: back to its own spot")
sw[1].set(false)
check(not mover:IsShown(), "put away")
out("== ClassicUI's own: this one aside")
ns.ClassicUIRuns = true
M.Fire("UNIT_AURA", "pet")
check(not feed:IsShown(), "hidden where ClassicUI runs")
ns.ClassicUIRuns = nil
out(string.format("\n%d failure(s)", fails))
return fails
