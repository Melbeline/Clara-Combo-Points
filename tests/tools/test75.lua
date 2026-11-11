-- The minimap's tracking given back after a death (GameFixes.lua): at once when the game takes it, else at
-- the next movement key or world click (never a key bound to something else); not when the player picked another
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local dead = false
function UnitIsDeadOrGhost() return dead end
local TYPES = {
  { name = "Find Herbs", spellID = 2383, type = "spell", subType = -1, active = false },
  { name = "Find Minerals", spellID = 2580, type = "spell", subType = -1, active = false },
  { name = "Track Beasts", spellID = 1494, type = "spell", subType = 1, active = false },
  { name = "Repair", type = "other", subType = 2, active = true },
}
local needsPress = false   -- the game takes a tracking only on a key press or a click
local pressing = false
local calls = 0
C_Minimap = {
  GetNumTrackingTypes = function() return #TYPES end,
  GetTrackingInfo = function(i) local t = TYPES[i] return t and { name = t.name, spellID = t.spellID, type = t.type, subType = t.subType, active = t.active } end,
  SetTracking = function(i, on)
    calls = calls + 1
    if needsPress and not pressing then return end
    for _, t in ipairs(TYPES) do if t.type == "spell" then t.active = false end end -- (one at a time, as in vanilla)
    TYPES[i].active = on
    M.Fire("MINIMAP_UPDATE_TRACKING")
  end,
}
local bindings = { W = "MOVEFORWARD", ["1"] = "ACTIONBUTTON1", F5 = "" }
function GetBindingAction(key) return bindings[key] or "" end
function CreateKeyChordStringUsingMetaKeyState(key) return key end
local function Run() local n = 0 while M.timers and #M.timers > 0 and n < 200 do M.RunTimer() n = n + 1 end end
local function Later(dt) M.now = (M.now or 0) + (dt or 2) end
local function Catcher()
  for _, f in ipairs(M.frames) do
    if f._scripts and f._scripts.OnKeyDown and f._propagate and debug.getinfo(f._scripts.OnKeyDown, "S").source:find("GameFixes") then return f end
  end
end

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); Run()

out("== the game takes it at once")
TYPES[1].active = true; M.Fire("MINIMAP_UPDATE_TRACKING"); Run()
dead = true
TYPES[1].active = false; M.Fire("MINIMAP_UPDATE_TRACKING"); M.Fire("PLAYER_DEAD"); Run()
check(ClaraComboPointsDB.trackingLost ~= nil, "at death: Find Herbs kept to give back (saved for this character)")
M.Fire("PLAYER_ALIVE"); Run() -- (the release: a ghost)
check(not TYPES[1].active and calls == 0, "released, still a ghost: nothing tried")
dead = false; Later(); M.Fire("PLAYER_UNGHOST"); Run()
check(TYPES[1].active and calls == 1, "alive again: Find Herbs back on its own")
check(ClaraComboPointsDB.trackingLost == nil, "nothing left to give back")
check(TYPES[4].active, "the townsfolk tracking left as it was")

out("== the game takes it only on a press")
needsPress = true; calls = 0
Later(); TYPES[1].active = false; TYPES[3].active = true; M.Fire("MINIMAP_UPDATE_TRACKING"); Run()
dead = true; TYPES[3].active = false; M.Fire("MINIMAP_UPDATE_TRACKING"); M.Fire("PLAYER_DEAD"); Run()
dead = false; Later(); M.Fire("PLAYER_ALIVE"); Run()
check(not TYPES[3].active and calls == 1, "tried once at resurrection, not taken")
local catch = Catcher()
check(catch and catch:IsShown() and catch._propagate, "a frame hears the keys, each one passed on to the game")
Later(); pressing = true; M.Key(catch, "1"); pressing = false; Run()
check(not TYPES[3].active and calls == 1, "a key bound to a spell (action button 1): not used, its spell its own")
Later(); pressing = true; M.Key(catch, "W"); pressing = false; Run()
check(TYPES[3].active and calls == 2, "the next movement key: Track Beasts back (one press, one tracking)")
check(not catch:IsShown(), "nothing more to give back: the keys no longer heard")

out("== a world click, and another tracking picked")
Later(); dead = true; TYPES[3].active = false; M.Fire("MINIMAP_UPDATE_TRACKING"); M.Fire("PLAYER_DEAD"); Run()
dead = false; Later(); M.Fire("PLAYER_UNGHOST"); Run()
Later(); pressing = true; WorldFrame._scripts.OnMouseDown(WorldFrame, "RightButton"); pressing = false; Run()
check(TYPES[3].active, "a click in the world: back on")
Later(); dead = true; TYPES[3].active = false; M.Fire("MINIMAP_UPDATE_TRACKING"); M.Fire("PLAYER_DEAD"); Run()
dead = false; Later(); M.Fire("PLAYER_UNGHOST"); Run()
TYPES[2].active = true; M.Fire("MINIMAP_UPDATE_TRACKING"); Run() -- (the player picks Find Minerals)
local before = calls
Later(); pressing = true; M.Key(catch, "W"); pressing = false; Run()
check(calls == before and TYPES[2].active and not TYPES[3].active and ClaraComboPointsDB.trackingLost == nil,
  "another tracking picked by the player: theirs, nothing given back over it")

out("== a reload while dead")
Later(); TYPES[2].active = false; TYPES[1].active = true; M.Fire("MINIMAP_UPDATE_TRACKING"); Run()
dead = true; TYPES[1].active = false; M.Fire("MINIMAP_UPDATE_TRACKING"); M.Fire("PLAYER_DEAD"); Run()
local kept = ClaraComboPointsDB.trackingLost
check(kept ~= nil, "kept in the saved settings")
needsPress = false
out(string.format("\n%d failure(s)", fails))
return fails
