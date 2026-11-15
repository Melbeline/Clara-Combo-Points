-- Clara never calls the game's ContainerFrameUtil_EnumerateContainerFrames (it makes its list the first time it is
-- called: from Clara, in Clara's name, and every bag window built from it then, the items' right-click refused): the
-- bags above AtlasLoot and the mail's grey items read the bag windows by their names (ns.ContainerFrames)
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
ClaraComboPointsDB = { qol = setmetatable({ mail = true }, { __index = function() return false end }) }
local called = 0
function ContainerFrameUtil_EnumerateContainerFrames() called = called + 1 return ipairs({}) end
NUM_CONTAINER_FRAMES = 6
for i = 1, 6 do _G["ContainerFrame" .. i] = CreateFrame("Frame", "ContainerFrame" .. i, UIParent) end
ContainerFrameCombinedBags = CreateFrame("Frame", "ContainerFrameCombinedBags", UIParent)
for i = 1, 6 do
  local f = _G["ContainerFrame" .. i]
  f.Items = {}
  function f:EnumerateValidItems() return ipairs(self.Items) end
end
S.class = "ROGUE"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
-- AtlasLoot loaded and its window shown: the bags lifted over it; the bags shown and hidden; the mailbox shut
C_AddOns = C_AddOns or {}
C_AddOns.IsAddOnLoaded = function(n) return n == "AtlasLootClassic" end
AtlasLootDefaultFrame = CreateFrame("Frame", "AtlasLootDefaultFrame", UIParent)
M.Fire("ADDON_LOADED", "AtlasLootClassic")
for _ = 1, 3 do M.Tick() end
ContainerFrame1:Hide(); ContainerFrame1:Show()
M.Fire("PLAYER_REGEN_ENABLED")
M.Fire("MAIL_SHOW"); M.Fire("MAIL_CLOSED")
out("== the game's bag enumerator never called by Clara")
check(called == 0, "never called (" .. called .. ")")
local list = ns.ContainerFrames()
check(#list == 7 and list[1] == ContainerFrame1 and list[6] == ContainerFrame6 and list[7] == ContainerFrameCombinedBags,
  "Clara's own: the bag windows by their names (" .. #list .. ")")
out(string.format("\n%d failure(s)", fails))
return fails
