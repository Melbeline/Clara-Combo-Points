-- Loads the addon, sets a scenario, and dumps draw ops for render.py.
local M = MOCK
local S = M.state
local ns = {}
local SCENE = SCENE or "hud5"
if SCENE:find("^warrior") then S.class = "WARRIOR" end
if SCENE:find("^bear") then S.class = "DRUID"; S.powerType = 1 end
if SCENE:find("^caster") then S.class = "DRUID"; S.powerType = 0; S.mana, S.manaMax = 2100, 3000 end
if SCENE:find("^catmana") then S.class = "DRUID"; S.powerType = 3; S.mana, S.manaMax = 2100, 3000 end
if ACT == "qol" then
  GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
  ClaraComboPointsDB = { qol = { buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false } }
end
if SCENE:find("^craft") then -- Reverse Engineering's panel (Modules/Crafting), as test58 sets it
  GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
  ClaraComboPointsDB = { qol = { buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
    dialogkey = false, xtolevel = false, minimapdrawer = false, mail = false, classicui = false, tullarange = false,
    names = false, tooltipanchor = false } }
  Enum = Enum or {}
  Enum.CraftingReagentType = { Basic = 1 }
  Enum.BagIndex = { Backpack = 0, CharacterBankTab_1 = 6 }
  local ITEMS = { [100] = "Tranquil Mechanical Yeti", [101] = "Cured Rugged Hide", [102] = "Thorium Widget", [103] = "Globe of Water",
    [104] = "Truesilver Transformer", [105] = "Gold Power Core", [106] = "Gold Bar", [107] = "Thorium Bar", [108] = "Runecloth",
    [109] = "Rugged Hide", [110] = "Refined Deeprock Salt" }
  for id, name in pairs(ITEMS) do M.ITEMS[id] = { name, 1000 + id, 7, 0 } end
  S.bags = { [102] = 5, [103] = 2, [104] = 2, [106] = 4, [107] = 55, [108] = 23 }
  C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemInfo = function() end }
  local R = {
    [1] = { 100, { { 101, 1 }, { 102, 4 }, { 103, 2 }, { 104, 2 }, { 105, 1 } } }, [2] = { 105, { { 106, 1 } } },
    [3] = { 102, { { 107, 3 }, { 108, 1 } } } }
  C_TradeSkillUI = {
    GetRecipeSchematic = function(id)
      local r = R[id]
      if not r then return end
      local slots = {}
      for i, x in ipairs(r[2]) do slots[i] = { reagents = { { itemID = x[1] } }, quantityRequired = x[2], reagentType = 1 } end
      return { outputItemID = r[1], quantityMin = 1, reagentSlotSchematics = slots, name = ITEMS[r[1]] }
    end,
    GetRecipeRequirements = function(id) return id ~= 3 and { { name = "Anvil" }, { name = "Blacksmith Hammer" } } or {} end,
  }
  ClaraCraftDB = { mode = SCENE == "craftText" and "text" or nil,
    chars = { ["Alt-Forever"] = { bags = { [109] = 6 }, bank = {}, mail = {}, sent = { [106] = 2 }, at = 1, class = "DRUID" },
      ["Lola-Forever"] = { bags = {}, bank = { [110] = 3, [106] = 10 }, mail = {}, sent = {}, at = 1 } },
    recipes = { [4] = { o = 101, m = 1, r = { 109, 1, 110, 1 }, p = "Leatherworking", w = { ["Alt-Forever"] = true } },
      [2] = { o = 105, m = 1, r = { 106, 1 }, p = "Engineering", w = { ["Lola-Forever"] = true } },
      [3] = { o = 102, m = 1, r = { 107, 3, 108, 1 }, p = "Engineering", w = { ["Lola-Forever"] = true } } } }
