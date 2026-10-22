-- Clara Combo Points - a click on an icon of the HUD casts its spell (icons locked), when the
-- character knows that spell; the other icons (a debuff on the target, another class's aura...)
-- take no click. An item's icon uses the item (one for a weapon: left click on the main hand,
-- right click on the off hand). A spell that needs a form the character is not in (Maul: Bear
-- Form; a warrior's stance) or stealth (Sap: Stealth; Pounce: Cat Form, then Prowl) takes that
-- first: a next click casts the spell (one click, one action: the game's rule). A spell its
-- tooltip gives two forms for, one per line (Feral Charge: Bear Form, and Cat Form for its leap):
-- left click the first (Bear Form, then the charge), right click the second (Cat Form, then the
-- leap).
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

-- The ID of a spell the character knows: the one given, or the spell it is a variant of (in
-- Bear Form the game names Forever's Feral Charge by its Bear Form variant, which is not "known"
-- itself).
local GetBaseSpell = C_Spell and C_Spell.GetBaseSpell
local function KnownID(id)
  if type(id) ~= "number" or not Plain(id) then return end
  if Known(id) then return id end
  local base = GetBaseSpell and GetBaseSpell(id)
  if type(base) == "number" and Plain(base) and base ~= id and Known(base) then return base end
end

-- What a click on an icon casts: the rank chosen for it, else its spell by name (the highest
-- rank the character has); nothing when the character does not know it. Also its spell ID. A
-- name once found known keeps its ID, for a form that gives the name to another spell.
local knownByName = {}
local function Castable(slot)
  local spell = slot.spell
  if spell == nil then return end
  if slot.item then return spell, nil end -- an item: used
  if slot.exact then
    local id = KnownID(spell)
    if id then return spell, id end
    return
  end
  local name = slot.name or (type(spell) == "string" and spell) or nil
  local info = name and GetSpellInfo and GetSpellInfo(name)
  local id = info and KnownID(info.spellID)
  if id then
    knownByName[name] = id
    return name, id
  end
  if name and knownByName[name] and Known(knownByName[name]) then return name, knownByName[name] end
  id = KnownID(spell)
  if id then return spell, id end
end

---------------------------------------------------------------------------
-- Forms: the stance bar (a druid's forms, a warrior's stances, a rogue's Stealth), and the
-- ones a spell needs, read from its tooltip ("Requires Bear Form, Dire Bear Form"); stealth.
---------------------------------------------------------------------------
local seenCat, seenBear -- a druid's Cat and Bear Form on the stance bar, as seen worn (energy, rage)

-- Is a form of the stance bar one of these (by its ID, else by its name: the game may give the
-- stance bar another ID than the spellbook's)?
local function FormIs(id, name, forms)
  if forms[id] then return true end
  if not name then return false end
  for form in pairs(forms) do if SpellName(form) == name then return true end end
  return false
end

local function StanceBar()
  local bar = { names = {} }
  if not (GetNumShapeshiftForms and GetShapeshiftFormInfo and SpellName) then return bar end
  for i = 1, GetNumShapeshiftForms() or 0 do
    local _, _, _, id = GetShapeshiftFormInfo(i)
    local name = type(id) == "number" and SpellName(id) or nil
    if type(name) == "string" and Plain(name) then bar.names[i] = name else name = nil end
    if FormIs(id, name, CAT_FORMS) then bar.cat = i elseif FormIs(id, name, BEAR_FORMS) then bar.bear = i end
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

-- A tooltip's requirement lines ("Requires Bear Form, Dire Bear Form", "Nécessite la forme
-- d'ours ou la forme d'ours redoutable", "Requiert Forme de félin"): read without case, accents
-- or punctuation (ns:SearchKey), in the client's language.
local REQUIRES = { "requires", "necessite", "requiert", "benotigt" }
do
  local text = _G.SPELL_REQUIRED_FORM
  local prefix = type(text) == "string" and text:match("^(.-)%%s")
  local key = prefix and ns:SearchKey(prefix)
  if key and key ~= "" then table.insert(REQUIRES, 1, key) end
end

-- Openers that need stealth, whatever their tooltip says: Ambush, Garrote, Cheap Shot, Sap, Pick
-- Pocket, Premeditation (rogues); Pounce, Ravage (druids, in Cat Form). The stealth each class
-- takes first: Stealth, Prowl.
local STEALTH_OPENERS = { 8676, 703, 1833, 6770, 921, 14183, 9005, 6785 }
local STEALTH = { ROGUE = 1784, DRUID = 5215 }

-- Feral Charge (16979; WoW Forever's, 1238122: the charge in Bear Form, the leap in Cat Form),
-- whatever its tooltip gives: in game, the tooltip of Forever's one has been seen to give no
-- requirement line to addons.
local FERAL_CHARGE = { 16979, 1238122 }

-- What a spell needs: { forms = the stance bar's forms it needs, the one to take first; stealth
-- = the stealth spell to cast first; first, second = the forms of each of two requirement lines,
-- when the tooltip has two }, or false. A "nothing" is read again every few seconds for a
-- minute: just after logging in, the game may not have the spell's tooltip or the stance bar
-- yet. (A new spell or form reads them all again: the events at the end.)
local needs, readAt, firstAt, readOf = {}, {}, {}, {}
local RECHECK, RECHECK_FOR = 5, 60 -- seconds
local recheckUntil = 0 -- a "nothing" may still be read again until then

local function Needs(id, bar)
  local now = GetTime()
  if needs[id] or (needs[id] == false and (now - readAt[id] < RECHECK or now - firstAt[id] >= RECHECK_FOR)) then
    return needs[id]
  end
  local _, class = UnitClass("player")
  local stealthName = STEALTH[class] and SpellName and SpellName(STEALTH[class])
  if not (type(stealthName) == "string" and Plain(stealthName)) then stealthName = nil end
  local stealthKey = stealthName and ns:SearchKey(stealthName)
  local keys = {}
  for i, name in pairs(bar.names) do keys[i] = ns:SearchKey(name) end
  local found, order, stealth, groups = {}, {}, false, {}
  local data = C_TooltipInfo and C_TooltipInfo.GetSpellByID and C_TooltipInfo.GetSpellByID(id)
  local lines = type(data) == "table" and type(data.lines) == "table" and data.lines or {}
  if C_Spell and C_Spell.IsSpellDataCached and not C_Spell.IsSpellDataCached(id) and C_Spell.RequestLoadSpellData then
    C_Spell.RequestLoadSpellData(id) -- (what is read now is read again in a while if it gave nothing)
  end
  local read = { lines = #lines, requires = {} } -- (for /cl debug)
  for n, line in ipairs(lines) do
    local text = line.leftText
    if type(text) == "string" and Plain(text) then
      local key = ns:SearchKey((text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
      local requires
      for _, p in ipairs(REQUIRES) do if key:sub(1, #p) == p then requires = true break end end
      if requires then
        read.requires[#read.requires + 1] = text
        if stealthKey and key:find(stealthKey, 1, true) then stealth = true end
        local group = {}
        for i, k in pairs(keys) do
          local at = k ~= "" and k ~= stealthKey and key:find(k, 1, true)
          if at and not found[i] then
            found[i] = n * 10000 + at -- in the order the tooltip names them
            order[#order + 1] = i
            group[#group + 1] = i
          end
        end
        if #group > 0 then groups[#groups + 1] = group end
      end
    end
  end
  local name = SpellName and SpellName(id)
  -- Feral Charge: Bear Form, then Cat Form, if the tooltip named neither
  if #order == 0 and type(name) == "string" and Plain(name) then
    for _, fc in ipairs(FERAL_CHARGE) do
      if SpellName(fc) == name then
        if bar.bear then found[bar.bear] = 1; order[#order + 1] = bar.bear; groups[#groups + 1] = { bar.bear } end
        if bar.cat then found[bar.cat] = 2; order[#order + 1] = bar.cat; groups[#groups + 1] = { bar.cat } end
        read.list = #order > 0
        break
      end
    end
  end
  if stealthName and type(name) == "string" and Plain(name) then
    for _, opener in ipairs(STEALTH_OPENERS) do
      if SpellName(opener) == name then stealth = true break end
    end
  end
  local function ByPlace(a, b) return found[a] < found[b] end
  table.sort(order, ByPlace)
  for _, group in ipairs(groups) do table.sort(group, ByPlace) end
  local need = false
  if #order > 0 or stealth then need = { forms = #order > 0 and order or nil, stealth = stealth and stealthName or nil } end
  if need and #groups >= 2 and not stealth then need.first, need.second = groups[1], groups[2] end
  firstAt[id] = firstAt[id] or now
  needs[id], readAt[id], readOf[id] = need, now, read
  if not need then recheckUntil = math.max(recheckUntil, firstAt[id] + RECHECK_FOR) end
  return need
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

-- The click of a spell that needs a form or stealth: the spell when all is there, else what
-- is missing first (the form, then the stealth). Two forms on two lines: the left click's, and
-- the right click's.
-- (a form known only by its place on the stance bar, without a name to cast: no macro)
local function InForms(forms, name, bar)
  local form = bar.names[forms[1]]
  if not form then return end
  return ("/cast [form:%s] %s; %s"):format(table.concat(forms, "/"), name, form)
end
local function FormMacro(spell, id, bar)
  local need = id and Needs(id, bar)
  if not need then return end
  local name = CastName(spell)
  if not name then return end
  if need.second then
    local left, right = InForms(need.first, name, bar), InForms(need.second, name, bar)
    if left and right then return left, right end
    return left or right
  end
  if need.forms then
    local forms, form = table.concat(need.forms, "/"), bar.names[need.forms[1]]
    if not form then return end
    if need.stealth then
      return ("/cast [form:%s,stealth] %s; [form:%s] %s; %s"):format(forms, name, forms, need.stealth, form)
    end
    return ("/cast [form:%s] %s; %s"):format(forms, name, form)
  end
  return ("/cast [stealth] %s; %s"):format(name, need.stealth)
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------
local function Tooltip(self)
  if not GameTooltip then return end
  if self.item then
    ns:TooltipAt(self)
    if not (GameTooltip.SetItemByID and pcall(GameTooltip.SetItemByID, GameTooltip, self.item)) then
      GameTooltip:SetText(ns:ItemName(self.item) or tostring(self.spell))
    end
    GameTooltip:Show()
    return
  end
  if not self.spellID then return end
  ns:TooltipAt(self)
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
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp") -- (the right button: a weapon's item on the off hand)
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
    local w = { spell = spell, id = id, l = l * s, b = b * s, w = w * s, h = h * s }
    if slot.item then
      w.item = slot.item
      if ns:IsWeaponItem(slot.item) then -- used on a weapon: the main hand, or the off hand
        w.macro = ("/use %s\n/use 16"):format(spell)
        w.macro2 = ("/use %s\n/use 17"):format(spell)
      end
    else
      w.macro, w.macro2 = FormMacro(spell, id, bar)
    end
    list[#list + 1] = w
  end)
  return list
end

local function Key(list)
  local parts = {}
  for _, w in ipairs(list) do
    parts[#parts + 1] = ("%s:%s:%s:%.1f:%.1f:%.1f:%.1f"):format(tostring(w.spell), w.macro or "", w.macro2 or "", w.l, w.b, w.w, w.h)
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
    b:SetAttribute("macrotext2", w.macro2)
    b:SetAttribute("item", nil)
    if w.macro then
      b:SetAttribute("type1", "macro")
      b:SetAttribute("macrotext", w.macro)
      b:SetAttribute("spell", nil)
    elseif w.item then
      b:SetAttribute("type1", "item")
      b:SetAttribute("item", w.spell)
      b:SetAttribute("spell", nil)
      b:SetAttribute("macrotext", nil)
    else
      b:SetAttribute("type1", "spell")
      b:SetAttribute("spell", w.spell)
      b:SetAttribute("macrotext", nil)
    end
    -- the right click: its own macro (a weapon's item on the off hand, a spell's second form),
    -- else the same as the left one (its attributes: macrotext2, else macrotext...)
    b:SetAttribute("type2", w.macro2 and "macro" or b:GetAttribute("type1"))
    b.spell, b.spellID, b.item = w.spell, w.id, w.item
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

-- What the buttons depend on, besides the spells known, their tooltips and the stance bar
-- (read again on their events, below): put in a list without making anything (the check runs
-- often), to be compared with the list of the last time they were placed.
local seenList, nowList, nowCount, seenCount = {}, {}, 0, -1
local lastFull = 0 -- when they were last read in full
local function Put(v) nowCount = nowCount + 1; nowList[nowCount] = v end
local function PutTable(t) for k, v in pairs(t) do Put(k); Put(v) end end
local function PutSlot(slot)
  Put(slot); Put(slot:IsVisible()); Put(slot.spell); Put(slot.item); Put(slot.name); Put(slot.exact)
  local l, b, w, h = slot:GetRect()
  Put(l); Put(b); Put(w); Put(h); Put(slot:GetEffectiveScale())
end
-- (a druid's: the HUD's place and settings, which the layout in the other form depends on; the
-- form and power, which tell the stance bar's Cat and Bear Form when it gives other IDs)
local function PutDruid(db, shown)
  local x, y = ns.hud:GetCenter()
  Put(x); Put(y); Put(ns.hud:GetEffectiveScale())
  for _, side in ipairs(ns.SIDES) do
    for k = 1, ns.MAX_ROWS do
      for _, entry in ipairs(db.rows[side][k]) do
        Put(ns:EntrySpell(entry)); Put(type(entry) == "table" and entry.exact or nil)
      end
      Put("/")
    end
  end
  PutTable(db.icons); PutTable(db.disabled)
  PutTable(db.bars.combo); PutTable(db.bars.power); PutTable(db.bars.mana); PutTable(db.bars.health)
  for _, key in ipairs(db.bars.order) do Put(key) end
  Put(db.druidCatOnly); Put(db.bearIconsFixed)
  local form = GetShapeshiftForm and GetShapeshiftForm()
  local power = UnitPowerType and UnitPowerType("player")
  Put(Plain(form) and form or nil); Put(Plain(power) and power or nil)
  if not shown then Put(ns:ShownOutOfForm()) end
end

local function Unchanged(db, on, shown)
  nowCount = 0
  Put(db); Put(on); Put(shown); Put(ns.isDruid); Put(ns.iconsOnBar); Put(UIParent:GetEffectiveScale())
  if shown then ns:ForEachIcon(PutSlot) end
  if ns.isDruid and db then PutDruid(db, shown) end
  if nowCount ~= seenCount then return false end
  for i = 1, nowCount do
    if nowList[i] ~= seenList[i] then return false end
  end
  return true
end

-- The buttons placed for what was read last (kept once they are).
local function Placed()
  seenList, nowList, seenCount = nowList, seenList, nowCount
end

local PlaceAll -- below

-- Puts the buttons on the icons (out of combat; in combat, nothing can move them). Nothing is
-- read again while nothing they depend on changed (but a "nothing" a tooltip gave, every few
-- seconds for a while).
function ns:SyncClickers()
  if syncing or not self.hud or InCombatLockdown() then return end
  local db = self.db
  local on = self.enabled and db and db.locked and not self:EditingIcons()
  local shown = on and self.hud:IsVisible() and self.iconLayer:IsVisible()
  local t = GetTime()
  if Unchanged(db, on, shown) and not (t < recheckUntil and t - lastFull >= RECHECK) then return end
  lastFull = t
  PlaceAll(self, db, on, shown)
  Placed()
end

-- The places and clicks read in full, and the buttons placed when they changed.
function PlaceAll(self, db, on, shown)
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

-- What each click button does (/cl debug): its spell, and the macro or spell it casts.
function ns:DebugClicks()
  local out = {}
  for n, layer in pairs(layers) do
    for i, b in ipairs(layer.buttons) do
      if b:IsShown() then
        local right = b:GetAttribute("macrotext2")
        local read = b.spellID and readOf[b.spellID]
        local how = ""
        if read and (read.list or #read.requires > 0) then
          how = ("  [tooltip: %d lines, requires: %s%s]"):format(read.lines,
            #read.requires > 0 and table.concat(read.requires, " / ") or "none", read.list and "; forms from the addon's list" or "")
        end
        out[#out + 1] = ("click %d.%d: %s (%s) -> %s%s%s  [at %d,%d%s]"):format(n, i, tostring(b.spell), tostring(b.spellID),
          tostring(b:GetAttribute("macrotext") or b:GetAttribute("spell") or b:GetAttribute("item")),
          right and (" | right: " .. right) or "", how, math.floor((b:GetLeft() or 0) + .5), math.floor((b:GetBottom() or 0) + .5),
          layer:IsShown() and "" or ", layer hidden")
      end
    end
  end
  local bar = StanceBar()
  local forms = {}
  for i, name in pairs(bar.names) do forms[#forms + 1] = i .. "=" .. name end
  table.sort(forms)
  out[#out + 1] = ("stance bar: %s; Cat Form %s, Bear Form %s; form now %s"):format(#forms > 0 and table.concat(forms, ", ") or "none",
    tostring(bar.cat), tostring(bar.bear), tostring(GetShapeshiftForm and GetShapeshiftForm()))
  -- where the icons are now (to compare with the buttons)
  ns:ForEachIcon(function(slot)
    if slot:IsVisible() and slot.spell ~= nil then
      out[#out + 1] = ("icon %s %d.%d: %s at %d,%d"):format(slot.side, slot.k, slot.index or 0, tostring(slot.spell),
        math.floor((slot:GetLeft() or 0) * slot:GetEffectiveScale() / UIParent:GetEffectiveScale() + .5),
        math.floor((slot:GetBottom() or 0) * slot:GetEffectiveScale() / UIParent:GetEffectiveScale() + .5))
    end
  end)
  return out
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
      wipe(firstAt)
      placed = nil
    end
    seenCount = -1 -- (read in full)
    ns:SyncClickers()
  end)
end)
