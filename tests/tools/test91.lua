-- The world map left open when a quest window opens (GameFixes.lua): while the map shows, the quest window's
-- "pushable" layout setting is 1 (it stands beside the map instead of replacing it); back to the game's as it shuts
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

UIPanelWindows = UIPanelWindows or {}
UIPanelWindows.QuestFrame = { area = "left", pushable = 0 }
QuestFrame = CreateFrame("Frame", "QuestFrame", UIParent)
WorldMapFrame = CreateFrame("Frame", "WorldMapFrame", UIParent)
WorldMapFrame:Hide()
local writes = 0
function SetUIPanelAttribute(frame, name, value)
  writes = writes + 1
  frame:SetAttribute("UIPanelLayout-" .. name, value)
end
local function Pushable() return QuestFrame:GetAttribute("UIPanelLayout-pushable") end

local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
check(writes == 0, "map shut: the quest window's setting untouched")

out("== the map opens")
WorldMapFrame:Show()
check(Pushable() == 1, "the quest window may stand beside it (pushable 1)")
local n = writes
WorldMapFrame:Hide(); WorldMapFrame:Show()
check(Pushable() == 1, "shown again: still 1")

out("== the map shuts")
WorldMapFrame:Hide()
check(Pushable() == 0, "back to the game's own (0)")
n = writes
WorldMapFrame:Hide()
check(writes == n, "nothing written when nothing changes")
out(string.format("\n%d failure(s)", fails))
return fails