end
M.LoadAddon(ADDON_DIR, ns)
if ACT == "qol" then -- WeaponSwingTimer as if it ran, with its switches
  local real = ns.QolState
  ns.QolState = function(self, k) if k == "wst" then return "on" end return real(self, k) end
  ns.sv = ns.sv
  local v = { WST_SW_HUNTER = true, WST_SW_HUNTERS_ONLY = true, WST_SW_LOCKED = true }
  local list = {}
  for _, k in ipairs({ "WST_SW_HUNTER", "WST_SW_HUNTERS_ONLY", "WST_SW_PLAYER", "WST_SW_TARGET", "WST_SW_LOCKED" }) do
    list[#list + 1] = { label = k, get = function() return v[k] end, set = function(on) v[k] = on end }
  end
  ns:SetQolSwitches("wst", list)
end
ns.SPELL_CATALOG = ns.SPELL_CATALOG or {
  { class = "PRIEST", spells = { { "BUFF", 139, 6074, 6075 }, { "BUFF", 1243, 1244 }, { "SELFDEBUFF", 6788 } } },
  { class = "DRUID", spells = { { "BUFF", 774, 1058 }, { "DEBUFF", 8921, 8924 } } },
  { class = "WARRIOR", spells = { { "DEBUFF", 7386, 11597 }, { "BUFF", 6673 }, { "BUFF", 2687 }, { "DEBUFF", 1715 }, { "DEBUFF", 1160 } } },
}
M.Fire("ADDON_LOADED", "ClaraComboPoints")
M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")

local function fight() S.inCombat = true; M.Fire("PLAYER_REGEN_DISABLED") end
M.now = 0
if SCENE == "warrior" or SCENE == "warrior_square" then
  S.rage = 100; S.target = { hostile = true }
  S.auras = {
    target = { { name = "Sunder Armor", icon = 132363, applications = 5, duration = 30, expirationTime = 24, harmful = true },
               { name = "Demoralizing Shout", icon = 132366, applications = 0, duration = 30, expirationTime = 12, harmful = true } },
    player = { { name = "Battle Shout", icon = 132333, applications = 0, duration = 120, expirationTime = 95 },
               { name = "Bloodrage", icon = 132277, applications = 0, duration = 10, expirationTime = 2.4 } },
  }
  fight()
  if SCENE == "warrior_square" then
    ns.db.icons.square = true; ns.db.icons.size = 30
    ns.db.rows.above[2] = { 6774, 1943, 845 }
    ns.db.rows.below[1] = { 1160, 6673 }
    ns:LayoutIcons()
  end
  S.queued = 11567; M.Fire("CURRENT_SPELL_CAST_CHANGED", false)
  S.rage = 40; M.Fire("UNIT_POWER_FREQUENT", "player", "RAGE")
elseif SCENE == "bear5" or SCENE == "bear0" then
  S.rage = 100; S.target = { cp = SCENE == "bear5" and 5 or 0, hostile = true }
  fight()
  if SCENE == "bear0" then S.rage = 60; S.queued = 9881; M.Fire("CURRENT_SPELL_CAST_CHANGED", false) end
elseif SCENE == "caster" or SCENE == "catmana" then
  S.target = { cp = 3, hostile = true }; S.energy = 80; fight()
elseif SCENE == "ooc" then
  S.target = { cp = 2, hostile = true }; S.energy = 100
elseif SCENE == "hud5" then
  S.target = { cp = 5, hostile = true }; S.energy = 57
elseif SCENE == "hud2" then
  S.target = { cp = 2, hostile = true }; S.energy = 57
elseif SCENE == "options" then
  S.target = { cp = 2, hostile = true }; S.energy = 57
  if LANG then ns:SetLanguage(LANG) end
  SlashCmdList.CLARACOMBOPOINTS("")
  if SKIN then ns:SetSkin(SKIN) end
  if TAB and TAB ~= "ROGUE" then
    for _, f in ipairs(M.frames) do if f._kind == "Button" and f.class == TAB then f:Click() end end
  end
  if PAGE and tonumber(PAGE) then
    for _, f in ipairs(M.frames) do if f.page == tonumber(PAGE) then f:Click() end end
  end
  local function click(text)
    for _, f in ipairs(M.frames) do
      if f._kind == "Button" and f:IsVisible() and ((f._textFS and f._textFS._text == text) or (f.text and f.text._text == text)) then f:Click() return end
    end
  end
  if ACT == "qol" then
    ClaraComboPointsOptions.qolTab:Click()
    if PAGE == "wst" or PAGE == "buy" then
      for _, r in ipairs(M.regions) do
        if r._text == (PAGE == "wst" and "WeaponSwingTimer" or "BuyEmAll") and r:IsVisible() and r:GetParent()._kind == "Button" then r:GetParent():Click() end
      end
    end
  end
  if ACT == "profiles" or ACT == "export" then
    ns:SaveProfile(ns.profileClass, "Solo PvE"); ns:SaveProfile(ns.profileClass, "Raid")
    ns.db.fontSize = 19; ns:RefreshOptions()
    if ACT == "export" then click(ns.L.PROFILE_EXPORT) end
  elseif ACT == "settings" then
    ClaraComboPointsOptions:Hide()
    M.ShowSettingsPage(M.settingsCategories[1])
  end
end
if ACT == "health" or ACT == "order" then
  ns.db.bars.health.show = true; ns.db.healthClassColor = ACT == "order"
  S.mana, S.manaMax, S.health, S.healthMax = 2400, 3000, 1800, 2500
  if ACT == "order" then ns.db.bars.order = { "health", "mana", "combo", "power" }; ns.db.bars.combo.height = 18 end
  ns:ApplyAll()
end
if ACT == "classic" or ACT == "tooltip" then
  if ClaraComboPointsOptions then ClaraComboPointsOptions:Hide() end
  ns.db.bars.health.show = true
  S.mana, S.manaMax, S.health, S.healthMax = 2400, 3000, 1800, 2500
  ns.db.rows.above[1] = { 1943, 6774 }
  ns:SetSkin(ACT == "classic" and "CLASSIC" or "TOOLTIP")
end
if ACT == "edit" then
  if ClaraComboPointsOptions then ClaraComboPointsOptions:Hide() end
  ns.db.rows.above[1] = { 1943, 6774 }; ns.db.rows.below[1] = { 703 }
  ns:SetIconsLocked(false); ns:ApplyAll()
end
if SCENE:find("^craft") then
  if ClaraComboPointsHUD then ClaraComboPointsHUD:Hide() end
  local box = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  box:SetSize(330, 520)
  box:SetPoint("CENTER")
  box:SetBackdrop({ bgFile = "x", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 })
  box:SetBackdropColor(.12, .1, .08, 1)
  local p = ns.Craft.NewPanel(box)
  p.frame:SetPoint("TOPLEFT", 12, -12)
  p:Update(1, 300)
end
M.Fire("PLAYER_TARGET_CHANGED"); M.Frame(0.016)

local LAYERS = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4 }
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5 }
local function strata(f) while f do if f._strata then return STRATA[f._strata] end f = f._parent end return 3 end
local function frameOf(r) if r._kind == "Texture" or r._kind == "FontString" then return r._parent end return r end
local function visible(f) return f:IsVisible() end
local function alphaChain(f) local a = 1 while f do a = a * (f._alpha or 1) f = f._parent end return a end
local function clipOf(f)
  while f do
    if f._scrollParent then M.ResetLayout(); return { M.AbsRect(f._scrollParent) } end
    if f._clips then M.ResetLayout(); return { M.AbsRect(f) } end
    f = f._parent
  end
