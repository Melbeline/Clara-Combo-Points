-- WoW 12.1.7 / WoW Forever's 1.60.1 hotfix: the realm, server and spawn in creatures' GUIDs hidden (scrambled).
-- idTip still shows a creature's NPC ID (its own part, the others not read). The layer in the clock's tooltip:
-- read as before while the copies are copies; scrambled (more than four new copies in five minutes on one map),
-- "hidden by the game", never a wrong layer, the copies kept dropped, the verdict kept for this game build;
-- in a dungeon, each entry counted (entered again or not can no longer be told); dungeons reset in a row are not
-- taken for scrambling
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "71000", "Nov 25 2026", 16001 end
ClaraComboPointsDB = { qol = setmetatable({ idtip = true }, { __index = function() return false end }) }

-- idTip's tooltip (as test100)
local tip = GameTooltip
tip._lines = {}
function tip:GetName() return "GameTooltip" end
function tip:NumLines() return #self._lines end
local function Cell(side, i)
  local name = "GameTooltipText" .. side .. i
  _G[name] = _G[name] or { GetText = function(self) return self.text end, SetText = function(self, t) self.text = t end }
  return _G[name]
end
function tip:AddDoubleLine(l, r)
  table.insert(self._lines, tostring(l) .. "\t" .. tostring(r))
  local n = #self._lines
  Cell("Left", n):SetText(tostring(l)); Cell("Right", n):SetText(tostring(r))
end
local postCalls = {}
TooltipDataProcessor = { AllTypes = "ALL", AddTooltipPostCall = function(kind, fn) table.insert(postCalls, { kind, fn }) end }
local function Process(data)
  for i = 1, #tip._lines do Cell("Left", i):SetText(nil); Cell("Right", i):SetText(nil) end
  tip._lines = {}
  tip:AddLine("Kobold Vermin")
  for _, pc in ipairs(postCalls) do if pc[1] == "ALL" or pc[1] == data.type then pc[2](tip, data) end end
  return table.concat(tip._lines, " | ")
end
function tip:ProcessInfo() end

-- the layer's world: the units' GUIDs, the place, the clock's tooltip, the nameplates
local guids, instance = {}, { name = "Elwynn", kind = "none", map = 0 }
function UnitGUID(u) if u == "player" then return "Player-1-00000001" end return guids[u] end
function GetInstanceInfo() return instance.name, instance.kind, 0, "", 5, 0, false, instance.map end
function UnitIsPlayer(u) return false end
function GameTime_UpdateTooltip() GameTooltip:AddLine("Time Info") end
local plates = {}
C_NamePlate = { GetNamePlates = function() local t = {} for i, u in ipairs(plates) do t[i] = { namePlateUnitToken = u } end return t end }
RESET_INSTANCES = "Reset all instances"

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local function Run() while M.timers and #M.timers > 0 do M.RunTimer() end end
Run()
local function Clock() GameTooltip:SetOwner(UIParent); tip._lines = {}; GameTime_UpdateTooltip(); return table.concat(GameTooltip._lines, " | ") end
local function InstanceTip()
  local root = MenuUtil.CreateFrame()
  local reset = root:CreateButton(RESET_INSTANCES)
  for _, fn in ipairs(M.menuModifiers.MENU_UNIT_SELF or {}) do fn(UIParent, root, {}) end
  if not reset.tooltip then return "" end
  GameTooltip:SetOwner(UIParent); tip._lines = {}
  reset.tooltip(GameTooltip, reset)
  return table.concat(GameTooltip._lines, " | ")
end

