-- The Legacy window opened on its Legacy Tree page (LegacyTree.lua): the game's window (Blizzard_LegacySystem, loaded
-- on demand) shows its Progress Track page first; with Clara, its tree page as it opens (as its tab picks it), each
-- time; the challenges (opened from an achievement: the game picks their page just after) kept; the box off: the
-- game's own page.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local callbacks = {}
EventRegistry = { RegisterCallback = function(_, event, fn, owner) callbacks[event] = callbacks[event] or {}; table.insert(callbacks[event], { fn, owner }) end,
  TriggerEvent = function(_, event, ...) for _, c in ipairs(callbacks[event] or {}) do c[1](c[2], ...) end end }

local ns = {}
S.class = "HUNTER"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
if not ns.LegacyTreeOnShow then out("(no Legacy tree page in this version)"); out(""); out("0 failure(s)"); return end

-- The game's window, as its addon makes it (its pages, its tabs' event)
LegacySystemFrame = CreateFrame("Frame", "LegacySystemFrame", UIParent)
local f = LegacySystemFrame
f.Pages = {}
for i = 1, 3 do f.Pages[i] = CreateFrame("Frame", nil, f) end
function f:SelectPage(id) self.currentPage = id; for i, p in ipairs(self.Pages) do p:SetShown(i == id) end end
EventRegistry:RegisterCallback("Legacy.SelectPage", function(_, id) f:SelectPage(id) end, f)
f:SelectPage(1)
f:Hide()
M.Fire("ADDON_LOADED", "Blizzard_LegacySystem")
local function Toggle() if f:IsShown() then f:Hide() else f:Show() end end -- (ToggleLegacySystemUI: ToggleFrame)

out("== the Legacy button")
Toggle()
check(f.currentPage == 3 and f.Pages[3]:IsShown() and not f.Pages[1]:IsShown(), "opened: the Legacy Tree page")
EventRegistry:TriggerEvent("Legacy.SelectPage", 1)
Toggle(); Toggle()
check(f.currentPage == 3, "another page picked, shut, opened again: the tree again")
out("== the challenges, from an achievement")
f:Hide()
f:Show(); EventRegistry:TriggerEvent("Legacy.SelectPage", 2) -- (ShowChallenges: ShowUIPanel, then its page)
check(f.currentPage == 2, "their page kept")
out("== the box off")
f:Hide(); f:SelectPage(1)
ns:SetLegacyTree(false)
Toggle()
check(f.currentPage == 1 and ClaraComboPointsDB.legacyTree == false, "the game's page")
ns:SetLegacyTree(true)
check(ns:LegacyTree() and ClaraComboPointsDB.legacyTree == nil, "on again (by default)")
out("")
out(fails .. " failure(s)")
