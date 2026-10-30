-- idTip's and Solo Raid Frame's own addons enabled: they run this session, the built-in ones take over
-- from the next reload (their addons turned off for the character); idTip's settings carried over.
-- Solo Raid Frame with the game's frame made after Clara loads: hooked at login.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false, tullarange = false, names = false,
  tooltipanchor = false, mail = false, reverseengineering = false } }
local loaded, disabled = { idTip = true }, {}
C_AddOns = C_AddOns or {}
C_AddOns.IsAddOnLoaded = function(name) return loaded[name] == true end
C_AddOns.DoesAddOnExist = function(name) return name == "idTip" or name == "SoloRaidFrameNV" end
C_AddOns.GetAddOnEnableState = function(name) return disabled[name] and 0 or 2 end
C_AddOns.IsAddOnLoadable = function(name) return not disabled[name] end
C_AddOns.EnableAddOn = function(name) disabled[name] = nil end
C_AddOns.DisableAddOn = function(name) disabled[name] = true end
C_AddOns.SaveAddOns = function() end
idTipConfig = { enabled = true, version = 2, spellEnabled = false, itemEnabled = true, iconEnabled = false }
disabled.SoloRaidFrameNV = true -- (that one is installed, not enabled)

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
-- the game's raid-style party frame, made after Clara's files ran
CompactPartyFrame = CreateFrame("Frame", "CompactPartyFrame", UIParent)
CompactPartyFrame:Hide()
function CompactPartyFrame:UpdateVisibility() self:SetShown(IsInGroup() and true or false) end
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false)

out("== idTip's own addon running")
check(ns:QolState("idtip") == "standalone" and ns:QolTakesOver("idtip"), "it runs this session; the built-in one takes over")
check(disabled.idTip == true, "turned off for the character, from the next reload")
check(ClaraIdTipDB == nil, "nothing of the built-in one meanwhile")
M.Fire("PLAYER_LOGOUT")
check(type(ClaraIdTipDB) == "table" and ClaraIdTipDB.spellEnabled == false and ClaraIdTipDB.iconEnabled == false
  and ClaraIdTipDB.itemEnabled == true and ClaraIdTipDB.unitEnabled == true, "its settings carried over at logout (the rest: defaults)")

out("== Solo Raid Frame, its frame made late")
check(ns:QolRuns("soloraidframe"), "runs (its own addon not enabled)")
check(CompactPartyFrame:IsShown(), "hooked at login, and shown at once (solo)")
S.group = "raid"; CompactPartyFrame:UpdateVisibility()
S.group = nil; CompactPartyFrame:UpdateVisibility()
check(CompactPartyFrame:IsShown(), "after a group: shown again")

out("")
out(fails .. " failure(s)")
