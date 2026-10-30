local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local ns = {}
S.class = "DEATHKNIGHT" -- not a class of World of Warcraft: Forever
-- fake LibSharedMedia with one extra font and one duplicate name
-- (a LibStub newer than the addon's own, so that it stays: the libraries register in it)
local lsm = { List = function() return { "Arial Narrow", "Expressway" } end,
              Fetch = function(_, _, n) return "Interface\\AddOns\\SharedMedia\\" .. n .. ".ttf" end }
LibStub = setmetatable({ minor = 99, libs = { ["LibSharedMedia-3.0"] = lsm }, minors = {} }, {
  __call = function(self, name, silent) return self.libs[name] end })
function LibStub:NewLibrary(major, minor)
  local old = self.libs[major]
  if old and (self.minors[major] or 0) >= minor then return nil end
  self.libs[major] = old or {}
  self.minors[major] = minor
  return self.libs[major], old and self.minors[major]
end
function LibStub:GetLibrary(major, silent) return self.libs[major] end
M.LoadAddon(ADDON_DIR, ns)
ClaraComboPointsDB = { scale = "bad", colors = { cp1 = { r = "x" } }, outline = "WHAT", fontSize = 500 }
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
check(not ns.hud:IsShown(), "HUD hidden for a class without a tab")
check(not M.eventFrames[ns.hud] , "no gameplay events registered")
M.Fire("PLAYER_ENTERING_WORLD", true, false) -- (the quiet chat at login waits for it, for every class)
-- What the features for every character listen to, none of them a combat event: the layer and
-- the instances (Layers.lua: a target, the mouseover, a loading screen), the Interact Key's icons
-- (InteractKey.lua: a key binding or a setting changed), quest progress on nameplates
-- (QuestPlates.lua: a nameplate shown or hidden, the quest log changed), UnitScan (UnitScan.lua: the
-- group's targets, the sightings heard), the screenshots (Screenshots.lua: a level, a boss fight, the zone)
FEATURE_EVENTS = { PLAYER_ENTERING_WORLD = true, PLAYER_TARGET_CHANGED = true, UPDATE_MOUSEOVER_UNIT = true,
  UPDATE_BINDINGS = true, CVAR_UPDATE = true, NAME_PLATE_UNIT_ADDED = true, NAME_PLATE_UNIT_REMOVED = true,
  QUEST_LOG_UPDATE = true, UNIT_TARGET = true, CHAT_MSG_CHANNEL = true, CHAT_MSG_ADDON = true, PLAYER_LEVEL_UP = true,
  ENCOUNTER_START = true, INSTANCE_ENCOUNTER_ENGAGE_UNIT = true, ENCOUNTER_END = true, ZONE_CHANGED_NEW_AREA = true }
local registered = 0
for f in pairs(M.eventFrames) do
  for e in pairs(f._events or {}) do
    if e ~= "PLAYER_LOGOUT" and not FEATURE_EVENTS[e] then registered = registered + 1 end -- (the AceDB library saves at logout)
  end
end
check(registered == 0, "event frame idle once in the world (" .. registered .. " events)")
check(ns.db.scale == 1 and ns.db.colors.cp1.r == 1 and ns.db.outline == "OUTLINE" and ns.db.fontSize == 17, "corrupt saved values repaired")
SlashCmdList.CLARACOMBOPOINTS("")
check(ClaraComboPointsOptions:IsShown(), "options still open on other classes")
local names = {}
for _, f in ipairs(ns:GetFonts()) do names[f.name] = (names[f.name] or 0) + 1 end
check(names["Expressway"] == 1 and names["Arial Narrow"] == 1, "LibSharedMedia fonts merged without duplicates")
out(string.format("\n%d failure(s)", fails))
return fails
