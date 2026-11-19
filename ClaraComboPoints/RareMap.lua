-- Clara Combo Points - the rares on the world map. An icon (a skull) on each rare's main spot on the map shown (its
-- spots: RareSpots.lua; the rares: Rares.lua), its other spots (where it walks) as small marks while the mouse is on it;
-- its tooltip (name, level, map, coordinates); a click puts the game's map pin there and tracks it, a right-click hides
-- that rare. A button on the map, under the game's own round ones at its top right: a click shows the rares or not, a
-- right-click opens the list of every rare: a search box (a name, in the game's language or in English, or a map), each
-- rare's box to show its icon or not, Show all and Hide all (the rares the list shows), a click on a rare's name shows
-- its map. Kept for the account (ns.sv.rareMap). On the game's own map frame, with ClassicUI's restyle too: icons of
-- ours on its canvas, never in its pin pools (nothing of the game's map written).

local ADDON, ns = ...
local L = ns.L

local ICON = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local MARK = "Interface\\COMMON\\Indicator-Yellow"
local SIZE, MARK_SIZE = 18, 9 -- the icon's and a mark's size on the screen, whatever the map's zoom
local ROWS, ROW_H, LIST_W = 16, 18, 300
local LIST_TOP, FOOT = 84, 40 -- (the list under the search box; the foot's band for Show all and Hide all, nothing over it)
local LANG = ({ frFR = 2, deDE = 3 })[GetLocale and GetLocale() or "enUS"] or 1
local EMPTY = {}

local function Store()
  local sv = ns.sv
  if type(sv) ~= "table" then return nil end
  local s = sv.rareMap
  if type(s) ~= "table" then s = {}; sv.rareMap = s end
  if s.on == nil then s.on = true end
  if type(s.hidden) ~= "table" then s.hidden = {} end
  return s
end
ns.RareMapStore = Store

local function RareName(id, english)
  local names = ns.RARES and ns.RARES[id]
  if not names then return "#" .. id end
  return english and names[1] or names[LANG] or names[1]
end

local function Key(text) return ns.SearchKey and ns:SearchKey(text) or tostring(text):lower() end

-- Each map's rares, read once: mapID -> { { id, x, y, pts = { x, y, x, y, ... } (its main spot first) }, ... }
local byMap
local function Points(text)
  local pts = {}
  for x, y in text:gmatch("(%d+)%-(%d+)") do
    pts[#pts + 1] = tonumber(x) / 10000
    pts[#pts + 1] = tonumber(y) / 10000
  end
  return pts
end
local function ByMap()
  if byMap then return byMap end
  byMap = {}
  for id, entry in pairs(ns.RARE_SPOTS or EMPTY) do
    if ns.RARES and ns.RARES[id] then
      for i = 2, #entry - 1, 2 do
        local mapID, text = entry[i], entry[i + 1]
        if type(mapID) == "number" and type(text) == "string" then
          local pts = Points(text)
          if #pts >= 2 then
            local list = byMap[mapID] or {}
            byMap[mapID] = list
            list[#list + 1] = { id = id, x = pts[1], y = pts[2], pts = pts }
          end
        end
      end
    end
  end
  return byMap
end
ns.RareMapPoints = ByMap

local mapNames = {}
local function MapName(mapID)
  if mapNames[mapID] == nil then
    local ok, info = pcall(C_Map.GetMapInfo, mapID)
    mapNames[mapID] = ok and type(info) == "table" and type(info.name) == "string" and info.name or false
  end
  return mapNames[mapID] or ("#" .. mapID)
end

-- Every rare with a spot, once: { id, name, english, level, maps }, by name
local all
local function All()
  if all then return all end
  all = {}
  for id, entry in pairs(ns.RARE_SPOTS or EMPTY) do
    if ns.RARES and ns.RARES[id] then
      local maps = {}
      for i = 2, #entry - 1, 2 do maps[#maps + 1] = entry[i] end
      all[#all + 1] = { id = id, name = RareName(id), english = RareName(id, true), level = entry[1], maps = maps }
    end
  end
  table.sort(all, function(a, b)
    if a.name:lower() ~= b.name:lower() then return a.name:lower() < b.name:lower() end
    return a.id < b.id
  end)
  return all
end

---------------------------------------------------------------------------
-- The icons on the map
---------------------------------------------------------------------------
local map, canvas, button, panel
local pins, marks = {}, {}
local shownPins, shownMarks = 0, 0
local Refresh, RefreshList

local function Scale()
  local ok, scale = pcall(function() return map:GetCanvasScale() end)
  return ok and type(scale) == "number" and scale > 0 and scale or 1
end

-- The game's own level for rares on its map (its vignettes'): above the map's art, under the quests and the map pin
local function PinLevel()
  local ok, level = pcall(function()
    return map:GetPinFrameLevelsManager():GetValidFrameLevel("PIN_FRAME_LEVEL_VIGNETTE")
  end)
  if ok and type(level) == "number" then return level end
  return canvas:GetFrameLevel() + 50
end

local function Place(frame, x, y, size)
  local w, h = canvas:GetWidth() or 0, canvas:GetHeight() or 0
  local s = size / Scale()
  frame:SetSize(s, s)
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", canvas, "TOPLEFT", x * w, -y * h)
end

local function HideMarks()
  for i = 1, shownMarks do marks[i]:Hide() end
  shownMarks = 0
end

-- Its other spots, while the mouse is on it
local function ShowMarks(pin)
  HideMarks()
  local pts = pin.spot.pts
  for i = 3, #pts - 1, 2 do
    shownMarks = shownMarks + 1
    local mark = marks[shownMarks]
    if not mark then
      mark = CreateFrame("Frame", nil, canvas)
      local tex = mark:CreateTexture(nil, "OVERLAY")
      tex:SetAllPoints()
      tex:SetTexture(MARK)
      marks[shownMarks] = mark
    end
    mark:SetFrameLevel(math.max(1, pin:GetFrameLevel() - 1))
    Place(mark, pts[i], pts[i + 1], MARK_SIZE)
    mark:Show()
  end
end

local function SetWaypoint(mapID, x, y)
  if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and C_Map.CanSetUserWaypointOnMap
    and C_Map.CanSetUserWaypointOnMap(mapID)) then
    if UIErrorsFrame and MAP_PIN_INVALID_MAP then UIErrorsFrame:AddMessage(MAP_PIN_INVALID_MAP, 1, 0.1, 0.1) end
    return false
  end
  C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
  if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
  if SOUNDKIT and SOUNDKIT.UI_MAP_WAYPOINT_CONTROL_CLICK then PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_CONTROL_CLICK) end
  return true
end

local function Tip(pin)
  local spot = pin.spot
  local entry = ns.RARE_SPOTS[spot.id]
  GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
  GameTooltip:SetText(RareName(spot.id), 1, 0.82, 0)
  local level = entry and entry[1]
  GameTooltip:AddLine(type(level) == "number" and level > 0 and L.RAREMAP_LEVEL:format(level) or L.RAREMAP_RARE, 1, 1, 1)
  GameTooltip:AddLine(("%s  %.1f, %.1f"):format(MapName(pin.mapID), spot.x * 100, spot.y * 100), 0.75, 0.75, 0.75)
  local more = math.floor(#spot.pts / 2) - 1
  if more > 0 then GameTooltip:AddLine(L.RAREMAP_MORE:format(more), 0.75, 0.75, 0.75, true) end
  GameTooltip:AddLine(L.RAREMAP_PIN_HINT, 0.5, 0.8, 1, true)
  GameTooltip:Show()
end

local function Pin(i)
  local pin = pins[i]
  if pin then return pin end
  pin = CreateFrame("Button", nil, canvas)
  pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local tex = pin:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints()
  tex:SetTexture(ICON)
  local glow = pin:CreateTexture(nil, "HIGHLIGHT")
  glow:SetAllPoints()
  glow:SetTexture(ICON)
  glow:SetBlendMode("ADD")
  pin:SetScript("OnEnter", function(self) ShowMarks(self) Tip(self) end)
  pin:SetScript("OnLeave", function() HideMarks() GameTooltip:Hide() end)
  pin:SetScript("OnClick", function(self, mouse)
    if mouse == "RightButton" then
      local s = Store()
      if s then s.hidden[self.spot.id] = true end
      GameTooltip:Hide()
      Refresh()
      if RefreshList then RefreshList() end
    else
      SetWaypoint(self.mapID, self.spot.x, self.spot.y)
    end
  end)
  pins[i] = pin
  return pin
end

local function UpdateButton()
  if not button then return end
  local s = Store()
  local on = s and s.on
  button.icon:SetDesaturated(not on)
  button.icon:SetAlpha(on and 1 or 0.55)
end

Refresh = function()
  if not (map and canvas) then return end
  HideMarks()
  local s = Store()
  local mapID = map.GetMapID and map:GetMapID()
  local list = s and s.on and mapID and ByMap()[mapID] or EMPTY
  local n, level = 0, nil
  for _, spot in ipairs(list) do
    if not s.hidden[spot.id] then
      n = n + 1
      level = level or PinLevel()
      local pin = Pin(n)
      pin.spot, pin.mapID = spot, mapID
      pin:SetFrameLevel(level)
      Place(pin, spot.x, spot.y, SIZE)
      pin:Show()
    end
  end
  for i = n + 1, #pins do pins[i]:Hide() end
  shownPins = n
  UpdateButton()
end
ns.RareMapRefresh = function() if Refresh then Refresh() end end

-- The map zoomed or resized: the icons kept at their size on the screen, on their spots
local function Rescale()
  if not canvas then return end
  for i = 1, shownPins do
    local pin = pins[i]
    Place(pin, pin.spot.x, pin.spot.y, SIZE)
  end
  HideMarks()
end

---------------------------------------------------------------------------
-- The list: a search box, Show all, Hide all, each rare with its box
---------------------------------------------------------------------------
local rows, shown, offset = {}, {}, 0

local function Matches(rare, key)
  if key == "" then return true end
  if Key(rare.name):find(key, 1, true) or Key(rare.english):find(key, 1, true) then return true end
  for _, mapID in ipairs(rare.maps) do
    if Key(MapName(mapID)):find(key, 1, true) then return true end
  end
  return false
end

-- The rares the list shows: those of the map shown first, then the others, each by name
local function Filter()
  shown = {}
  local key = Key(panel and panel.search and panel.search:GetText() or "")
  local mapID = map and map.GetMapID and map:GetMapID()
  local here = {}
  for _, rare in ipairs(All()) do
    if Matches(rare, key) then
      local onMap = false
      for _, m in ipairs(rare.maps) do if m == mapID then onMap = true end end
      if onMap then here[#here + 1] = rare else shown[#shown + 1] = rare end
    end
  end
  for i = #here, 1, -1 do table.insert(shown, 1, here[i]) end
  panel.here = #here
end

local function DrawRows()
  local s = Store()
  local mapID = map and map.GetMapID and map:GetMapID()
  offset = math.max(0, math.min(offset, #shown - ROWS))
  for i = 1, ROWS do
    local row = rows[i]
    local rare = shown[offset + i]
    row.rare = rare
    if rare then
      row.check:SetChecked(not (s and s.hidden[rare.id]))
      local onMap = i + offset <= (panel.here or 0)
      row.name:SetText(rare.name)
      row.name:SetTextColor(onMap and 1 or 0.9, onMap and 0.82 or 0.9, onMap and 0 or 0.9)
      local where = MapName(rare.maps[1]) .. (#rare.maps > 1 and (" +" .. (#rare.maps - 1)) or "")
      row.info:SetText((type(rare.level) == "number" and rare.level > 0 and (rare.level .. "  ") or "") .. where)
      row:Show()
    else
      row:Hide()
    end
  end
  panel.count:SetText(L.RAREMAP_COUNT:format(#shown, #All()))
  local track = panel.track
  if #shown > ROWS then
    local h = track:GetHeight() or 1
    local thumbH = math.max(12, h * ROWS / #shown)
    panel.thumb:SetHeight(thumbH)
    panel.thumb:ClearAllPoints()
    panel.thumb:SetPoint("TOP", track, "TOP", 0, -(h - thumbH) * offset / (#shown - ROWS))
    panel.thumb:Show()
  else
    panel.thumb:Hide()
  end
  if panel.onBox then panel.onBox:SetChecked(s and s.on and true or false) end
end

RefreshList = function()
  if not (panel and panel:IsShown()) then return end
  Filter()
  DrawRows()
end

local function SetAll(hidden)
  local s = Store()
  if not s then return end
  for _, rare in ipairs(shown) do s.hidden[rare.id] = hidden or nil end
  PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
  Refresh()
  DrawRows()
end
ns.RareMapSetAll = function(hidden) if panel then Filter() SetAll(hidden) end end

local function Row(i)
  local row = CreateFrame("Button", nil, panel)
  row:SetSize(LIST_W - 30, ROW_H)
  row:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -LIST_TOP - (i - 1) * ROW_H)
  local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
  check:SetSize(20, 20)
  check:SetPoint("LEFT", row, "LEFT", 0, 0)
  check:SetScript("OnClick", function(self)
    local s, rare = Store(), row.rare
    if not (s and rare) then return end
    s.hidden[rare.id] = not self:GetChecked() or nil
    PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    Refresh()
  end)
  row.check = check
  row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  row.name:SetPoint("LEFT", check, "RIGHT", 2, 0)
  row.name:SetWidth(140)
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(false)
  row.info = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  row.info:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
  row.info:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  row.info:SetJustifyH("RIGHT")
  row.info:SetWordWrap(false)
  local glow = row:CreateTexture(nil, "HIGHLIGHT")
  glow:SetAllPoints()
  glow:SetColorTexture(1, 1, 1, 0.08)
  -- (a click on its name: its map, out of a fight)
  row:SetScript("OnClick", function(self)
    local rare = self.rare
    if not (rare and map and map.SetMapID) or InCombatLockdown() then return end
    map:SetMapID(rare.maps[1])
  end)
  row:SetScript("OnEnter", function(self)
    local rare = self.rare
    if not rare then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(rare.name, 1, 0.82, 0)
    for _, mapID in ipairs(rare.maps) do GameTooltip:AddLine(MapName(mapID), 1, 1, 1) end
    GameTooltip:AddLine(L.RAREMAP_ROW_HINT, 0.5, 0.8, 1, true)
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return row
end

local function BuildPanel()
  panel = CreateFrame("Frame", nil, map, "BackdropTemplate")
  panel:SetSize(LIST_W, LIST_TOP + ROWS * ROW_H + FOOT)
  panel:SetPoint("TOPRIGHT", button, "TOPLEFT", -4, 0)
  panel:SetFrameStrata(button:GetFrameStrata())
  panel:SetFrameLevel(button:GetFrameLevel() + 5)
  panel:EnableMouse(true)
  if panel.SetBackdrop then
    panel:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    panel:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
  end
  panel:Hide()
  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
  title:SetText(L.RAREMAP_TITLE)
  local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
  close:SetScript("OnClick", function() panel:Hide() end)
  -- (the icons on the map or not: the same as the button's click)
  local onBox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  onBox:SetSize(22, 22)
  onBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -26)
  local onText = onBox.Text or onBox.text or panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  if not (onBox.Text or onBox.text) then onText:SetPoint("LEFT", onBox, "RIGHT", 2, 0) end
  onText:SetFontObject("GameFontHighlightSmall")
  onText:SetText(L.RAREMAP_SHOW_ON_MAP)
  onBox:SetScript("OnClick", function(self)
    local s = Store()
    if s then s.on = self:GetChecked() and true or false end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    Refresh()
  end)
  panel.onBox = onBox
  local search = CreateFrame("EditBox", nil, panel, "SearchBoxTemplate")
  search:SetSize(LIST_W - 26, 20)
  search:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -50)
  search:SetAutoFocus(false)
  search:HookScript("OnTextChanged", function() offset = 0; RefreshList() end)
  if search.Instructions then search.Instructions:SetText(L.RAREMAP_SEARCH) end
  panel.search = search
  local showAll = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  showAll:SetSize(110, 20)
  showAll:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 10, 10)
  showAll:SetText(L.RAREMAP_SHOW_ALL)
  showAll:SetScript("OnClick", function() SetAll(false) end)
  local hideAll = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  hideAll:SetSize(110, 20)
  hideAll:SetPoint("LEFT", showAll, "RIGHT", 4, 0)
  hideAll:SetText(L.RAREMAP_HIDE_ALL)
  hideAll:SetScript("OnClick", function() SetAll(true) end)
  panel.showAll, panel.hideAll = showAll, hideAll
  -- (how many the list shows, on the title's line, clear of the foot's buttons)
  panel.count = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  panel.count:SetPoint("RIGHT", close, "LEFT", -2, 0)
  -- (a thin bar showing where the list is scrolled to; the mouse wheel scrolls it)
  local track = panel:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(1, 1, 1, 0.06)
  track:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -LIST_TOP)
  track:SetSize(6, ROWS * ROW_H)
  panel.track = track
  local thumb = panel:CreateTexture(nil, "ARTWORK")
  thumb:SetColorTexture(1, 0.82, 0, 0.6)
  thumb:SetWidth(6)
  panel.thumb = thumb
  for i = 1, ROWS do rows[i] = Row(i) end
  panel:EnableMouseWheel(true)
  panel:SetScript("OnMouseWheel", function(_, delta)
    offset = offset - delta * 3
    DrawRows()
  end)
  panel:SetScript("OnShow", function() Filter() DrawRows() end)
  ns.RareMapPanel = panel
end

local function TogglePanel()
  if not panel then BuildPanel() end
  panel:SetShown(not panel:IsShown())
end
ns.RareMapTogglePanel = TogglePanel

---------------------------------------------------------------------------
-- The button on the map, under the game's round ones on its top right
---------------------------------------------------------------------------
local function MakeButton()
  local container = map:GetCanvasContainer()
  button = CreateFrame("Button", nil, map)
  button:SetSize(32, 32)
  button:SetFrameStrata(container:GetFrameStrata())
  button:SetFrameLevel(container:GetFrameLevel() + 100)
  local above = map.WorldMapTrackingPinButton or map.WorldMapTrackingOptionsButton
  if above then
    button:SetPoint("TOP", above, "BOTTOM", 0, 0)
  else
    button:SetPoint("TOPRIGHT", container, "TOPRIGHT", -4, -2)
  end
  local back = button:CreateTexture(nil, "BACKGROUND")
  back:SetSize(24, 24)
  back:SetPoint("CENTER")
  back:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(18, 18)
  icon:SetPoint("CENTER")
  icon:SetTexture(ICON)
  button.icon = icon
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(54, 54)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:SetScript("OnClick", function(_, mouse)
    if mouse == "RightButton" then TogglePanel() return end
    local s = Store()
    if not s then return end
    s.on = not s.on
    PlaySound(s.on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    Refresh()
    RefreshList()
  end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(L.RAREMAP_TITLE, 1, 1, 1)
    local s = Store()
    GameTooltip:AddLine(s and s.on and L.RAREMAP_ON or L.RAREMAP_OFF, 1, 0.82, 0)
    GameTooltip:AddLine(L.RAREMAP_BUTTON_TIP, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  ns.RareMapButton = button
  UpdateButton()
end

local dressed = false
local function Dress()
  local m = WorldMapFrame
  if dressed or not (m and m.GetCanvas and m.GetCanvasContainer and ns.RARE_SPOTS) then return end
  dressed = true
  map, canvas = m, m:GetCanvas()
  MakeButton()
  -- (after the game's own: its map changed, zoomed, shown)
  hooksecurefunc(m, "OnMapChanged", function() Refresh() RefreshList() end)
  if m.OnCanvasScaleChanged then hooksecurefunc(m, "OnCanvasScaleChanged", Rescale) end
  canvas:HookScript("OnSizeChanged", Rescale)
  m:HookScript("OnShow", Refresh)
  Refresh()
end
ns.RareMapDress = Dress

if EventUtil and EventUtil.ContinueOnAddOnLoaded then
  EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", Dress)
end