end

local out = assert(io.open(OUT_FILE, "w"))
local order = 0
local function emit(kind, f, layer, l, b, w, h, extra)
  order = order + 1
  local clip = clipOf(f)
  out:write(table.concat({ kind, strata(f), f._level or 1, layer, order, l, b, w, h, alphaChain(f),
    clip and table.concat(clip, ",") or "-", extra }, "\t"), "\n")
end

for _, r in ipairs(M.regions) do
  local f = frameOf(r)
  if r:IsShown() and visible(f) and r._layer ~= "HIGHLIGHT" and not (f._kind == "Slider" and r == f._thumb) then
    M.ResetLayout()
    local l, b, w, h = M.AbsRect(r)
    if r._kind == "Texture" and r._color then
      local c = r._vc or r._color
      if r._gradient then local g1 = r._gradient[2]; c = { g1.r, g1.g, g1.b, g1.a } end
      emit("rect", f, LAYERS[r._layer] or 3, l, b, w, h, table.concat({ c[1], c[2], c[3], c[4] }, ","))
    elseif r._kind == "Texture" and r._file then
      local c = r._vc or { 1, 1, 1, 1 }
      local file = r._file
      if type(file) == "string" and file:find("^ATLAS:") and r._tc then
        file = file .. "|" .. table.concat({ r._tc[1], r._tc[2], r._tc[3], r._tc[4] }, ",")
      end
      if type(file) == "number" then
        local name = "?"
        for _, sp in pairs(M.SPELLS) do if sp[2] == file then name = sp[1] end end
        file = "ICON:" .. name .. ":" .. (r._desat and "D" or "C")
      end
      emit("file", f, LAYERS[r._layer] or 3, l, b, w, h, table.concat({ c[1], c[2], c[3], c[4] }, ",") .. "\t" .. file .. "\t" .. (r._alpha or 1))
    elseif r._kind == "FontString" and r._text ~= nil then
      local obj = r._fontObject or ""
      local base = obj:find("Normal") and not obj:find("Chat") and not obj:find("Number") and { 1, .82, 0, 1 }
        or obj:find("Disable") and { .5, .5, .5, 1 } or { 1, 1, 1, 1 }
      local c = r._tc or base
      local font = r._font
      local s = f:GetEffectiveScale()
      emit("text", f, LAYERS[r._layer] or 4, l, b, w, h, table.concat({ c[1], c[2], c[3], c[4] }, ",") .. "\t" ..
        tostring(font[1]) .. "\t" .. (font[2] * s) .. "\t" .. tostring(font[3] or "") .. "\t" .. tostring(M.reveal(r._text)):gsub("\n", "  "):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. "\t" .. (r._jh or "CENTER"))
    end
  end
