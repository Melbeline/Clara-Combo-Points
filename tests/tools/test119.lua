-- The rares on the world map (RareMap.lua, RareSpots.lua): an icon on each rare's main spot of the map shown, at its
-- place on the canvas and at the same size on the screen whatever the zoom; its other spots marked while the mouse is
-- on it; a click puts the game's map pin there, a right-click hides that rare; the map's button shows them or not, its
-- right-click opens the list: the map's rares first, the search box (a name in either language, a map), each rare's
-- box, Show all and Hide all (the rares listed), a click on a name shows its map; kept for the account
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70959", "Nov 17 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false,
  leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false,
  mail = false, classicui = false, tullarange = false, names = false, tooltipanchor = false, idtip = false, soloraidframe = false,
  enemycasts = false, reverseengineering = false } }
SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF = 2
local MAPNAMES = { [1411] = "Durotar", [1412] = "Mulgore", [1413] = "The Barrens", [1429] = "Elwynn Forest" }
C_Map.GetMapInfo = function(id) return { mapID = id, name = MAPNAMES[id] or ("Map " .. id) } end
local tracked
C_SuperTrack = { SetSuperTrackedUserWaypoint = function(on) tracked = on end }

-- The game's world map (the parts used): a canvas 1000 x 667 in a container, its map, its zoom, its round buttons
WorldMapFrame = CreateFrame("Frame", "WorldMapFrame", UIParent)
local container = CreateFrame("Frame", nil, WorldMapFrame)
local canvas = CreateFrame("Frame", nil, container)
canvas:SetSize(1000, 667)
WorldMapFrame.ScrollContainer = container
container.Child = canvas
WorldMapFrame.WorldMapTrackingPinButton = CreateFrame("Button", nil, WorldMapFrame)
local mapID, scale = 1411, 1
function WorldMapFrame:GetCanvas() return canvas end
function WorldMapFrame:GetCanvasContainer() return container end
function WorldMapFrame:GetMapID() return mapID end
function WorldMapFrame:GetCanvasScale() return scale end
function WorldMapFrame:OnMapChanged() end
function WorldMapFrame:OnCanvasScaleChanged() end
function WorldMapFrame:SetMapID(id) if id ~= mapID then mapID = id; self:OnMapChanged() end end
function WorldMapFrame:GetPinFrameLevelsManager() return { GetValidFrameLevel = function(_, kind) return kind == "PIN_FRAME_LEVEL_VIGNETTE" and 2600 or 1 end } end
WorldMapFrame:Show()

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints")
M.Fire("PLAYER_LOGIN")
M.Fire("ADDON_LOADED", "Blizzard_WorldMap")
if not ns.RareMapButton and ns.RareMapDress then ns.RareMapDress() end

