-- A unit frame's tooltip of Clara's (GameFixes.lua, the frame under a chat): its owner carries the unit, so that the
-- addons reading the owner (Leatrix's class colors) find it when the tooltip itself gives no unit (a unit far away).
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local owner
GameTooltip = { _shown = false }
function GameTooltip:SetOwner(o) owner = o end
function GameTooltip:GetOwner() return owner end
function GameTooltip:SetUnit(u) self.unit = u return true end
function GameTooltip:Show() self._shown = true end
function GameTooltip:Hide() self._shown = false end
function GameTooltip:IsShown() return self._shown end
function GameTooltip:IsOwned(o) return owner == o end
function GameTooltip:AddLine() end
function GameTooltip_SetDefaultAnchor(tip, o) tip:SetOwner(o) end
S.class = "ROGUE"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
if not ns.ShowUnitTip then out("(no unit tooltip of Clara's in this version)"); out(""); out("0 failure(s)"); return end
local frame = CreateFrame("Button", "TargetFrame", UIParent)
ns.ShowUnitTip(frame, "target")
check(GameTooltip.unit == "target" and GameTooltip._shown, "the unit's tooltip shown")
check(owner ~= nil and owner ~= frame and owner.unit == "target", "its owner (Clara's) carries the unit: " .. tostring(owner and owner.unit))
ns.ShowUnitTip(frame, "party2")
check(owner.unit == "party2", "another unit: the owner's changed with it")
out("")
out(fails .. " failure(s)")
