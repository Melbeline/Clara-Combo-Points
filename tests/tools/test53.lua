-- Fishing (Fishing.lua): one key casts Fishing, then while the line is out it is the game's Interact
-- Key (one press, one action); the game's interact settings set while fishing and given back
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, mail = false, classicui = false, tullarange = false,
  names = false, tooltipanchor = false } }

local CVARS = { SoftTargetInteract = "1", SoftTargetInteractRange = "10", SoftTargetInteractArc = "0",
  SoftTargetIconGameObject = "0", SoftTargetIconInteract = "1" }
C_CVar = { GetCVar = function(n) return CVARS[n] end, SetCVar = function(n, v) CVARS[n] = tostring(v) end }
local overrides = {}
function SetOverrideBinding(owner, prio, key, command) overrides[key] = command end
function ClearOverrideBindings() wipe(overrides) end
function GetBindingKey(command) if command == "CLICK ClaraFishingButton:LeftButton" then return "F" end end
C_Spell = C_Spell or {}
local NAMES = { [7620] = "Fishing", [133] = "Fireball" }
C_Spell.GetSpellName = function(id) return NAMES[id] end

local ns = {}
S.class = "MAGE"; S.locale = "enUS"
S.knownSpells = { [7620] = true }
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")

local fish = ClaraFishingButton
check(fish and fish:GetAttribute("type") == "spell" and fish:GetAttribute("spell") == "Fishing", "its button casts Fishing")
check(_G["BINDING_NAME_CLICK ClaraFishingButton:LeftButton"] == "Fish / Reel in (one press, one action)", "its key in the game's key bindings")
M.casts = {}
fish:Click("LeftButton")
check(#M.casts == 1 and M.casts[1] == "Fishing", "the key: one cast")

M.Fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 7620)
check(overrides.F == "INTERACTTARGET" and overrides.BUTTON2 == nil, "the line out: the same key is the Interact Key")
check(CVARS.SoftTargetInteract == "3" and CVARS.SoftTargetInteractRange == "20" and CVARS.SoftTargetInteractArc == "1"
  and CVARS.SoftTargetIconGameObject == "1", "the game's interact settings as its gamepad mode's, for the keyboard")
check(ClaraComboPointsDB.fishingCVars and ClaraComboPointsDB.fishingCVars.SoftTargetInteractRange == "10", "the former ones kept")
M.Fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "guid", 7620)
check(next(overrides) == nil, "reeled in (or the line gone): the key casts again")
check(CVARS.SoftTargetInteract == "1" and CVARS.SoftTargetInteractRange == "10" and CVARS.SoftTargetInteractArc == "0"
  and ClaraComboPointsDB.fishingCVars == nil, "the settings given back")

M.Fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 133)
check(next(overrides) == nil, "another channel: nothing")

M.Fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 7620)
check(overrides.F == "INTERACTTARGET" and overrides.BUTTON2 == nil, "the right click left to the camera")
M.Fire("PLAYER_REGEN_DISABLED")
check(next(overrides) == nil, "a fight: back to normal")

CVARS.SoftTargetInteractRange = "30"
M.Fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 7620)
check(CVARS.SoftTargetInteractRange == "30", "a longer reach of one's own: kept")
M.Fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "guid", 7620)

out("")
out(fails .. " failure(s)")
