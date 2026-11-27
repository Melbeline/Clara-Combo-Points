-- Shared by the Enhanced Raid Frames tests: Clara loaded with the XML files its TOC lists (the shared
-- Ace libraries), unknown templates tolerated, ERF's indicator template, the game's raid frames
local M, S = MOCK, MOCK.state
local E = {}
local function readfile(p) local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return s end
local function run(path, name, ns)
  local fn = assert(loadstring(readfile(path), "@" .. name))
  fn("ClaraComboPoints", ns)
end
local function xml(path, ns)
  local dir = path:match("^(.*)/[^/]*$")
  for tag, file in (readfile(path):gsub("<!%-%-.-%-%->", "")):gmatch('<(%a+)%s+file="([^"]+)"') do
    local p = dir .. "/" .. file:gsub("\\", "/")
    if tag == "Script" then run(p, file, ns) elseif tag == "Include" then xml(p, ns) end
  end
end
function E.Load(dir, ns)
  -- (the built-in Clique off and its files left out, as in the mock's own loader)
  local db = rawget(_G, "ClaraComboPointsDB")
  if type(db) ~= "table" then db = {}; ClaraComboPointsDB = db end
  db.qol = type(db.qol) == "table" and db.qol or {}
  if db.qol.clique == nil then db.qol.clique = false end
  for file in readfile(dir .. "/ClaraComboPoints.toc"):gmatch("[^\r\n]+") do
    if file:find("Modules\\Clique\\", 1, true) then -- (left out)
    elseif not file:match("^##") and file:match("%.lua$") then run(dir .. "/" .. file:gsub("\\", "/"), file, ns)
    elseif not file:match("^##") and file:match("%.xml$") then xml(dir .. "/" .. file:gsub("\\", "/"), ns) end
  end
end
-- a method the mock lacks (AceGUI's widgets use many): does nothing (the ones the tests read are set below)
local noop = function() end
local Base = getmetatable(M.classes.Region).__index
if not getmetatable(Base) then
  setmetatable(Base, { __index = function(_, k)
    if type(k) ~= "string" then return end
    if k:match("^Get%a*Texture$") then -- (a texture of its own, made when asked)
      return function(self) self["_auto" .. k] = self["_auto" .. k] or self:CreateTexture(); return self["_auto" .. k] end
    end
    if k == "CreateAnimationGroup" or k == "CreateAnimation" then -- (a stand-in that takes any call)
      local dummy
      dummy = setmetatable({}, { __index = function(_, m) return m:match("^Create") and function() return dummy end or noop end })
      return function() return dummy end
    end
    if k:match("^%u%l") and not k:find("_") then return noop end
  end })
end
-- unknown templates: a plain frame
local Create = CreateFrame
function CreateFrame(kind, name, parent, template)
  if template and template ~= "BackdropTemplate" and not M.TEMPLATES[template] then
    local okKind = pcall(Create, kind, nil, nil)
    if not okKind then kind = "Frame" end
    template = nil
  end
  return Create(kind, name, parent, template)
end
M.TEMPLATES.ERF_indicatorTemplate = function(f)
  f.Icon = f:CreateTexture(nil, "BACKGROUND"); f.Icon:SetAllPoints()
  f.Countdown = f:CreateFontString(nil, "OVERLAY"); f.Countdown:SetPoint("CENTER")
  f.StackSize = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall"); f.StackSize:SetPoint("BOTTOMRIGHT")
  f.Cooldown = Create("Cooldown", nil, f)
  f.Cooldown.Clear = f.Cooldown.Clear or function() end
end
-- the game's global shorthands
floor, ceil, min, max = floor or math.floor, ceil or math.ceil, min or math.min, max or math.max
tinsert, tremove = tinsert or table.insert, tremove or table.remove
sort, wipe = sort or table.sort, wipe or function(t) for k in pairs(t) do t[k] = nil end return t end
format, strsplit = format or string.format, strsplit or function(sep, s) local r = {} for p in (s .. sep):gmatch("(.-)%" .. sep) do r[#r + 1] = p end return unpack(r) end
tContains = tContains or function(t, v) for _, x in pairs(t) do if x == v then return true end end return false end
tInvert = tInvert or function(t) local r = {} for k, v in pairs(t) do r[v] = k end return r end
Mixin = Mixin or function(o, ...) for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do o[k] = v end end return o end
CreateFromMixins = CreateFromMixins or function(...) return Mixin({}, ...) end
RunNextFrame = RunNextFrame or function(fn) C_Timer.After(0, fn) end
strtrim = strtrim or function(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
GetFileIDFromPath = GetFileIDFromPath or function(p) return p end
FONT_COLOR_CODE_CLOSE = FONT_COLOR_CODE_CLOSE or "|r"
PARENS_TEMPLATE = PARENS_TEMPLATE or "(%s)"
-- the game's spell and item objects, data always there
Spell = Spell or {}
function Spell:CreateFromSpellID(id)
  return { id = id, GetSpellName = function() return "Spell " .. id end, GetSpellSubtext = function() return "Rank 1" end,
    ContinueOnSpellLoad = function(_, fn) fn() end, IsSpellEmpty = function() return false end,
    GetSpellTexture = function() return 136243 end, GetSpellDescription = function() return "" end }
end
Item = Item or {}
function Item:CreateFromItemID(id)
  return { id = id, GetItemName = function() return "Item " .. id end, ContinueOnItemLoad = function(_, fn) fn() end,
    GetItemIcon = function() return 134400 end, IsItemEmpty = function() return false end, GetItemLink = function() return "|Hitem:" .. id .. "|h" end }
end
C_Spell.IsSpellDataCached = C_Spell.IsSpellDataCached or function() return true end
C_Spell.RequestLoadSpellData = C_Spell.RequestLoadSpellData or function() end
C_Spell.GetSpellSubtext = C_Spell.GetSpellSubtext or function() return "Rank 1" end
C_Spell.GetSpellLink = C_Spell.GetSpellLink or function(id) return "|Hspell:" .. tostring(id) .. "|h" end
C_Item.IsItemDataCachedByID = C_Item.IsItemDataCachedByID or function() return true end
C_Item.RequestLoadItemDataByID = C_Item.RequestLoadItemDataByID or function() end
C_CurrencyInfo = C_CurrencyInfo or {}
C_CurrencyInfo.GetCoinTextureString = C_CurrencyInfo.GetCoinTextureString or function(c) return tostring(c) end
C_Map = C_Map or {}
C_Map.GetAreaInfo = C_Map.GetAreaInfo or function(id) return "Area " .. tostring(id) end
C_Reputation = C_Reputation or {}
C_Reputation.GetFactionDataByID = C_Reputation.GetFactionDataByID or function() return nil end
for _, k in ipairs({ "RED_FONT_COLOR_CODE", "ORANGE_FONT_COLOR_CODE", "LIGHTYELLOW_FONT_COLOR_CODE", "GRAY_FONT_COLOR_CODE",
  "NORMAL_FONT_COLOR_CODE", "HIGHLIGHT_FONT_COLOR_CODE", "YELLOW_FONT_COLOR_CODE", "WHITE_FONT_COLOR_CODE" }) do
  _G[k] = _G[k] or "|cffffffff"
end
for _, k in ipairs({ "RED_FONT_COLOR", "ORANGE_FONT_COLOR", "GRAY_FONT_COLOR", "LIGHTYELLOW_FONT_COLOR", "YELLOW_FONT_COLOR", "DISABLED_FONT_COLOR", "PASSIVE_SPELL_FONT_COLOR" }) do
  _G[k] = _G[k] or { r = 1, g = 1, b = 1 }
end
CopyTable = CopyTable or function(t)
  local c = {}
  for k, v in pairs(t) do c[k] = type(v) == "table" and CopyTable(v) or v end
  return c
end
-- colors as the game's ColorMixin
local MakeColor = CreateColor
function CreateColor(r, g, b, a)
  local c = MakeColor and MakeColor(r, g, b, a) or { r = r, g = g, b = b, a = a or 1 }
  c.r, c.g, c.b, c.a = c.r or r, c.g or g, c.b or b, c.a or a or 1
  c.GetRGB = c.GetRGB or function(self) return self.r, self.g, self.b end
  c.GetRGBA = c.GetRGBA or function(self) return self.r, self.g, self.b, self.a end
  c.WrapTextInColorCode = c.WrapTextInColorCode or function(_, text) return text end
  return c
end
for _, k in ipairs({ "NORMAL_FONT_COLOR", "WHITE_FONT_COLOR", "DIM_RED_FONT_COLOR", "DARKYELLOW_FONT_COLOR", "HIGHLIGHT_FONT_COLOR", "GREEN_FONT_COLOR" }) do
  local c = _G[k]
  if type(c) == "table" then _G[k] = CreateColor(c.r, c.g, c.b, c.a) end
end
-- the game's options: a category found by its ID; secure variables (none tainted here)
local byID = {}
local function Keep(c) if c then byID[c.ID or (c.GetID and c:GetID())] = c end return c end
local reg, sub, vsub = Settings.RegisterCanvasLayoutCategory, Settings.RegisterCanvasLayoutSubcategory, Settings.RegisterVerticalLayoutSubcategory
Settings.RegisterCanvasLayoutCategory = function(...) return Keep(reg(...)) end
Settings.RegisterCanvasLayoutSubcategory = function(...) return Keep(sub(...)) end
Settings.RegisterVerticalLayoutSubcategory = function(...) local c, l = vsub(...); Keep(c); return c, l end
Settings.GetCategory = Settings.GetCategory or function(id) return byID[id] end
issecurevariable = issecurevariable or function() return true end
securecallfunction = securecallfunction or function(f, ...) return f(...) end
-- what AceAddon and Enhanced Raid Frames ask the game (xpcall with arguments, as the game's)
local xp = xpcall
xpcall = function(f, h, ...)
  local n, args = select("#", ...), { ... }
  return xp(function() return f(unpack(args, 1, n)) end, h)
end
IsLoggedIn = IsLoggedIn or function() return E.loggedIn == true end
-- the game's raid frames: E.Frame(unit) makes one, in the raid container's "normal" list
E.frames = {}
CompactRaidFrameContainer = CreateFrame("Frame", "CompactRaidFrameContainer", UIParent)
function CompactRaidFrameContainer:ApplyToFrames(which, fn, ...)
  if which == "normal" or which == "all" then for _, f in ipairs(E.frames) do fn(f, ...) end end
end
CompactRaidFrameContainer:SetSize(200, 200)
function CompactUnitFrame_UpdateInRange(frame) end
function CompactUnitFrame_UpdateCenterStatusIcon(frame)
  frame:SetAlpha(frame.optionTable.fadeOutOfRange and not issecretvalue(frame.outOfRange) and frame.outOfRange and 0.5 or 1)
end
function CompactUnitFrame_SetUnit(frame, unit) frame.unit = unit; frame.displayedUnit = unit end
function E.Frame(unit)
  local n = #E.frames + 1
  local f = CreateFrame("Button", "CompactRaidFrame" .. n, CompactRaidFrameContainer)
  f:SetSize(72, 36)
  f.unit, f.displayedUnit = unit, unit
  f.optionTable = { fadeOutOfRange = true }
  f.background = f:CreateTexture()
  f.powerBar = CreateFrame("StatusBar", nil, f); f.powerBar:SetHeight(8); f.powerBar:Hide()
  function f:SetAlphaFromBoolean(v, yes, no) self._alphaFromBoolean = { v, yes, no } end
  E.frames[n] = f
  return f
end
return E