end
for _, f in ipairs(M.frames) do
  if visible(f) and f._template then
    M.ResetLayout()
    local l, b, w, h = M.AbsRect(f)
    local state = (f._selected and "selected" or "") .. (f._locked and "locked" or "") .. (f._checked and "checked" or "") .. (f._disabled and "disabled" or "")
    emit("tmpl", f, 0, l, b, w, h, f._template .. "\t" .. state)
  end
end
for _, f in ipairs(M.frames) do
  if visible(f) and f._backdrop then
    M.ResetLayout()
    local l, b, w, h = M.AbsRect(f)
    local c = f._bdColor or { 1, 1, 1, 1 }
    local e = f._bdBorder or { 1, 1, 1, 1 }
    emit("backdrop", f, 0, l, b, w, h, f._backdrop.edgeFile .. "\t" .. table.concat({ c[1], c[2], c[3], c[4] or 1 }, ",") .. "\t" .. table.concat({ e[1], e[2], e[3], e[4] or 1 }, ","))
  end
end
for _, f in ipairs(M.frames) do
  if visible(f) and f._kind == "Cooldown" and f._cd then
    M.ResetLayout()
    local l, b, w, h = M.AbsRect(f)
    local now = M.now or 0
    local left = f._cd[1] + f._cd[2] - now
    if left > 0 then
      local text = ""
      if not f._hideNumbers then
        if left >= (f._abbrev or 60) and left >= 60 then text = math.floor(left / 60) .. "m"
        elseif left >= 60 then text = string.format("%d:%02d", math.floor(left / 60), math.floor(left % 60))
        else text = tostring(math.ceil(left)) end
      end
      local size = f._countdown and f._countdown._font and f._countdown._font[2] or 12
      emit("cooldown", f, 5, l, b, w, h, (left / f._cd[2]) .. "\t" .. tostring(f._reverse and 1 or 0) .. "\t" .. text .. "\t" .. (size * f:GetEffectiveScale()))
    end
  end
end
for _, f in ipairs(M.frames) do
  if visible(f) then
    M.ResetLayout()
    local l, b, w, h = M.AbsRect(f)
    if f._kind == "StatusBar" and f._barcolor then
      local v = M.reveal(f._value) or 0
      local frac = math.max(0, math.min(1, (v - f._min) / (f._max - f._min)))
      local c = f._barcolor
      emit("rect", f, 3, l, b, w * frac, h, table.concat(c, ","))
    elseif f._kind == "Slider" and f._thumb then
      local frac = ((f._value or f._min) - f._min) / (f._max - f._min)
      local s = f:GetEffectiveScale()
      if f._thumb._file == "Interface\\Buttons\\WHITE8X8" then
        emit("rect", f, 4, l + frac * (w - 8 * s), b, 8 * s, h, "1,0.82,0,1")
      else
        emit("file", f, 4, l + frac * (w - 32 * s), b + h / 2 - 16 * s, 32 * s, 32 * s, "1,1,1,1\t" .. f._thumb._file .. "\t1")
      end
    end
  end
end
out:close()
