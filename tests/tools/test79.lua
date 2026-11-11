-- The bags above AtlasLoot (GameFixes.lua): while its window is shown, the bags a strata above its own; closed,
-- their own back
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local ticks = {}
C_Timer.NewTicker = function(_, fn) local t = { Cancel = function(self) self.off = true end } ticks[#ticks + 1] = { t = t, fn = fn } return t end
local function Tick() for _, k in ipairs(ticks) do if not k.t.off then k.fn() end end end
local bags = {}
for i = 1, 2 do local b = CreateFrame("Frame", "ContainerFrame" .. i, UIParent) b:SetFrameStrata("MEDIUM") b:Hide() bags[i] = b end
ContainerFrameCombinedBags = CreateFrame("Frame", "ContainerFrameCombinedBags", UIParent); ContainerFrameCombinedBags:SetFrameStrata("MEDIUM"); ContainerFrameCombinedBags:Hide()
function ContainerFrameUtil_EnumerateContainerFrames() local i = 0 return function() i = i + 1 if bags[i] then return i, bags[i] end end end
local loaded = {}
C_AddOns = C_AddOns or {}
local oldLoaded = C_AddOns.IsAddOnLoaded
C_AddOns.IsAddOnLoaded = function(n) if n == "AtlasLootClassic" then return loaded[n] end return oldLoaded and oldLoaded(n) end
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
local mine = 0
for _, k in ipairs(ticks) do if (debug.getinfo(k.fn, "S").source or ""):find("GameFixes") then mine = mine + 1 end end
check(mine == 0, "no AtlasLoot: nothing looked for")
loaded.AtlasLootClassic = true
M.Fire("ADDON_LOADED", "AtlasLootClassic")
local atlas = CreateFrame("Frame", "AtlasLoot_GUI-Frame", UIParent); atlas:SetFrameStrata("HIGH"); atlas:Hide()
Tick()
atlas:Show()
check(bags[1]:GetFrameStrata() == "DIALOG" and ContainerFrameCombinedBags:GetFrameStrata() == "DIALOG", "AtlasLoot open (HIGH): the bags a strata above it (" .. bags[1]:GetFrameStrata() .. ")")
bags[2]:Show()
check(bags[2]:GetFrameStrata() == "DIALOG", "a bag opened meanwhile: above it too")
atlas:Hide()
check(bags[1]:GetFrameStrata() == "MEDIUM" and bags[2]:GetFrameStrata() == "MEDIUM", "AtlasLoot closed: the bags' own strata back")
out(string.format("\n%d failure(s)", fails))
return fails