out("== idTip: a creature's NPC ID, whatever the hidden parts")
local t = Process({ type = 2, guid = "Creature-0-4395-0-25-299-0000ABC" })
check(t:find("NPC ID\t299", 1, true) or t:find("299", 1, true), "today's GUID: 299 (" .. t .. ")")
t = Process({ type = 2, guid = "Creature-0-8f3a1c-0-q7z-299-zz91kq0" })
check(t:find("299", 1, true), "its server, copy and spawn scrambled (not numbers): 299 still (" .. t .. ")")
t = Process({ type = 2, guid = "Vehicle-0-x-y-z-1234-w" })
check(t:find("1234", 1, true), "a vehicle: its id")
t = Process({ type = 2, guid = "Player-1234-0ABCDEF" })
check(not t:find("1234", 1, true), "a player: no NPC ID")
t = Process({ type = 2, guid = "BattlePet-0-0000123456" })
check(not t:find("123456", 1, true), "a battle pet: no NPC ID")
local ok = pcall(Process, { type = 2, guid = M.Secret("Creature-0-1-2-3-299-5") })
check(ok, "a secret GUID: no error")

out("== the layer while the copies are copies")
check(Clock():find("Layer: unknown", 1, true), "none seen: unknown")
guids.target = "Creature-0-4395-0-25-299-0000ABC"
M.Fire("PLAYER_TARGET_CHANGED")
check(Clock():find("Layer 1", 1, true), "one copy: Layer 1")
guids.target = nil
guids.mouseover = "Creature-0-4395-0-12-80-0000DEF"
M.Fire("UPDATE_MOUSEOVER_UNIT")
check(Clock():find("Layer 1", 1, true), "a lower copy (a layer changed): Layer 1 of 2")
guids.mouseover = nil

out("== dungeons reset in a row: new copies, not scrambling")
for i = 1, 6 do
  instance.name, instance.kind, instance.map = "Deadmines", "party", 36
  M.Fire("PLAYER_ENTERING_WORLD"); Run()
  guids.target = ("Creature-0-4395-36-%d-1-0000"):format(700 + i)
  M.Fire("PLAYER_TARGET_CHANGED")
  instance.name, instance.kind, instance.map = "Westfall", "none", 0
  guids.target = nil
  M.Fire("PLAYER_ENTERING_WORLD"); Run()
end
check(not ns.LayerHidden(), "six dungeon copies in a row: the layer not taken as hidden")
check(#ClaraComboPointsDB.instances == 6, "six entries counted")

out("== scrambled: more than four new copies in five minutes on one map")
instance.name, instance.kind, instance.map = "Elwynn", "none", 0
for i = 1, 5 do
  guids.mouseover = ("Creature-0-4395-0-%d-%d-0000"):format(9000 + i * 37, 80 + i)
  M.Fire("UPDATE_MOUSEOVER_UNIT")
  M.now = (M.now or 0) + 20
end
guids.mouseover = nil
check(ns.LayerHidden(), "hidden")
t = Clock()
check(t:find("Layer: hidden by the game", 1, true) and not t:find("Layer %d") , "the clock: hidden by the game, no number (" .. t .. ")")
check(next(ClaraComboPointsDB.layers) == nil and ClaraComboPointsDB.layerHidden == "71000", "the copies kept dropped, the verdict kept for this build")
guids.target = "Creature-0-4395-0-25-299-0000ABC"
M.Fire("PLAYER_TARGET_CHANGED")
check(Clock():find("hidden by the game", 1, true), "a creature of a copy known before: still hidden (no wrong layer)")
guids.target = nil

out("== hidden: a dungeon entered again counts")
local before = #ClaraComboPointsDB.instances
instance.name, instance.kind, instance.map = "Deadmines", "party", 36
M.Fire("PLAYER_ENTERING_WORLD"); Run()
guids.target = "Creature-0-4395-36-706-1-0000" -- (the last one's copy: entered again)
M.Fire("PLAYER_TARGET_CHANGED")
check(#ClaraComboPointsDB.instances == before + 1, "counted (entered again or not can no longer be told)")
instance.name, instance.kind, instance.map = "Westfall", "none", 0
guids.target = nil
M.Fire("PLAYER_ENTERING_WORLD"); Run()
ok = pcall(InstanceTip)
check(ok, "the instances' tooltip: no error")
out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
