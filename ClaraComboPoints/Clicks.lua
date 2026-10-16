-- Clara Combo Points - a click on an icon of the HUD casts its spell (icons locked), when the
-- character knows that spell; the other icons (a debuff on the target, another class's aura...)
-- take no click. A spell that needs a form the character is not in (Feral Charge: Bear or Cat
-- Form; Maul: Bear Form; a warrior's stance, a rogue's Stealth) takes that form first: a second
-- click casts the spell (one click, one action: the game's rule).
-- Casting needs the game's secure action buttons, which addons can neither move, show nor hide
-- in combat. They live in a layer of their own over the HUD (outside it, so that the HUD stays
-- free to move and hide in combat), placed on the icons out of combat; in combat they stay where
-- the icons were when it began. A druid's icons are not in the same place in Bear Form (the rows
-- above come down onto the rage bar: Core.lua), so a druid has a second layer, placed for Bear
-- Form; each layer only shows in its forms. Out of the forms the HUD shows in, a druid's layers
-- keep the places they were given in them.

local _, ns = ...

local GetSpellInfo = C_Spell and C_Spell.GetSpellInfo
local SpellName = C_Spell and C_Spell.GetSpellName
local SpellSubtext = C_Spell and C_Spell.GetSpellSubtext
local SYNC_EVERY = .25 -- out of combat, the buttons follow the icons this often (when they moved)
local CAT_FORMS, BEAR_FORMS = { [768] = true }, { [5487] = true, [9634] = true } -- (Dire Bear Form)
local POWER_RAGE, POWER_ENERGY = 1, 3

local layers = {} -- [1]: the HUD as it is out of Bear Form; [2]: a druid's, in Bear Form
local placed      -- what the buttons were placed for (nothing to do while it stays the same)
local syncing     -- the HUD laid out for another form, to read its icons' places

local function Known(id)
  if IsPlayerSpell and IsPlayerSpell(id) then return true end
  return C_SpellBook ~= nil and C_SpellBook.IsSpellKnown ~= nil and C_SpellBook.IsSpellKnown(id) == true
end

local function Plain(v) return not (issecretvalue and issecretvalue(v)) end

-- What a click on an icon casts: the rank chosen for it, else its spell by name (the highest
-- rank the character has); nothing when the character does not know it. Also its spell ID.
local function Castable(slot)
  local spell = slot.spell
  if spell == nil then return end
  if slot.exact then
    if type(spell) == "number" and Known(spell) then return spell, spell end
    return
  end
  local name = slot.name or (type(spell) == "string" and spell) or nil
  local info = name and GetSpellInfo and GetSpellInfo(name)
  if info and type(info.spellID) == "number" and Known(info.spellID) then return name, info.spellID end
  if type(spell) == "number" and Known(spell) then return spell, spell end
end

---------------------------------------------------------------------------
-- Forms: the stance bar (a druid's forms, a warrior's stances, a rogue's Stealth), and the
-- ones a spell needs, read from its tooltip ("Requires Bear Form, Dire Bear Form").
---------------------------------------------------------------------------
local seenCat, seenBear -- a druid's Cat and Bear Form on the stance bar, as seen worn (energy, rage)

local function StanceBar()
  local bar = { names = {} }
  if not (GetNumShapeshiftForms and GetShapeshiftFormInfo and SpellName) then return bar end
  for i = 1, GetNumShapeshiftForms() or 0 do
    local _, _, _, id = GetShapeshiftFormInfo(i)
    local name = type(id) == "number" and SpellName(id) or nil
    if type(name) == "string" and Plain(name) then bar.names[i] = name end
    if CAT_FORMS[id] then bar.cat = i elseif BEAR_FORMS[id] then bar.bear = i end
  end
  -- a form of this client under another ID: known by the power it gives
  local form = GetShapeshiftForm and GetShapeshiftForm()
  if type(form) == "number" and Plain(form) and form > 0 and UnitPowerType then
    local power = UnitPowerType("player")
    if power == POWER_ENERGY then seenCat = form elseif power == POWER_RAGE then seenBear = form end
  end
  bar.cat, bar.bear = bar.cat or seenCat, bar.bear or seenBear
  return bar
end

-- The beginning of a tooltip's "Requires ..." line, in the client's language.
local REQUIRES = {}
do
  local text = _G.SPELL_REQUIRED_FORM
  local prefix = type(text) == "string" and text:match("^(.-)%%s")
  if prefix and prefix ~= "" then REQUIRES[1] = prefix end
  for _, p in ipairs({ "Requires ", "Nécessite ", "Requiert ", "Benötigt " }) do REQUIRES[#REQUIRES + 1] = p end
end

local needs = {} -- spell ID -> the stance bar's forms it needs (the one to take first), or false

local function FormsOf(id, bar)
  if needs[id] ~= nil then return needs[id] end
  local found, order = {}, {}
  local data = C_TooltipInfo and C_TooltipInfo.GetSpellByID and C_TooltipInfo.GetSpellByID(id)
  for n, line in ipairs(type(data) == "table" and type(data.lines) == "table" and data.lines or {}) do
    local text = line.leftText
    if type(text) == "string" and Plain(text) then
      text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
      local requires
      for _, p in ipairs(REQUIRES) do if text:sub(1, #p) == p then requires = true break end end
      if requires then
        for i, name in pairs(bar.names) do
          local at = text:find(name, 1, true)
          if at and not found[i] then
            found[i] = n * 10000 + at -- in the order the tooltip names them
            order[#order + 1] = i
          end
        end
      end
    end
  end
  table.sort(order, function(a, b) return found[a] < found[b] end)
  needs[id] = #order > 0 and order or false
  return needs[id]
end

-- The spell's name as a macro casts it: "Maul", or "Maul(Rank 3)" for one rank.
local function CastName(spell)
  if type(spell) ~= "number" then return spell end
  local name = SpellName and SpellName(spell)
  if type(name) ~= "string" or not Plain(name) then return end
  local rank = SpellSubtext and SpellSubtext(spell)
  if type(rank) == "string" and Plain(rank) and rank ~= "" then name = name .. "(" .. rank .. ")" end
  return name
end

-- The click of a spell that needs a form: the spell in one of its forms, else the first of them.
local function FormMacro(spell, id, bar)
  local forms = id and FormsOf(id, bar)
  if not forms then return end
  local name = CastName(spell)
  if not name then return end
  return ("/cast [form:%s] %s; %s"):format(table.concat(forms, "/"), name, bar.names[forms[1]])
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------
local function Tooltip(self)
  if not GameTooltip or not self.spellID then return end
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  if not (GameTooltip.SetSpellByID and pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellID)) then
    GameTooltip:SetText(tostring(self.spell))
  end
  GameTooltip:Show()
end

local function Layer(n)
  local layer = layers[n]
  if layer then return layer end
  layer = CreateFrame("Frame", "ClaraComboPointsClicks" .. (n > 1 and n or ""), UIParent)
  layer:SetAllPoints(UIParent)
  layer:SetFrameStrata(ns.hud:GetFrameStrata())
  layer:SetFrameLevel(ns.hud:GetFrameLevel() + 50)
  layer.buttons = {}
  layers[n] = layer
  return layer
end

local function Button(layer, i)
  local b = layer.buttons[i]
  if b then return b end
  b = CreateFrame("Button", layer:GetName() .. "Button" .. i, layer, "SecureActionButtonTemplate")
  b:RegisterForClicks("LeftButtonUp")
  b:SetAttribute("useOnKeyDown", false)
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:SetScript("OnEnter", Tooltip)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  layer.buttons[i] = b
  return b
end

-- The castable icons shown now, each with its rect in UIParent units and its click.
local function Read(bar)
  local list = {}
  local ui = UIParent:GetEffectiveScale()
  ns:ForEachIcon(function(slot)
    if not slot:IsVisible() then return end
    local spell, id = Castable(slot)
    if spell == nil then return end
    local l, b, w, h = slot:GetRect()
    if not l then return end
    local s = slot:GetEffectiveScale() / ui
    list[#list + 1] = { spell = spell, id = id, macro = FormMacro(spell, id, bar),
      l = l * s, b = b * s, w = w * s, h = h * s }
  end)
  return list
end

local function Key(list)
  local parts = {}
  for _, w in ipairs(list) do
    parts[#parts + 1] = ("%s:%s:%.1f:%.1f:%.1f:%.1f"):format(tostring(w.spell), w.macro or "", w.l, w.b, w.w, w.h)
  end
  return table.concat(parts, "|")
end

-- One layer's buttons on its icons, shown in the forms the driver says (nil: always).
local function Place(n, list, driver)
  if not list or #list == 0 then
    local layer = layers[n]
    if not layer then return end
    for _, b in ipairs(layer.buttons) do b:Hide() end
    UnregisterStateDriver(layer, "visibility")
    layer:Hide()
    return
  end
  local layer = Layer(n)
  for i, w in ipairs(list) do
    local b = Button(layer, i)
    if w.macro then
      b:SetAttribute("type1", "macro")
      b:SetAttribute("macrotext", w.macro)
      b:SetAttribute("spell", nil)
    else
      b:SetAttribute("type1", "spell")
      b:SetAttribute("spell", w.spell)
      b:SetAttribute("macrotext", nil)
    end
    b.spell, b.spellID = w.spell, w.id
    b:ClearAllPoints()
    b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", w.l, w.b)
    b:SetSize(w.w, w.h)
    b:Show()
  end
  for i = #list + 1, #layer.buttons do layer.buttons[i]:Hide() end
  if driver then
    RegisterStateDriver(layer, "visibility", driver)
  else
    UnregisterStateDriver(layer, "visibility")
    layer:Show()
  end
end

-- What a druid's layout depends on, besides the form: where the HUD is, its scale, its bars,
-- its icons. Out of the forms the HUD shows in, the layers placed in them stay while it holds.
local function DruidSettings()
  local db, parts = ns.db, {}
  local x, y = ns.hud:GetCenter()
  parts[#parts + 1] = ("%s:%s:%s"):format(tostring(x), tostring(y), tostring(ns.hud:GetEffectiveScale()))
  for _, side in ipairs(ns.SIDES) do
    for k = 1, ns.MAX_ROWS do
      for _, entry in ipairs(db.rows[side][k]) do
        parts[#parts + 1] = tostring(ns:EntrySpell(entry)) .. (type(entry) == "table" and entry.exact and "!" or "")
      end
      parts[#parts + 1] = "/"
    end
  end
  for _, t in ipairs({ db.icons, db.disabled, db.bars.combo, db.bars.power, db.bars.mana, db.bars.health }) do
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. tostring(t[k]) end
  end
  parts[#parts + 1] = table.concat(db.bars.order, ",") .. tostring(db.druidCatOnly) .. tostring(db.bearIconsFixed)
  return table.concat(parts, ";")
end

-- A druid's two layouts: out of Bear Form, and in it (the HUD laid out for each in turn, then
-- back as it was: nothing is drawn meanwhile).
local function DruidLists(bar)
  local now = ns.iconsOnBar
  syncing = true
  ns.iconsOnBar = false
  ns:LayoutIcons()
  local main = Read(bar)
  local bear
  if bar.bear and not ns.db.bearIconsFixed then
    ns.iconsOnBar = true
    ns:LayoutIcons()
    bear = Read(bar)
  end
  ns.iconsOnBar = now
  ns:LayoutIcons()
  syncing = nil
  return main, bear
end

-- Puts the buttons on the icons (out of combat; in combat, nothing can move them).
function ns:SyncClickers()
  if syncing or not self.hud or InCombatLockdown() then return end
  local db = self.db
  local on = self.enabled and db and db.locked and not self:EditingIcons()
  local shown = on and self.hud:IsVisible() and self.iconLayer:IsVisible()
  local bar = StanceBar()
  if not self.isDruid then
    local list = shown and Read(bar) or {}
    local key = "1" .. Key(list)
    if key == placed then return end
    placed = key
    Place(1, list)
    Place(2)
    return
  end
  if not shown then
    -- hidden by its form alone: the layers placed in the forms the HUD shows in stay
    if on and self:ShownOutOfForm() and placed and placed.settings == DruidSettings() then return end
    if placed ~= nil then
      placed = nil
      Place(1)
      Place(2)
    end
    return
  end
  local current = Key(Read(bar))
  local settings = DruidSettings()
  local forms = ("%s/%s"):format(tostring(bar.cat), tostring(bar.bear))
  if type(placed) == "table" and placed.current == current and placed.settings == settings and placed.forms == forms
    and placed.onBar == self.iconsOnBar then
    return
  end
  local main, bear = DruidLists(bar)
  placed = { current = current, settings = settings, forms = forms, onBar = self.iconsOnBar }
  local catOnly = db.druidCatOnly
  if bear then
    Place(1, main, catOnly and (bar.cat and ("[form:%d] show; hide"):format(bar.cat) or "hide")
      or ("[form:%d] hide; show"):format(bar.bear))
    Place(2, bear, ("[form:%d] show; hide"):format(bar.bear))
  else -- the same places in every form
    local feral = {}
    if bar.cat then feral[#feral + 1] = bar.cat end
    if bar.bear then feral[#feral + 1] = bar.bear end
    Place(1, main, catOnly and (#feral > 0 and ("[form:%s] show; hide"):format(table.concat(feral, "/")) or "hide") or nil)
    Place(2)
  end
end

-- The click buttons now (for the tests): the first layer's, it, and every layer.
function ns:ClickButtons()
  local layer = layers[1]
  return layer and layer.buttons or {}, layer, layers
end

-- Out of combat the buttons follow the icons (moved, resized, shown or hidden); the last chance
-- is the moment combat starts. A new spell or form: what each spell needs is read again.
local ticker = CreateFrame("Frame")
local wait = 0
table.insert(ns.onEnable, function()
  ticker:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = SYNC_EVERY
    if not InCombatLockdown() then ns:SyncClickers() end
  end)
  ticker:RegisterEvent("PLAYER_REGEN_DISABLED")
  ticker:RegisterEvent("SPELLS_CHANGED")
  pcall(ticker.RegisterEvent, ticker, "UPDATE_SHAPESHIFT_FORMS")
  ticker:SetScript("OnEvent", function(_, event)
    if event ~= "PLAYER_REGEN_DISABLED" then
      wipe(needs)
      placed = nil
    end
    ns:SyncClickers()
  end)
end)
