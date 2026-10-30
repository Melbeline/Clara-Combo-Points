-- Typed return values from the game's own API documentation (apidoc.lua, made by extract_apidoc.py):
-- for a documented function or widget method, values of the types the game returns (0, "", false, a
-- table with a structure's fields, a color, a widget) instead of a mock that is none of them.
-- Usage: local T = dofile(dir .. "/doctypes.lua")(dir); T.Method(name), T.Namespace(ns), T.Global(name)
return function(dir)
  local D = dofile(dir .. "/apidoc.lua")
  local T = { doc = D }
  local defs = {}
  for _, t in ipairs(D.tables) do defs[t.name] = t end
  T.defs = defs

  local NUMBER = {}
  for _, k in ipairs({ "number", "fileID", "luaIndex", "time_t", "Seconds", "BigUInteger", "BigInteger", "size",
    "uiFontHeight", "normalizedValue", "FrameTime", "ClubId", "WOWMONEY", "SoundHandle", "SingleColorValue",
    "VoiceChatID", "TBFFlags", "UnitCastBarID", "EncounterTimelineEventID", "DiscordMemberOpaqueID", "uiMapID",
    "ClubStreamId", "AccountStoreState", "GameMode", "uiUnit" }) do NUMBER[k] = true end
  local STRING = {}
  for _, k in ipairs({ "string", "cstring", "WOWGUID", "stringView", "textureAtlas", "FramePoint",
    "JustifyVertical", "JustifyHorizontal", "DrawLayer", "textureKit", "Orientation", "KStringDiscordUserName",
    "FileAsset", "mouseButton", "BlendMode", "FilterMode", "WrapMode", "TextureAndAtlasFilterMode",
    "ConnectionIptype", "ConnectionProtocol" }) do STRING[k] = true end
  local COLOR = { colorRGB = true, colorRGBA = true }
  T.NUMBER, T.STRING = NUMBER, STRING

  -- a color as the game hands one (ColorMixin's reading methods)
  local function Color()
    local c = { r = 1, g = 1, b = 1, a = 1 }
    function c:GetRGB() return self.r, self.g, self.b end
    function c:GetRGBA() return self.r, self.g, self.b, self.a end
    function c:GetRGBAsBytes() return 255, 255, 255 end
    function c:GenerateHexColor() return "ffffffff" end
    function c:GenerateHexColorMarkup() return "|cffffffff" end
    function c:WrapTextInColorCode(s) return "|cffffffff" .. tostring(s) .. "|r" end
    function c:IsEqualTo() return true end
    function c:SetRGB(r, g, b) self.r, self.g, self.b = r, g, b end
    function c:SetRGBA(r, g, b, a) self.r, self.g, self.b, self.a = r, g, b, a end
    return c
  end
  T.Color = Color

  -- the value of one documented type; widget: function(type) for the types that are widgets
  local function Value(typ, nilable, widget, depth)
    if nilable then return nil end
    if typ == "bool" then return false end
    if NUMBER[typ] then return 0 end
    if STRING[typ] then return "" end
    if COLOR[typ] then return Color() end
    local def = defs[typ]
    if def then
      if def.kind == "enum" then local low; for _, v in pairs(def.values) do if not low or v < low then low = v end end return low or 0 end
      if def.kind == "struct" then
        local t = {}
        if (depth or 0) < 3 then
          for _, f in ipairs(def.fields) do if not f[3] then t[f[1]] = Value(f[2], false, widget, (depth or 0) + 1) end end
        end
        return t
      end
    end
    if typ == "table" or typ == "vector2" or typ == "vector3" or typ == "TooltipData" then return {} end
    if widget and (typ:match("^Simple") or typ == "ScriptRegion" or typ == "FrameScriptObject" or typ == "CScriptObject") then
      return widget(typ)
    end
    return nil
  end
  T.Value = Value

  -- the values a function returns, in order
  local function Returns(rets, widget)
    local out, n = {}, 0
    for i, r in ipairs(rets) do out[i] = Value(r[1], r[2], widget); n = i end
    return unpack(out, 1, n)
  end
  T.Returns = Returns

  -- widget methods by name (the Simple*API ones first: a frame's own over a model's)
  local methods = {}
  local order = {}
  for name in pairs(D.scriptObjects) do order[#order + 1] = name end
  table.sort(order, function(a, b)
    local sa, sb = a:match("^Simple") ~= nil, b:match("^Simple") ~= nil
    if sa ~= sb then return sa end
    return a < b
  end)
  for _, so in ipairs(order) do
    for fname, rets in pairs(D.scriptObjects[so]) do if not methods[fname] then methods[fname] = rets end end
  end
  T.methods = methods
  T.scriptObjects = D.scriptObjects

  -- namespaces and global functions
  local namespaces, globals, events = {}, {}, {}
  for _, sys in ipairs(D.systems) do
    if sys.ns then
      namespaces[sys.ns] = namespaces[sys.ns] or {}
      for fname, rets in pairs(sys.functions) do namespaces[sys.ns][fname] = rets end
    else
      for fname, rets in pairs(sys.functions) do globals[fname] = rets end
    end
    for _, e in ipairs(sys.events) do events[e] = true end
  end
  T.namespaces, T.globals, T.events = namespaces, globals, events

  -- Enum and Constants as the game has them
  local enum, constants = {}, {}
  for _, t in ipairs(D.tables) do
    if t.kind == "enum" then
      local e = {}
      for k, v in pairs(t.values) do e[k] = v end
      enum[t.name] = e
    elseif t.kind == "const" then
      local c = {}
      for k, v in pairs(t.values) do c[k] = v end
      constants[t.name] = c
    end
  end
  -- constants the client sets itself, not in its documentation (Classic's values)
  constants.InventoryConstants = constants.InventoryConstants or {}
  for k, v in pairs({ NumBagSlots = 4, NumReagentBagSlots = 1, NumBankBagSlots = 6, NumAccountBankSlots = 5 }) do
    if constants.InventoryConstants[k] == nil then constants.InventoryConstants[k] = v end
  end
  T.Enum, T.Constants = enum, constants
  return T
end