local function Children(parent)
  local t = {}
  for _, f in ipairs(M.frames) do if f._parent == parent then t[#t + 1] = f end end
  return t
end
local function Pins()
  local t = {}
  for _, child in ipairs(Children(canvas)) do
    if child:IsShown() and child.spot then t[#t + 1] = child end
  end
  return t
end
local function PinOf(id) for _, p in ipairs(Pins()) do if p.spot.id == id then return p end end end
local function Marks()
  local n = 0
  for _, child in ipairs(Children(canvas)) do if child:IsShown() and not child.spot then n = n + 1 end end
  return n
end
local durotar = 0
for _, entry in pairs(ns.RARE_SPOTS) do for i = 2, #entry - 1, 2 do if entry[i] == 1411 then durotar = durotar + 1 end end end

out("== Durotar: an icon on each of its rares' main spot, at the vignettes' level")
check(durotar > 5 and #Pins() == durotar, ("one per rare (%d of %d)"):format(#Pins(), durotar))
local egg = PinOf(276194)
check(egg ~= nil, "Dustwind Eggtender's icon")
local point, rel, relPoint, x, y = egg:GetPoint(1)
check(point == "CENTER" and rel == canvas and relPoint == "TOPLEFT" and math.abs(x - 514) < 0.01 and math.abs(y + 0.192 * 667) < 0.01,
  ("on its spot, 51.4 %%, 19.2 %% (%s, %s)"):format(tostring(x), tostring(y)))
check(math.abs(egg:GetWidth() - 18) < 0.01 and egg:GetFrameLevel() == 2600, "18 high, at the game's rares' level")
check(PinOf(203079) ~= nil, "a rare of several maps: its Durotar spot")

out("== zoomed in: the same size on the screen")
scale = 2
WorldMapFrame:OnCanvasScaleChanged()
check(math.abs(egg:GetWidth() - 9) < 0.01, "9 in the canvas's units at twice the zoom")
scale = 1
WorldMapFrame:OnCanvasScaleChanged()

out("== the mouse on it: its other spots marked, its tooltip")
egg._scripts.OnEnter(egg)
check(Marks() == 6, "its 6 other spots marked (" .. Marks() .. ")")
local tip = table.concat(GameTooltip._lines or {}, " | ")
check(GameTooltip._shown and tip:find("Dustwind Eggtender", 1, true) and tip:find("Level 12", 1, true) and tip:find("Durotar  51.4, 19.2", 1, true),
  "its tooltip: " .. tip)
egg._scripts.OnLeave(egg)
check(Marks() == 0, "marks gone with the mouse")

out("== a click: the map pin there, tracked; a right-click: that rare hidden")
egg:Click("LeftButton")
check(M.waypoint and M.waypoint.uiMapID == 1411 and math.abs(M.waypoint.x - 0.514) < 1e-6 and tracked == true, "the game's map pin on its spot, tracked")
egg:Click("RightButton")
check(PinOf(276194) == nil and #Pins() == durotar - 1, "hidden")
check(ns.sv.rareMap.hidden[276194] == true, "kept")

out("== the map's button: the rares off, then on again")
local button = ns.RareMapButton
local p1, rel1, rp1 = button:GetPoint(1)
check(p1 == "TOP" and rel1 == WorldMapFrame.WorldMapTrackingPinButton and rp1 == "BOTTOM", "under the game's round buttons")
button:Click("LeftButton")
check(#Pins() == 0 and ns.sv.rareMap.on == false, "off: none")
button:Click("LeftButton")
check(#Pins() == durotar - 1, "on again")

out("== the list: the map's rares first, the search, Show all and Hide all")
button:Click("RightButton")
local panel = ns.RareMapPanel
check(panel and panel:IsShown(), "opened by the button's right-click")
local function Rows()
  local t = {}
  for _, child in ipairs(Children(panel)) do if child.rare and child:IsShown() then t[#t + 1] = child end end
  table.sort(t, function(a, b) return select(5, a:GetPoint(1)) > select(5, b:GetPoint(1)) end)
  return t
end
local rows = Rows()
local onMap = 0
for i = 1, durotar do
  local rare = rows[i] and rows[i].rare
  if rare then for _, m in ipairs(rare.maps) do if m == 1411 then onMap = onMap + 1 break end end end
end
check(#rows == 16 and onMap == math.min(16, durotar), ("Durotar's rares first (%d of the first rows)"):format(onMap))
panel.search:SetText("dustwind")
panel.search._scripts.OnTextChanged(panel.search)
rows = Rows()
check(#rows == 1 and rows[1].rare.id == 276194 and not rows[1].check:GetChecked(), "searched: Dustwind Eggtender alone, unticked (hidden)")
rows[1].check:Click()
check(PinOf(276194) ~= nil, "ticked: its icon back")
panel.search:SetText("mulgore")
panel.search._scripts.OnTextChanged(panel.search)
rows = Rows()
local allMulgore = #rows > 0
for _, row in ipairs(rows) do
  local has = false
  for _, m in ipairs(row.rare.maps) do if m == 1412 then has = true end end
  allMulgore = allMulgore and has
end
check(allMulgore, "a map's name: its rares (" .. #rows .. ")")
panel.hideAll:Click()
check(ns.sv.rareMap.hidden[203079] == true and PinOf(203079) == nil, "Hide all: the rares listed (Mulgore's), a Durotar icon of one of them gone")
check(PinOf(276194) ~= nil, "the others left as they were")
panel.showAll:Click()
check(ns.sv.rareMap.hidden[203079] == nil and PinOf(203079) ~= nil, "Show all: back")
panel.search:SetText("")
panel.search._scripts.OnTextChanged(panel.search)

out("== a click on a rare's name: its map")
panel.search:SetText("narg the taskmaster")
panel.search._scripts.OnTextChanged(panel.search)
rows = Rows()
check(rows[1] and rows[1].rare.id == 79, "Narg the Taskmaster found")
rows[1]:Click()
check(mapID == 1429 and PinOf(79) ~= nil and PinOf(276194) == nil, "Elwynn Forest shown, its rares on it")
out(string.format("\n%d failure(s)", fails))
return fails
