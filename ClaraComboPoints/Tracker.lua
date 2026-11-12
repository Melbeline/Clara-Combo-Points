-- Clara Combo Points - buff, debuff and spell icons
-- Up to three rows above the HUD (growing upward) and three below the bar (growing downward),
-- 20 icons each. Warriors start with one row where the combo points would be: Sunder Armor,
-- Demoralizing Shout, Hamstring, Battle Shout, Bloodrage.
--
-- Spells are kept as IDs (or names) and looked up by spell name, so every rank matches (unless
-- one rank is picked), in every client language. Each icon watches where its entry says (auto:
-- your buffs, then the target's debuffs, then your debuffs; or only you, or only the target,
-- any / enemy / friendly) and shows, in this order:
--   - the aura when it is up, with its stacks and time left;
--   - else the spell's own cooldown (not the global cooldown) when it runs;
--   - else the spell ready (spells with a cooldown) or the aura missing (grayed out).
-- Weapon imbues (Rockbiter Weapon...) watch the enchantment on your weapons instead of an aura.
-- In combat the game hides auras from addons; one of the game's own aura buttons, given the
-- spell's IDs, shows the aura over the icon instead (see the end of this file's live state).
-- Icons look like the action bar buttons: the game's button frame around them, the art kept
-- inside it by a mask, the cooldown swipe and countdown numbers ("2m" from two minutes up,
-- then "1:59", then seconds), charges and stacks bottom right.
--
-- Shapes: the row shares the bar's width (cells cropped, not stretched), or each icon is a
-- combo point cell, or square at the chosen size.

local ADDON, ns = ...
local L = ns.L

local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max
local issecretvalue = issecretvalue or function() return false end
local GetSpellTexture = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
local GetSpellInfo = (C_Spell and C_Spell.GetSpellInfo) or nil
local GetSpellCooldown = C_Spell and C_Spell.GetSpellCooldown
local GetSpellCooldownDuration = C_Spell and C_Spell.GetSpellCooldownDuration
local GetSpellCharges = C_Spell and C_Spell.GetSpellCharges
local GetDisplayCount = C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount

local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"
local FRAME_ATLAS = "UI-HUD-ActionBar-IconFrame" -- the action button frame
local FONT = "Fonts\\FRIZQT__.TTF"
local TRIM = .08             -- icon border cut off
local CORNER = .22           -- share of the button frame (and of the icon's short side) in a corner
local MISSING_ALPHA = .45
local GCD = 1.5              -- a cooldown this short is only the global cooldown
local ABBREV = 120           -- countdown: "2m" from two minutes up, "1:59" below
local MASK_ATLAS = "UI-HUD-CoolDownManager-Mask" -- keeps the icon art inside the frame (fills the icon)
local CHECKED_ATLAS = "UI-HUD-ActionBar-IconFrame-Mouseover" -- the game's action and stance buttons checked: a gold border
local CHECKED_FILE = "Interface\\Buttons\\CheckButtonHilight" -- (without that atlas: the classic checked look)
local ACTIVE_ICON = "Interface\\Icons\\Spell_Nature_WispSplode" -- (when the game shows none of its own: see ActiveIcon)
local ACTION_SLOTS = 180     -- the action bars' slots read for a spell's icon as they show it
-- where each icon looks for its aura (on = the entry's condition; auto for plain entries)
local LOOKUPS = {
  auto   = { { "player", "HELPFUL" }, { "target", "HARMFUL" }, { "player", "HARMFUL" } },
  self   = { { "player", "HELPFUL" }, { "player", "HARMFUL" } },
  target = { { "target", "HELPFUL" }, { "target", "HARMFUL" } },
  enemy  = { { "target", "HARMFUL" }, { "target", "HELPFUL" } },
  friend = { { "target", "HELPFUL" }, { "target", "HARMFUL" } },
}
ns.CONDITIONS = { "auto", "self", "target", "enemy", "friend" }
local GetAuraDuration = C_UnitAuras and C_UnitAuras.GetAuraDuration
local GetAuraDataByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex

-- A row entry: a spell ID or name, or { spell = ID or name, on = condition, exact = true,
-- mine = true } (exact: this rank only; mine: only the aura you cast, not another player's).
function ns:EntrySpell(entry) if type(entry) == "table" then return entry.spell end return entry end
function ns:EntryOn(entry) return type(entry) == "table" and entry.on or "auto" end
function ns:EntryMine(entry) return type(entry) == "table" and entry.mine == true end
local MINE = "|PLAYER" -- aura filter: cast by you

local rows = { above = {}, below = {} }
local NONE = {} -- (a row without spells, in loops that run often: nothing made each time)
local dirty

local function Plain(v)
  if not issecretvalue(v) and type(v) == "number" then return v end
end

-- Lower case, accented capitals included (string.lower leaves "É" or "Ü" as they are).
local function LowerAccent(c) return "\195" .. string.char(c:byte() + 32) end
local function Fold(s)
  return (s:lower():gsub("\195([\128-\158])", LowerAccent))
end
ns.Fold = function(_, s) return Fold(s) end

-- A spell's own icon: the game's original one (while on, Shadowmeld's or an aspect's icon is the star: not its own).
function ns:SpellIcon(spell)
  local item = self:ItemOf(spell)
  if item then return self:ItemIcon(item) or QUESTION_MARK end
  if GetSpellTexture then
    local ok, icon, original = pcall(GetSpellTexture, spell)
    if ok and type(original) == "number" and not issecretvalue(original) then return original end
    if ok and icon and not issecretvalue(icon) then return icon end
  end
  return QUESTION_MARK
end

-- The icon of a row entry's spell (one tracked by name: its icon once seen).
function ns:EntryIcon(spell)
  local icon = self:SpellIcon(spell)
  if icon == QUESTION_MARK and self:SpellName(spell) then return self:SeenIcon(self:SpellName(spell)) end
  return icon
end

-- Icons of spells tracked by name (unknown to this character), learned when the aura is seen.
function ns:SeenIcon(name)
  local seen = self.sv and self.sv.seenIcons
  return seen and seen[name] or QUESTION_MARK
end

function ns:RememberIcon(name, icon)
  if self.sv and name and (type(icon) == "number" or type(icon) == "string") then
    self.sv.seenIcons[name] = icon
  end
end

local function RowName(side, k)
  return (side == "above" and L.ROW_ABOVE or L.ROW_BELOW):format(k)
end
ns.RowName = function(_, side, k) return RowName(side, k) end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------
-- The button frame art (and the checked border over it), cut in nine so it fits square icons and
-- combo-point-shaped cells alike (corners keep their size, edges stretch). Without atlas info: drawn whole.
local arts = {} -- atlas -> its file and texture coordinates (false: no atlas info)
local function AtlasArt(atlas)
  local art = arts[atlas]
  if art == nil then
    art = false
    if C_Texture and C_Texture.GetAtlasInfo then
      local ok, info = pcall(C_Texture.GetAtlasInfo, atlas)
      if ok and type(info) == "table" and info.file and Plain(info.leftTexCoord) then
        art = { file = info.file, info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord }
      end
    end
    arts[atlas] = art
  end
  return art
end
local function FrameArt() return AtlasArt(FRAME_ATLAS) end

local PIECES = { -- column, row (1 = left/top, 2 = middle, 3 = right/bottom)
  { 1, 1 }, { 2, 1 }, { 3, 1 }, { 1, 2 }, { 3, 2 }, { 1, 3 }, { 2, 3 }, { 3, 3 },
}

local function LayoutFrame(owner, pieces, w, h, atlas)
  atlas = atlas or FRAME_ATLAS
  local art = AtlasArt(atlas)
  if not art then
    pieces[1]:SetAllPoints()
    pieces[1]:SetAtlas(atlas)
    return
  end
  local c = min(w, h) * CORNER
  local l, r, t, b = art[1], art[2], art[3], art[4]
  local du, dv = (r - l) * CORNER, (b - t) * CORNER
  local us = { l, l + du, r - du, r }
  local vs = { t, t + dv, b - dv, b }
  local xs = { 0, c, w - c, w }
  local ys = { 0, c, h - c, h }
  for i, piece in ipairs(PIECES) do
    local tex, col, row = pieces[i], piece[1], piece[2]
    tex:SetTexture(art.file)
    tex:SetTexCoord(us[col], us[col + 1], vs[row], vs[row + 1])
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", owner, "TOPLEFT", xs[col], -ys[row])
    tex:SetSize(xs[col + 1] - xs[col], ys[row + 1] - ys[row])
  end
end

-- Without the game's checked atlas: an action button's checked art as drawn (else the classic art).
local function CheckedArt(tex)
  local button = _G.ActionButton1
  local ok, real = pcall(function() return button and button.GetCheckedTexture and button:GetCheckedTexture() end)
  real = ok and real or nil
  local atlas = real and real.GetAtlas and real:GetAtlas()
  if type(atlas) == "string" and atlas ~= "" then
    tex:SetAtlas(atlas)
  else
    local file = real and real.GetTexture and real:GetTexture()
    tex:SetTexture((type(file) == "number" or (type(file) == "string" and file ~= "")) and file or CHECKED_FILE)
  end
  tex:SetBlendMode("ADD")
end

local function NewSlot(row)
  local slot = CreateFrame("Frame", nil, row)
  slot.icon = slot:CreateTexture(nil, "ARTWORK")
  slot.icon:SetAllPoints()
  -- a mask: the art stays inside the button frame's rounded corners
  if slot.CreateMaskTexture and slot.icon.AddMaskTexture then
    slot.mask = slot:CreateMaskTexture()
    slot.mask:SetAtlas(MASK_ATLAS)
    slot.mask:SetAllPoints(slot.icon)
    slot.icon:AddMaskTexture(slot.mask)
  end
  -- swipe and countdown numbers, like an action button
  slot.cd = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
  slot.cd:SetDrawBling(false)
  slot.cd:SetDrawEdge(false)
  if slot.cd.SetCountdownAbbrevThreshold then slot.cd:SetCountdownAbbrevThreshold(ABBREV) end
  -- button frame and count above the swipe, and above the game's aura button (see below)
  slot.over = CreateFrame("Frame", nil, slot)
  slot.over:SetAllPoints()
  slot.over:SetFrameLevel(slot:GetFrameLevel() + 6)
  slot.frame = {}
  for i = 1, FrameArt() and #PIECES or 1 do slot.frame[i] = slot.over:CreateTexture(nil, "OVERLAY") end
  -- The image the game shows for the spell while on (Shadowmeld's star, Stealth's face), drawn above the game's aura
  -- button (which shows the buff's own icon over the icon while the buff is up, the face or the hood) and under the
  -- button frame and the gold border; hidden otherwise.
  slot.active = slot.over:CreateTexture(nil, "BACKGROUND")
  slot.active:SetAllPoints(slot.icon)
  if slot.over.CreateMaskTexture and slot.active.AddMaskTexture then
    slot.activeMask = slot.over:CreateMaskTexture()
    slot.activeMask:SetAtlas(MASK_ATLAS)
    slot.activeMask:SetAllPoints(slot.active)
    slot.active:AddMaskTexture(slot.activeMask)
  end
  slot.active:Hide()
  -- in that form, stance or stealth (or the spell queued, Auto Shot on): checked, as the game's action and
  -- stance buttons show it, their gold border cut like the frame (not the classic square ClassicUI puts on
  -- its bars: the icon under it looked pale)
  slot.checked = CreateFrame("Frame", nil, slot.over)
  slot.checked:SetAllPoints()
  slot.checked.pieces = {}
  local cut = AtlasArt(CHECKED_ATLAS)
  for i = 1, cut and #PIECES or 1 do
    local piece = slot.checked:CreateTexture(nil, "OVERLAY", nil, 1)
    slot.checked.pieces[i] = piece
    if cut then piece:SetBlendMode("ADD") else piece:SetAllPoints() CheckedArt(piece) end
  end
  slot.checked:Hide()
  slot.count = slot.over:CreateFontString(nil, "OVERLAY")
  ns:EditableSlot(slot) -- (editing on the HUD, below)
  return slot
end

local function GetRow(side, k)
  local row = rows[side][k]
  if not row then
    row = CreateFrame("Frame", nil, ns.iconLayer)
    row.slots = {}
    row.side, row.k = side, k
    rows[side][k] = row
    ns:EditableRow(row) -- (editing on the HUD, below)
  end
  return row
end

-- Shows the middle of the icon in a w x h area, without stretching it.
local function Crop(tex, w, h)
  local span = 1 - 2 * TRIM
  if w >= h then
    local half = span * h / w / 2
    tex:SetTexCoord(TRIM, 1 - TRIM, .5 - half, .5 + half)
  else
    local half = span * w / h / 2
    tex:SetTexCoord(.5 - half, .5 + half, TRIM, 1 - TRIM)
  end
end

-- Stacks and countdown numbers sized for the icon (the countdown at the size chosen in the
-- options, a percentage of that).
local function SetCountFonts(count, cd, w, h)
  local s = min(w, h)
  local timerSize = ns.db and ns.db.icons.timerSize or 100
  local countFont = NumberFontNormal and NumberFontNormal.GetFont and NumberFontNormal:GetFont() or FONT
  count:SetFont(countFont, max(8, floor(s * .4)), "OUTLINE")
  count:ClearAllPoints()
  count:SetPoint("BOTTOMRIGHT", -max(1, s * 5 / 45), max(1, s * 5 / 45))
  local fs = cd.GetCountdownFontString and cd:GetCountdownFontString()
  if fs then
    local path = fs:GetFont()
    fs:SetFont(path or FONT, max(6, floor(max(9, s * .48) * timerSize / 100)), "OUTLINE")
  end
end

-- Spells known to have a cooldown of their own: ready, they show lit rather than grayed out.
local function HasCooldown(slot)
  local learned = ns.sv and ns.sv.cooldownSpells
  if slot.name and learned and learned[slot.name] then return true end
  if type(slot.spell) == "number" and GetSpellBaseCooldown then
    local ok, ms = pcall(GetSpellBaseCooldown, slot.spell)
    if ok and Plain(ms) and ms > GCD * 1000 then return true end
  end
  return false
end

function ns:LayoutIcons()
  local db = self.db
  if not db then return end
  local look = db.icons
  local shape = look.shape
  local cellW, cellH, cellGap = self:ComboCellSize() -- a combo point cell
  local size = shape == "CELL" and cellH or look.size
  local top, bottom, topWidth, bottomWidth, topRoom, bottomRoom = self:IconAnchors()
  local editable = self:IconsEditable()
  local items = {} -- the items on the rows (their spells watched: Items.lua)
  for _, side in ipairs(self.SIDES) do
    -- each row sits on the previous one, from the top bar up or the bottom bar down; empty
    -- rows take no room (in Bear Form without combo points, the rows above sit on the rage
    -- bar: see Core.lua). The Bar width shape takes the width of that bar.
    local anchor = side == "above" and top or bottom
    local barWidth = side == "above" and topWidth or bottomWidth
    local room = (side == "above" and topRoom or bottomRoom) or 0 -- the bar's frame (bar style)
    for k = 1, self.MAX_ROWS do
      local spells = db.rows[side][k]
      local row = GetRow(side, k)
      local n = #spells
      row.spells = spells
      for i = n + 1, #row.slots do row.slots[i]:Hide() end
      if n == 0 and not editable then
        row:Hide()
      else
        -- FILL: the row shares the bar's width; CELL: each icon the size of a combo point
        -- cell, however many there are; SQUARE: square icons. CELL and SQUARE rows are
        -- centred on the bar. (Icons unlocked: the empty rows show too, to drop spells on.)
        local gap = shape == "CELL" and cellGap or self.CP_GAP
        local w = (shape == "SQUARE" and size) or (shape == "CELL" and cellW)
          or (barWidth - max(0, n - 1) * gap) / max(1, n)
        row:ClearAllPoints()
        local rowWidth = (shape == "FILL" or n == 0) and barWidth or (n * w + (n - 1) * gap)
        row:SetSize(rowWidth, size)
        row:EditMode(editable, max(barWidth, rowWidth), size)
        if side == "above" then
          row:SetPoint("BOTTOM", anchor, "TOP", 0, self.ROW_GAP + room)
        else
          row:SetPoint("TOP", anchor, "BOTTOM", 0, -self.ROW_GAP - room)
        end
        anchor, room = row, 0
        for i = 1, n do
          local slot = row.slots[i] or NewSlot(row)
          row.slots[i] = slot
          slot:ClearAllPoints()
          slot:SetSize(w, size)
          slot:SetPoint("TOPLEFT", (i - 1) * (w + gap), 0)
          slot.w, slot.h = w, size
          Crop(slot.icon, w, size)
          Crop(slot.active, w, size)
          LayoutFrame(slot, slot.frame, w, size)
          if AtlasArt(CHECKED_ATLAS) then LayoutFrame(slot.checked, slot.checked.pieces, w, size, CHECKED_ATLAS) end
          local inset = min(w, size) * 3 / 45
          slot.cd:ClearAllPoints()
          slot.cd:SetPoint("TOPLEFT", inset, -inset)
          slot.cd:SetPoint("BOTTOMRIGHT", -inset, inset)
          SetCountFonts(slot.count, slot.cd, w, size)
          local spell = self:EntrySpell(spells[i])
          slot.spell, slot.on, slot.mine = spell, self:EntryOn(spells[i]), self:EntryMine(spells[i])
          slot.side, slot.k, slot.index = side, k, i
          slot:EnableMouse(editable)
          slot.exact = type(spells[i]) == "table" and spells[i].exact and type(spell) == "number" and self:RankIDs(spell) or nil
          slot.item = self:ItemOf(spell)
          if slot.item then
            -- an item: the buff it gives has the name of the spell it casts, on you
            slot.name, slot.itemSpell = self:ItemSpell(slot.item)
            slot.on, slot.byName, slot.hasCooldown = "self", false, false
            slot.spellIcon = self:SpellIcon(spell)
            items[#items + 1] = slot.item
          else
            slot.itemSpell = nil
            slot.name = self:SpellName(spell)
            slot.byName = type(spell) == "string"
            slot.spellIcon = self:SpellIcon(spell)
            if slot.spellIcon == QUESTION_MARK and slot.name then slot.spellIcon = self:SeenIcon(slot.name) end
            slot.hasCooldown = HasCooldown(slot)
          end
          slot.imbue = self:ImbueKey(spell, slot.name)
        end
        row:Show()
      end
    end
    if side == "above" then self:AnchorMoverText(anchor) end
  end
  self:WatchItemSpells(items)
  self:SyncAuraButtons()
  self:MarkIconsDirty() -- states read on the next frame, once
  if self.SyncClickers then self:SyncClickers() end -- the click buttons follow (Clicks.lua)
end

---------------------------------------------------------------------------
-- Live state, read by the addon: auras the game lets addons see (out of combat, and in combat
-- the few spells it marks as never secret), spell cooldowns and charges.
---------------------------------------------------------------------------
local function Bool(v) return not issecretvalue(v) and v == true end

-- Is the target one this icon watches? (any target, or only an enemy / a friend)
local function TargetFits(on)
  if not UnitExists("target") then return false end
  if on == "enemy" then return Bool(UnitCanAttack("player", "target")) end
  if on == "friend" then return not Bool(UnitCanAttack("player", "target")) end
  return true
end

-- A spell typed by name and unknown to this character ("renew"): the unit's auras are read one
-- by one, without minding upper / lower case.
local function ScanAuras(unit, name, filter)
  if not GetAuraDataByIndex then return end
  local wanted = Fold(name)
  for i = 1, 255 do
    local ok, aura = pcall(GetAuraDataByIndex, unit, i, filter)
    if not ok or issecretvalue(aura) or type(aura) ~= "table" then return end
    local auraName = aura.name
    if not issecretvalue(auraName) and type(auraName) == "string" and Fold(auraName) == wanted then return aura end
  end
end

-- By name, where the icon's condition says (only yours if it says so). Also says when the
-- aura is there in another rank than the one watched.
local function FindAura(slot)
  local otherRank
  for _, lookup in ipairs(LOOKUPS[slot.on] or LOOKUPS.auto) do
    local unit = lookup[1]
    if unit ~= "target" or TargetFits(slot.on) then
      local filter = lookup[2] .. (slot.mine and MINE or "")
      local aura = ns:FindAura(unit, slot.name, filter)
      if not aura and slot.byName then aura = ScanAuras(unit, slot.name, filter) end
      if aura then
        if not slot.exact or issecretvalue(aura.spellId) or slot.exact[aura.spellId] then return aura, unit end
        otherRank = true
      end
    end
  end
  return nil, nil, otherRank
end

-- The spell's own cooldown, global cooldown left out: put on the swipe, true while it runs.
local function SpellCooldown(slot)
  if not GetSpellCooldown or not slot.name then return false end
  local ok, info = pcall(GetSpellCooldown, slot.name)
  if not ok or issecretvalue(info) or type(info) ~= "table" then return false end -- unknown spell
  if info.isActive ~= true or info.isOnGCD == true then return false end
  local duration = Plain(info.duration)
  if duration and duration <= GCD then return false end
  if duration and slot.name and ns.sv and not ns.sv.cooldownSpells[slot.name] then
    ns.sv.cooldownSpells[slot.name] = true -- lit when ready from now on
    slot.hasCooldown = true
  end
  if GetSpellCooldownDuration and slot.cd.SetCooldownFromDurationObject then
    local okD, d = pcall(GetSpellCooldownDuration, slot.name, true)
    if okD and d and pcall(slot.cd.SetCooldownFromDurationObject, slot.cd, d, true) then return true end
  end
  local start = Plain(info.startTime)
  if start and duration then
    slot.cd:SetCooldown(start, duration, Plain(info.modRate) or 1)
    return true
  end
  return false
end

-- An item's cooldown (potions, food...) on the swipe, true while it runs.
local function ItemCooldown(slot)
  local start, duration = ns:ItemCooldown(slot.item)
  if not start or duration <= GCD then return false end
  slot.cd:SetCooldown(start, duration)
  return true
end

-- Charges of a spell that has some (possibly secret: only handed to SetText).
local function Charges(slot)
  if not GetSpellCharges or not slot.name then return end
  local ok, info = pcall(GetSpellCharges, slot.name)
  if ok and not issecretvalue(info) and type(info) == "table" then
    local most = Plain(info.maxCharges)
    if most and most > 1 then return info.currentCharges end
  end
end

-- The spell IDs an aura was seen under, by spell name: the game's aura buttons (below) match
-- auras by ID, and some spells exist under several IDs (ranks, Forever's second IDs).
local function LearnAuraID(slot, aura)
  local id = Plain(aura.spellId)
  local learned = ns.sv and ns.sv.auraIDs
  if not id or not learned or slot.exact or not slot.name then return end
  local key = Fold(slot.name)
  if learned[key] and learned[key][id] then return end
  learned[key] = learned[key] or {}
  learned[key][id] = true
  ns:SyncAuraButtons()
end

-- The spell's form, stance or stealth on (Stealth, Prowl, Cat Form, Battle Stance, Devotion Aura...), the spell
-- queued (Heroic Strike) or repeating (Auto Shot, Shoot): checked, as the game's action and stance buttons show it
-- (their gold border). A spell whose button shows another icon while on (Shadowmeld, the aspects: the white star)
-- takes that icon instead, alone, as its button: no form nor aura of theirs to be read on WoW Forever, the game's
-- own buttons tell, read through C_ActionBar (the old GetActionTexture is there only with the game's deprecation
-- fallbacks on).
local IsCurrentSpell = (C_Spell and C_Spell.IsCurrentSpell) or IsCurrentSpell
local IsAutoRepeatSpell = (C_Spell and C_Spell.IsAutoRepeatSpell) or IsAutoRepeatSpell
local function SpellOn(fn, spell)
  if not fn or spell == nil then return false end
  local ok, v = pcall(fn, spell)
  return ok and Bool(v)
end
-- The game's answer taken as its own code takes it: anything but nil and false (its stance bar tests `if isActive`;
-- a 1 counts as a true)
local function Truthy(v) return not issecretvalue(v) and v ~= nil and v ~= false and v ~= 0 end
-- The form of this name (Stealth, Prowl, Cat Form, a stance...) on: on the stance bar, or the game's form index
local function SameName(a, b) return type(a) == "string" and type(b) == "string" and Fold(a) == Fold(b) end
local function FormIndex(name)
  if not name or not GetNumShapeshiftForms or not GetShapeshiftFormInfo then return nil end
  local ok, n = pcall(GetNumShapeshiftForms)
  if not ok or not Plain(n) then return nil end
  local current
  if GetShapeshiftForm then
    local okF, f = pcall(GetShapeshiftForm)
    current = okF and Plain(f) or nil
  end
  for i = 1, n do
    local okI, icon, active, _, spellID = pcall(GetShapeshiftFormInfo, i)
    if okI and (Truthy(active) or current == i) and Plain(spellID) and SameName(ns:SpellName(spellID), name) then
      return i, (not issecretvalue(icon)) and icon or nil
    end
  end
end
local function FormOn(name) return FormIndex(name) ~= nil end
-- The white star: the game's icon for a form or a toggle on (its file ID, read once from its path)
local starID
local function IsStar(icon)
  if icon == nil or issecretvalue(icon) then return false end
  if type(icon) == "string" then return icon:lower():find("wispsplode", 1, true) ~= nil end
  if type(icon) ~= "number" then return false end
  if starID == nil then
    starID = false
    local probe = ns.hud and ns.hud.CreateTexture and ns.hud:CreateTexture(nil, "BACKGROUND")
    if probe then
      probe:SetTexture(ACTIVE_ICON)
      local id = probe.GetTextureFileID and probe:GetTextureFileID()
      if type(id) == "number" and not issecretvalue(id) then starID = id end
      probe:Hide()
    end
  end
  return starID ~= false and icon == starID
end

-- The weapons' icons: Attack, Auto Shot, Shoot and Throw show their weapon's on their button, on or not
local WEAPON_SLOTS = { 16, 17, 18 }
local function WeaponIcon(icon)
  if not GetInventoryItemTexture then return false end
  for _, inv in ipairs(WEAPON_SLOTS) do
    local ok, t = pcall(GetInventoryItemTexture, "player", inv)
    if ok and t ~= nil and not issecretvalue(t) and t == icon then return true end
  end
  return false
end

-- An action button's icon as the game shows it now (read live)
local function ActionTexture(action)
  local fn = (C_ActionBar and C_ActionBar.GetActionTexture) or GetActionTexture
  if not fn then return end
  local ok, icon = pcall(fn, action)
  if ok and icon ~= nil and not issecretvalue(icon) then return icon end
end

-- The spell an action button holds: a spell, or the one a macro shows (C_ActionBar.GetSpell reads both)
local GetActionSpell = C_ActionBar and C_ActionBar.GetSpell
local function SpellOfAction(action)
  if GetActionSpell then
    local ok, id = pcall(GetActionSpell, action)
    if ok and Plain(id) and id > 0 then return id end
  end
  if not GetActionInfo then return nil end
  local ok, kind, id = pcall(GetActionInfo, action)
  if not ok or issecretvalue(kind) then return nil end
  if kind == "spell" and Plain(id) then return id end
  if kind == "macro" and Plain(id) and GetMacroSpell then
    local okM, spell = pcall(GetMacroSpell, id)
    if okM and Plain(spell) then return spell end
  end
end

-- The action bars' slots holding each spell (by name), macros showing it included, read again when the bars
-- change (not kept while the bars read empty: not known yet at login)
local actionsByName
local function ActionsOf(name)
  if not actionsByName then
    local found, any = {}, false
    for action = 1, ACTION_SLOTS do
      local hasAction = true
      if C_ActionBar and C_ActionBar.HasAction then
        local ok, has = pcall(C_ActionBar.HasAction, action)
        hasAction = ok and Truthy(has)
      end
      if hasAction then
        local id = SpellOfAction(action)
        if id then
          any = true
          local spellName = ns:SpellName(id)
          if spellName then
            local key = Fold(spellName)
            found[key] = found[key] or {}
            table.insert(found[key], action)
          end
        elseif GetActionInfo then
          local ok, kind = pcall(GetActionInfo, action)
          if ok and not issecretvalue(kind) and kind ~= nil then any = true end
        end
      end
    end
    if not any then return NONE end
    actionsByName = found
  end
  return (name and actionsByName[Fold(name)]) or NONE
end
function ns:ActionBarsChanged() actionsByName = nil end

-- The slots holding the icon's spell: by its name (every rank, macros too), else as the game finds it
local function SpellActions(slot)
  local list = ActionsOf(slot.name)
  if #list == 0 and type(slot.spell) == "number" and C_ActionBar and C_ActionBar.FindSpellActionButtons then
    local ok, found = pcall(C_ActionBar.FindSpellActionButtons, slot.spell)
    if ok and not issecretvalue(found) and type(found) == "table" then return found end
  end
  return list
end

-- The game has the spell on (Shadowmeld, an aspect) or queued (Heroic Strike), or casts it: as the spell, or as a
-- button holding it is checked (the game's own buttons read C_ActionBar.IsCurrentAction)
local IsCurrentAction = C_ActionBar and C_ActionBar.IsCurrentAction
local function Current(slot)
  if SpellOn(IsCurrentSpell, slot.name) or (type(slot.spell) == "number" and SpellOn(IsCurrentSpell, slot.spell)) then return true end
  if IsCurrentAction then
    for _, action in ipairs(SpellActions(slot)) do
      if SpellOn(IsCurrentAction, action) then return true end
    end
  end
  return false
end

-- Checked as the game checks its own buttons: its form on, the spell current (a button holding it checked: Stealth),
-- or repeating. Shadowmeld's and the aspects' buttons are not checked while on: they only change image.
local function GameChecked(slot)
  return FormOn(slot.name) or SpellOn(IsAutoRepeatSpell, slot.name) or Current(slot)
end

-- Each spell's icon at rest, by spell ID: the game gives a spell another image while it is on (Shadowmeld's star,
-- Stealth's face), to its icon and to the buttons holding it, its "original" icon included; so the image a spell
-- had when first seen (at login, off) is what tells on from off.
local GetSpellTextureNow = C_Spell and C_Spell.GetSpellTexture
local restIcons = {}
local function RestIcon(spellID)
  if not Plain(spellID) then return nil end
  local icon = restIcons[spellID]
  if icon == nil and GetSpellTextureNow then
    local ok, a, b = pcall(GetSpellTextureNow, spellID)
    local v = ok and (Plain(b) or Plain(a)) or nil
    if v and IsStar(v) then v = nil end
    if v then restIcons[spellID] = v end
    icon = v
  end
  return icon
end

-- Another image than its own at rest (rest: the icon's own, and that of the spell the button holds): the star by its
-- file, or any other, but never a weapon's (Attack, Auto Shot, Shoot show their weapon on their button).
local function OtherThanRest(icon, restA, restB)
  if icon == nil or issecretvalue(icon) then return nil end
  if IsStar(icon) then return icon end
  if type(icon) ~= "number" or WeaponIcon(icon) then return nil end
  if type(restA) ~= "number" and type(restB) ~= "number" then return nil end
  if icon ~= restA and icon ~= restB then return icon end
end

-- The image the game shows for it while on when it is not its own at rest (the star of Shadowmeld and the aspects,
-- Stealth's face): on a button holding it (spells and macros: what you see on your bars), or as the spell's icon.
-- nil otherwise.
local function ShownOn(slot)
  if slot.item or not slot.name or ns.preview then return end
  local own = Plain(slot.spellIcon)
  for _, action in ipairs(SpellActions(slot)) do
    local other = OtherThanRest(ActionTexture(action), own, RestIcon(SpellOfAction(action)))
    if other then return other end
  end
  if GetSpellTextureNow and slot.spell ~= nil then
    local ok, icon = pcall(GetSpellTextureNow, slot.spell)
    local other = ok and OtherThanRest(icon, own, RestIcon(slot.spell))
    if other then return other end
  end
end

-- A spell the game checks while on (Stealth) and does not check now is off: what it shows now is its rest image
-- (its first sight may have been while on: a reload while stealthed)
local function SpellImage(spellID)
  if not (GetSpellTextureNow and Plain(spellID)) then return nil end
  local ok, a = pcall(GetSpellTextureNow, spellID)
  a = ok and Plain(a) or nil
  if a and not IsStar(a) then return a end
end
local function LearnRest(slot)
  if not slot.spellIcon or slot.item then return end
  -- (from the spell's own icon only: on WoW Forever only its buttons change image while on)
  local icon = SpellImage(slot.spell)
  if not icon then return end
  restIcons[slot.spell] = icon
  if slot.spellIcon ~= icon and type(slot.spellIcon) == "number" then slot.spellIcon = icon end
  for _, action in ipairs(SpellActions(slot)) do
    local id = SpellOfAction(action)
    local own = id and SpellImage(id)
    if own then restIcons[id] = own end
  end
end

-- What the form, action bar and spell events change on an icon: on (a form, a toggle, queued or repeating), the
-- other image its button shows while on, and whether the game checks it
local function Look(slot)
  if slot.item or not slot.name or ns.preview then return false, nil, false end
  local checked = GameChecked(slot) and true or false
  if checked then
    slot.everChecked = true
  elseif slot.everChecked then
    LearnRest(slot)
  end
  local shown = ShownOn(slot)
  local on = shown ~= nil or checked
  return on, shown, checked
end
local function Checked(slot) return (Look(slot)) end
ns.IconChecked = function(_, slot) return Checked(slot) end

-- On as a form is: the game's form (stance bar), the other image its button shows, or an aura you cast on yourself
-- that lasts until it is cancelled (no duration: Shadowmeld, Stealth, the aspects, Trueshot Aura, the paladins'
-- auras...). Not another player's aura on you, not a timed buff.
local function FormLike(slot, aura, unit)
  if slot.item or not slot.name or ns.preview then return false end
  if FormOn(slot.name) or ShownOn(slot) ~= nil then return true end
  if not aura or unit ~= "player" then return false end
  local source = aura.sourceUnit
  if issecretvalue(source) or source ~= "player" then return false end
  local duration, ends = Plain(aura.duration), Plain(aura.expirationTime)
  return duration == 0 and (ends == nil or ends == 0)
end
ns.IconFormLike = function(_, slot, aura, unit) return FormLike(slot, aura, unit) end

-- The image the game shows for it while on, as on your bars: the other image a button holding it shows (Stealth's
-- face, Shadowmeld's star), else what that button shows now (its first sight was while on: a reload while
-- stealthed), else its form's on the stance bar when not its own, else its own; the star when the game shows
-- nothing of it.
local function ActiveIcon(slot)
  local shown = ShownOn(slot)
  if shown ~= nil then return shown end
  for _, action in ipairs(SpellActions(slot)) do
    local icon = ActionTexture(action)
    if icon ~= nil and not WeaponIcon(icon) then return icon end
  end
  local form, formIcon = FormIndex(slot.name)
  if form then
    if Plain(formIcon) and formIcon ~= slot.spellIcon and not WeaponIcon(formIcon) then return formIcon end
    return slot.spellIcon
  end
  return ACTIVE_ICON
end
ns.IconActiveTexture = function(_, slot) return (ActiveIcon(slot)) end

-- An image on while on is dull, as vanilla's buttons show it: grey 0.4, the game's own tint for a button that cannot
-- be cast (ActionButton.lua UpdateUsable: Shadowmeld and Stealth while on); the same for the aspects and the forms
-- (the user: "the active look is darker"); blue 0.5 0.5 1, the game's, when the button holding it lacks mana.
local IsUsableAction = C_ActionBar and C_ActionBar.IsUsableAction
local function GameTint(slot, image)
  if IsUsableAction then
    for _, action in ipairs(SpellActions(slot)) do
      if ActionTexture(action) == image then
        local ok, usable, lacking = pcall(IsUsableAction, action)
        if ok and not issecretvalue(usable) and not issecretvalue(lacking) and not usable and lacking then
          return .5, .5, 1
        end
      end
    end
  end
  return .4, .4, .4
end

local function ShowChecked(slot, on)
  if slot.isChecked == on then return end
  slot.isChecked = on
  if slot.checked then slot.checked:SetShown(on) end
end

local Enchanted -- below: a weapon imbue's enchantment on the swipe

local function SetSlot(slot, look, aura, unit, enchant)
  slot.cd:Clear()
  slot.cd:SetReverse(false)
  if slot.cd.SetHideCountdownNumbers then slot.cd:SetHideCountdownNumbers(not look.timers) end
  slot.count:SetText("")
  local running
  if ns.preview then
    -- a sample: lit, with a cooldown under way
    ShowChecked(slot, false)
    slot.spellChecked, slot.spellShown = false, nil
    slot.active:Hide()
    slot.icon:SetTexture(slot.spellIcon)
    slot.icon:SetDesaturated(false)
    slot:SetAlpha(1)
    slot:Show()
    slot.cd:SetCooldown(GetTime() - 15, 45)
    return
  end
  if enchant then
    slot.icon:SetTexture(slot.spellIcon)
    Enchanted(slot, look, enchant)
  elseif aura then
    LearnAuraID(slot, aura)
    local icon = aura.icon
    if issecretvalue(icon) or not icon then
      icon = slot.spellIcon
    elseif slot.spellIcon == QUESTION_MARK then
      slot.spellIcon = icon -- a spell tracked by name: its icon is known from now on
      ns:RememberIcon(slot.name, icon)
    end
    slot.icon:SetTexture(icon)
    local ends, duration = Plain(aura.expirationTime), Plain(aura.duration)
    if ends and duration then
      if ends > 0 and duration > 0 then
        slot.cd:SetReverse(look.reverse)
        slot.cd:SetCooldown(ends - duration, duration)
      end
    elseif GetAuraDuration and slot.cd.SetCooldownFromDurationObject then
      -- times hidden: the game's duration object (possibly secret, only handed to the swipe)
      local ok, d = pcall(GetAuraDuration, unit, aura.auraInstanceID)
      if ok and d then
        slot.cd:SetReverse(look.reverse)
        pcall(slot.cd.SetCooldownFromDurationObject, slot.cd, d, true)
      end
    end
    local stacks = aura.applications
    if issecretvalue(stacks) then
      if GetDisplayCount then
        local ok, text = pcall(GetDisplayCount, unit, aura.auraInstanceID, 2)
        if ok then slot.count:SetText(text) end -- possibly secret: only handed to SetText
      end
    elseif type(stacks) == "number" and stacks > 1 then
      slot.count:SetText(stacks)
    end
  else
    slot.icon:SetTexture(slot.spellIcon)
    if slot.item then running = ItemCooldown(slot) else running = SpellCooldown(slot) end
  end
  local carried
  if slot.item then
    -- an item: how many you carry (lit while you have some)
    local n = ns:ItemCount(slot.item)
    carried = n ~= nil and n > 0
    slot.count:SetText(n and n > 0 and n or "")
  elseif not enchant and not (aura and Plain(aura.applications) and aura.applications > 1) then
    local charges = Charges(slot)
    if charges ~= nil then slot.count:SetText(charges) end
  end
  local formOn = FormLike(slot, aura, unit)
  local onIcon
  if formOn then
    onIcon = ActiveIcon(slot)
    slot.icon:SetTexture(onIcon)
  end
  local gameChecked
  slot.spellChecked, slot.spellShown, gameChecked = Look(slot) -- (what the form, action bar and spell events read again: ns:CheckIcons)
  slot.spellGameChecked = gameChecked
  -- As the game's own button: its image while on (Shadowmeld's star, Stealth's face), and the gold border only when
  -- the game checks it (Stealth, a form, a spell queued or repeating; not Shadowmeld nor the aspects). An aura of
  -- yours with no duration and no other image (Trueshot Aura, a paladin aura) keeps the border, as before.
  local swapped = formOn and onIcon ~= slot.spellIcon
  local on = formOn or slot.spellChecked
  ShowChecked(slot, on and (gameChecked or not swapped))
  -- (the active image above the game's aura button: under it, it was never seen); a form's own image too, dull
  if swapped or (formOn and FormIndex(slot.name) ~= nil) then
    slot.active:SetTexture(onIcon)
    slot.active:SetVertexColor(GameTint(slot, onIcon)) -- (as dull as the game's own button: vanilla's look)
    slot.active:Show()
  else
    slot.active:Hide()
  end
  local lit = enchant or aura or carried or (running and not slot.item) or slot.hasCooldown or on
  slot.icon:SetDesaturated(not lit)
  slot:SetAlpha(lit and 1 or MISSING_ALPHA)
  slot:SetShown(lit or look.missing)
end

function ns:UpdateIcons()
  dirty = false
  if not self.db or not self.hud:IsShown() then
    dirty = true -- catch up when shown
    return
  end
  local look = self.db.icons
  local enchants -- the weapons' enchantments, read once
  for _, side in ipairs(self.SIDES) do
    for _, row in pairs(rows[side]) do
      for i = 1, #(row.spells or NONE) do
        local slot = row.slots[i]
        local aura, unit, otherRank, enchant
        if slot.imbue then
          enchants = enchants or self:WeaponEnchants()
          enchant = self:MatchEnchant(slot.imbue, slot.spellIcon, enchants)
        end
        if slot.name and not enchant then aura, unit, otherRank = FindAura(slot) end
        SetSlot(slot, look, aura, unit, enchant)
      end
    end
  end
end

-- A form, stance or stealth changed, a spell queued: the icons drawn again only if one of them turns on or off,
-- or its button's star shows or goes (these events come often; no aura read for nothing).
function ns:CheckIcons()
  if not self.db then return end
  if not self.hud:IsShown() then
    dirty = true -- (read when shown)
    return
  end
  for _, side in ipairs(self.SIDES) do
    for _, row in pairs(rows[side]) do
      for i = 1, #(row.spells or NONE) do
        local slot = row.slots[i]
        if slot then
          local on, shown, checked = Look(slot) -- (on or off, the image its button shows, checked by the game)
          if on ~= (slot.spellChecked and true or false) or shown ~= slot.spellShown
            or checked ~= (slot.spellGameChecked and true or false) then
            dirty = true
            return
          end
        end
      end
    end
  end
end

-- Aura and cooldown events can come in bursts: the icons are refreshed once, on the next frame.
function ns:MarkIconsDirty()
  dirty = true
end

function ns:UpdateIconsIfDirty()
  if dirty then self:UpdateIcons() end
end

---------------------------------------------------------------------------
-- Weapon imbues: Rockbiter, Flametongue, Frostbrand and Windfury Weapon, and the items that
-- enchant a weapon (poisons, oils, stones: see the consumables). Their icon is lit while one of
-- your weapons has the enchantment, with its time left on the swipe and its charges. The game
-- tells enchantments apart by IDs of their own: known from the lists below (Classic Era's),
-- learned when you cast the spell (the enchantment that shows up on a weapon right after), or
-- found by their icon.
---------------------------------------------------------------------------
local IMBUE_ENCHANTS = { -- by the spell's rank 1 (Classic Era's enchantment IDs, every rank)
  [8017] = { 1, 6, 29, 503, 504, 683, 1663, 1664, 241 }, -- Rockbiter Weapon
  [8024] = { 3, 4, 5, 523, 1665, 1666 },                  -- Flametongue Weapon
  [8033] = { 2, 12, 524, 1667, 1668 },                    -- Frostbrand Weapon
  [8232] = { 283, 284, 525, 1669 },                       -- Windfury Weapon
}
ns.WINDFURY_WEAPON = 8232
local WEAPONS = { { 0, 16 }, { 1, 17 } } -- Enum.WeaponSlot and inventory slot: main hand, off hand
local LEARN_TIME = 3 -- seconds after a cast to see its enchantment show up
local knownEnchants   -- enchantment ID -> imbue key (from IMBUE_ENCHANTS, names read once)
local pendingImbue    -- a cast waiting for its enchantment: { key =, at =, before = }
local lastEnchants = {} -- inventory slot -> { id =, left =, at = } as last read

-- An imbue's key: its spell name, folded (every rank is the same imbue).
local function ImbueKeyOf(name) return name and "imbue:" .. Fold(name) end

function ns:ImbueKey(spell, name)
  for _, rec in ipairs(self:CatalogRecords(spell, name)) do
    if rec.kind == "IMBUE" then return ImbueKeyOf(rec.name) end
  end
  if self.ItemImbueKey then return self:ItemImbueKey(spell) end -- (consumables)
end

local function KnownEnchants()
  if knownEnchants then return knownEnchants end
  knownEnchants = {}
  for spell, ids in pairs(IMBUE_ENCHANTS) do
    local key = ImbueKeyOf(ns:SpellName(spell))
    if key then for _, id in ipairs(ids) do knownEnchants[id] = key end end
  end
  return knownEnchants
end

-- The enchantments on your weapons: { slot =, id =, left = seconds or nil, charges =, icon = }.
-- (Forever's call lists a weapon's imbue and its temporary enchantment, a stone or an oil.)
function ns:WeaponEnchants()
  local list = {}
  local function Add(slot, id, ms, charges, icon)
    id = Plain(id)
    if not id or id <= 0 then return end
    ms = Plain(ms)
    list[#list + 1] = { slot = slot, id = id, left = ms and ms > 0 and ms / 1000 or nil,
      charges = Plain(charges), icon = Plain(icon) }
  end
  local byItem = C_Item and C_Item.GetWeaponEnchantInfo
  local byInventory = C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo
  for _, w in ipairs(WEAPONS) do
    local ok, enchants = false, nil
    if byItem then ok, enchants = pcall(byItem, w[1]) end
    if ok and type(enchants) == "table" and not issecretvalue(enchants) then
      for _, e in pairs(enchants) do
        if type(e) == "table" and Bool(e.hasEnchant) then Add(w[2], e.enchantID, e.timeLeft, e.charges, e.enchantIconID) end
      end
    elseif byInventory then
      local okI, e = pcall(byInventory, w[2])
      if okI and type(e) == "table" and not issecretvalue(e) then Add(w[2], e.enchantID, e.remainingTimeMs, e.chargesRemaining) end
    elseif GetWeaponEnchantInfo then
      local values = { pcall(GetWeaponEnchantInfo) }
      local at = w[2] == 16 and 2 or 6
      if values[1] and Bool(values[at]) then Add(w[2], values[at + 3], values[at + 1], values[at + 2]) end
    end
  end
  self:LearnEnchant(list)
  return list
end

-- The imbue an enchantment belongs to, if known.
local function EnchantKey(e)
  local learned = ns.sv and ns.sv.enchantKeys
  return learned and learned[e.id] or KnownEnchants()[e.id]
end

-- An imbue's enchantment among them (on the inventory slot given, or any), if one of your
-- weapons has it.
function ns:MatchEnchant(key, icon, enchants, slot)
  for _, e in ipairs(enchants) do
    if not slot or e.slot == slot then
      local owner = EnchantKey(e)
      if owner == key or (not owner and e.icon and e.icon == icon) then return e end
    end
  end
end

-- A cast or an item used: if it is an imbue, the enchantment that shows up next is its own.
function ns:ImbueStarted(key)
  if not key then return end
  local before = {}
  for slot, last in pairs(lastEnchants) do before[slot] = last end
  pendingImbue = { key = key, at = GetTime(), before = before }
  self:MarkIconsDirty()
  C_Timer.After(.5, function() self:CheckPendingImbue() end)
  C_Timer.After(LEARN_TIME, function() self:CheckPendingImbue() end)
end

-- A weapon's enchantment changed, or a while after the cast: read the weapons if a cast waits
-- for its enchantment (the icons may not read them: an item not known yet to enchant weapons).
function ns:CheckPendingImbue()
  if pendingImbue then self:WeaponEnchants() end
  self:MarkIconsDirty()
end

function ns:LearnEnchant(list)
  local now = GetTime()
  local times = self.sv and self.sv.enchantTimes
  for _, e in ipairs(list) do
    -- the longest time left seen: the full duration, for the swipe
    if times and e.left and (times[e.id] or 0) < e.left then times[e.id] = math.ceil(e.left) end
    -- (an enchantment already known as another imbue's is not this cast's)
    local pend, before = pendingImbue, pendingImbue and pendingImbue.before[e.slot]
    local owner = pend and EnchantKey(e)
    if pend and self.sv and now - pend.at <= LEARN_TIME and (not owner or owner == pend.key) then
      local renewed = before and before.id == e.id and e.left and before.left
        and e.left > before.left - (now - before.at) + 1
      if not before or before.id ~= e.id or renewed then
        self.sv.enchantKeys[e.id] = pend.key
        self:ItemEnchantLearned(pend.key)
        pendingImbue = nil
      end
    end
  end
  if pendingImbue and now - pendingImbue.at > LEARN_TIME then pendingImbue = nil end
  wipe(lastEnchants)
  for _, e in ipairs(list) do lastEnchants[e.slot] = { id = e.id, left = e.left, at = now } end
end

-- Windfury Weapon's internal cooldown: after an extra attack, no other for this long (1.5 s in
-- WoW Forever, as its players measured it). Shown on its icon by a short swipe.
local WINDFURY_ICD = 1.5
local windfuryAt -- when it last gave an extra attack

function ns:WindfuryProc()
  local now = GetTime()
  if windfuryAt and now - windfuryAt < WINDFURY_ICD then return end
  windfuryAt = now
  self:MarkIconsDirty()
  C_Timer.After(WINDFURY_ICD, function() self:MarkIconsDirty() end)
end

local WINDFURY_KEY
local function IsWindfury(key)
  WINDFURY_KEY = WINDFURY_KEY or ImbueKeyOf(ns:SpellName(ns.WINDFURY_WEAPON)) or false
  return WINDFURY_KEY and key == WINDFURY_KEY
end
ns.IsWindfuryKey = function(_, key) return IsWindfury(key) end

-- A spell you cast, or one your weapon cast for you: an imbue cast (its enchantment to learn),
-- or Windfury Weapon's extra attack (its proc, under another ID than the ranks you cast).
function ns:SpellDone(spell)
  local name = self:SpellName(spell)
  if not name then return end
  for _, rec in ipairs(self:CatalogRecords(spell, name)) do
    if rec.kind == "IMBUE" then
      local cast = false
      for _, r in ipairs(rec.ranks) do if r[2] == spell or r[3] == spell then cast = true end end
      local key = ImbueKeyOf(rec.name)
      if cast then self:ImbueStarted(key) elseif IsWindfury(key) then self:WindfuryProc() end
      return
    end
  end
  if self.ItemSpellDone then self:ItemSpellDone(spell, name) end -- (consumables)
end

-- Forever's swing events: a second swing of the same hand much sooner than the weapon's speed
-- is an extra attack; with Windfury Weapon on that hand, its proc.
local EXTRA_ATTACK = .5 -- seconds at most
local lastSwing, lastSpeed = {}, {}
function ns:Swing(duration, kind)
  if issecretvalue(kind) or (kind ~= 0 and kind ~= 1) then return end
  local now, last, speed = GetTime(), lastSwing[kind], lastSpeed[kind]
  lastSwing[kind], lastSpeed[kind] = now, Plain(duration)
  if not last or now - last >= min(EXTRA_ATTACK, (speed or 2) * .4) then return end
  local key = ImbueKeyOf(self:SpellName(self.WINDFURY_WEAPON))
  if key and self:MatchEnchant(key, self:SpellIcon(self.WINDFURY_WEAPON), self:WeaponEnchants(), kind == 0 and 16 or 17) then
    self:WindfuryProc()
  end
end

-- An imbue's enchantment on the icon: its time left (or Windfury's cooldown, while it runs)
-- and its charges.
function Enchanted(slot, look, e)
  local now = GetTime()
  if IsWindfury(slot.imbue) and windfuryAt and now - windfuryAt < WINDFURY_ICD then
    slot.cd:SetCooldown(windfuryAt, WINDFURY_ICD)
  elseif e.left then
    local full = ns.sv and ns.sv.enchantTimes and ns.sv.enchantTimes[e.id] or e.left
    full = max(full, e.left)
    slot.cd:SetReverse(look.reverse)
    slot.cd:SetCooldown(now + e.left - full, full)
  end
  if e.charges and e.charges > 0 then slot.count:SetText(e.charges) end
end

---------------------------------------------------------------------------
-- In combat the game hides most auras from addons. It still shows them itself, in its "aura
-- containers": each icon gets one of the game's aura buttons, given the spell IDs to show, on
-- you or on your target. The game fills it, in and out of combat, with the aura's icon, time
-- left and stacks; it sits over the icon (grayed out when the aura is missing) while the aura
-- is up. The game matches spell IDs for buffs on you and on friendly units, and for debuffs on
-- enemies.
---------------------------------------------------------------------------
local CONTAINER_TEMPLATE = "CustomAuraContainerTemplate"
-- what an icon's aura buttons watch, for each condition: unit, aura filter
local SECURE = {
  auto   = { { "player", "HELPFUL" }, { "target", "HARMFUL" } },
  self   = { { "player", "HELPFUL" } },
  target = { { "target", "HELPFUL" }, { "target", "HARMFUL" } },
  enemy  = { { "target", "HARMFUL" } },
  friend = { { "target", "HELPFUL" } },
}

-- While auras are secret (combat, and some instances), the game's aura buttons cannot be set
-- up by addons: changes wait until it is over.
local function AurasSecret()
  if C_Secrets and C_Secrets.ShouldAurasBeSecret then
    local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
    if ok and secret == true then return true end
  end
  return InCombatLockdown() == true
end

local containers = {} -- unit -> the game's aura container (false: none in this client)
ns.auraContainers = containers

local function Container(unit)
  if containers[unit] == nil then
    containers[unit] = false
    local ok, c = pcall(CreateFrame, "AuraContainer", nil, ns.iconLayer, CONTAINER_TEMPLATE)
    if ok and c and c.AddAuraSlot then
      c:SetPoint("TOPLEFT", ns.iconLayer, "TOPLEFT")
      c:SetSize(1, 1)
      c:SetFrameLevel(ns.iconLayer:GetFrameLevel() + 4) -- over the icons, under their button frame
      if c.SetEditModePreviewEnabled then c:SetEditModePreviewEnabled(false) end
      c:SetUnit(unit)
      containers[unit] = c
    end
  end
  return containers[unit] or nil
end

local slotCount = 0
local StyleAuraButton -- below

-- One of the game's aura buttons over an icon, dressed like it: masked art, swipe and
-- countdown, stacks bottom right (all its own children, which the game updates).
local function AuraButton(slot, unit, filter)
  local key = unit .. "|" .. filter
  slot.secure = slot.secure or {}
  if slot.secure[key] ~= nil then return slot.secure[key] or nil end
  local container = Container(unit)
  if not container then
    slot.secure[key] = false
    return
  end
  slotCount = slotCount + 1
  local rec = { container = container, key = "ClaraComboPoints" .. slotCount, enabled = true }
  local ok = pcall(container.AddAuraSlot, container, rec.key, filter, {
    candidateFilters = { includeSpellIDs = {} },
    initializeFrame = function(button)
      button:SetAllPoints(slot)
      if button.EnableMouse then button:EnableMouse(false) end
      local icon = button:CreateTexture(nil, "ARTWORK")
      icon:SetAllPoints()
      if button.CreateMaskTexture and icon.AddMaskTexture then
        local mask = button:CreateMaskTexture()
        mask:SetAtlas(MASK_ATLAS)
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
      end
      local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
      cd:SetDrawBling(false)
      cd:SetDrawEdge(false)
      if cd.SetCountdownAbbrevThreshold then cd:SetCountdownAbbrevThreshold(ABBREV) end
      -- its own button frame and stacks, over the icon's (which is faded while the addon
      -- cannot read the aura)
      local over = CreateFrame("Frame", nil, button)
      over:SetAllPoints()
      over:SetFrameLevel(slot.over:GetFrameLevel() + 1)
      local frame = {}
      for i = 1, FrameArt() and #PIECES or 1 do frame[i] = over:CreateTexture(nil, "OVERLAY") end
      local count = over:CreateFontString(nil, "OVERLAY")
      count:SetFont(FONT, 10, "OUTLINE")
      rec.button = button
      button:SetIcon(icon)
      button:SetDurationCooldown(cd)
      button:SetApplicationCount(count)
      rec.icon, rec.cd, rec.count, rec.over, rec.frame = icon, cd, count, over, frame
      -- dressed now: the game restricts its buttons only after this
      StyleAuraButton(rec, slot.w, slot.h, ns.db.icons)
    end,
  })
  slot.secure[key] = ok and rec.icon and rec or false
  return slot.secure[key] or nil
end

function StyleAuraButton(rec, w, h, look)
  if rec.w == w and rec.h == h and rec.reverse == look.reverse and rec.timers == look.timers
    and rec.timerSize == look.timerSize then return end
  rec.w, rec.h, rec.reverse, rec.timers, rec.timerSize = w, h, look.reverse, look.timers, look.timerSize
  Crop(rec.icon, w, h)
  LayoutFrame(rec.over, rec.frame, w, h)
  local inset = min(w, h) * 3 / 45
  rec.cd:ClearAllPoints()
  rec.cd:SetPoint("TOPLEFT", inset, -inset)
  rec.cd:SetPoint("BOTTOMRIGHT", -inset, inset)
  rec.cd:SetReverse(look.reverse)
  if rec.cd.SetHideCountdownNumbers then rec.cd:SetHideCountdownNumbers(not look.timers) end
  SetCountFonts(rec.count, rec.cd, w, h)
end

-- The spell IDs an icon's aura buttons show: every rank this client knows (with the second IDs
-- Forever gives some spells) and the IDs its aura was seen under; or one rank only.
local function SecureIDs(slot)
  local ids, any = {}, false
  local function Add(id) if id then ids[id] = true; any = true end end
  if slot.exact then
    for id in pairs(slot.exact) do Add(id) end
    return any and ids or nil
  end
  if type(slot.spell) == "number" then Add(slot.spell) end
  if slot.itemSpell then Add(slot.itemSpell) end
  for _, rec in ipairs(slot.item and {} or ns:CatalogRecords(slot.spell, slot.name)) do
    for _, r in ipairs(rec.ranks) do Add(r[2]); Add(r[3]) end
  end
  local learned = slot.name and ns.sv and ns.sv.auraIDs and ns.sv.auraIDs[Fold(slot.name)]
  for id in pairs(learned or {}) do Add(id) end
  return any and ids or nil
end

local function IDKey(ids)
  local list = {}
  for id in pairs(ids) do list[#list + 1] = id end
  table.sort(list)
  return table.concat(list, ",")
end

local secureDirty -- aura buttons to restyle once auras are no longer secret

-- Gives every icon its aura buttons (by condition), with the spell IDs to show; turns off the
-- ones not needed. Run after each layout, when an aura is seen under a new ID, and when the
-- icon look changes. The containers take these changes at any time, in combat too; the
-- buttons themselves are closed to addons while auras are secret, so their look waits.
function ns:SyncAuraButtons()
  if not self.db then return end
  local secret = AurasSecret()
  secureDirty = secret
  local look = self.db.icons
  for _, side in ipairs(self.SIDES) do
    for _, row in pairs(rows[side]) do
      local n = row:IsShown() and #(row.spells or NONE) or 0
      for i, slot in ipairs(row.slots) do
        local ids = i <= n and SecureIDs(slot)
        local wanted = {}
        if ids then
          for _, watch in ipairs(SECURE[slot.on] or SECURE.auto) do
            local rec = AuraButton(slot, watch[1], watch[2] .. (slot.mine and MINE or ""))
            if rec then wanted[rec] = true end
          end
        end
        for _, rec in pairs(slot.secure or {}) do
          if rec then
            local on = wanted[rec] == true
            pcall(function()
              if on then
                local idKey = IDKey(ids)
                if rec.idKey ~= idKey then
                  rec.container:SetAuraSlotCandidateFilters(rec.key, { includeSpellIDs = ids })
                  rec.idKey = idKey
                end
                if not secret then StyleAuraButton(rec, slot.w, slot.h, look) end
              end
              if rec.enabled ~= on then
                rec.container:SetAuraSlotEnabled(rec.key, on)
                rec.enabled = on
              end
            end)
          end
        end
      end
    end
  end
end

-- The game's target container shows the new target's auras.
function ns:TargetChanged()
  local c = containers.target
  if c then pcall(c.UpdateAllAuras, c) end
  self:MarkIconsDirty()
end

-- Combat over: set up what waited.
function ns:AurasReadable()
  if secureDirty then self:SyncAuraButtons() end
  self:MarkIconsDirty()
end

-- /cl debug: what the icons watch, for a report.
function ns:DebugIcons()
  local out = {}
  local function Add(text) out[#out + 1] = text end
  Add(("auras secret: %s, aura containers: player %s, target %s"):format(tostring(AurasSecret()),
    tostring(containers.player and true or containers.player), tostring(containers.target and true or containers.target)))
  for _, side in ipairs(self.SIDES) do
    for k, row in pairs(rows[side]) do
      for i = 1, #(row.spells or NONE) do
        local slot = row.slots[i]
        local ids = SecureIDs(slot)
        local buttons = {}
        for key, rec in pairs(slot.secure or {}) do buttons[#buttons + 1] = key .. (rec and (rec.enabled and "+" or "-") or "x") end
        table.sort(buttons)
        Add(("%s %d: %s (%s) on %s, IDs %s, buttons %s"):format(RowName(side, k), i, tostring(slot.name), tostring(slot.spell),
          tostring(slot.on) .. (slot.mine and " (mine)" or ""), ids and IDKey(ids) or "none", #buttons > 0 and table.concat(buttons, " ") or "none"))
      end
    end
  end
  return out
end

---------------------------------------------------------------------------
-- Editing (options)
---------------------------------------------------------------------------
-- A spell's ID from its name: your spellbook first, then the class spell lists (spells of
-- other classes, by their name in any language), then the auras on you and your target,
-- without minding upper / lower case or accents. Only whole names: a part of one would take
-- the place of an aura of that name (an NPC's "Slow" is not Slow Fall).
function ns:SpellByName(text)
  if GetSpellInfo then
    local ok, info = pcall(GetSpellInfo, text)
    if ok and type(info) == "table" and Plain(info.spellID) then return info.spellID end
  end
  local rec = self:CatalogRecord(text) or self:CatalogByAnyName(text) -- the game's name, else any language
  if rec then return rec.ranks[#rec.ranks][2] end -- its highest rank
  for _, unit in ipairs({ "player", "target" }) do
    for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
      local aura = UnitExists(unit) and ScanAuras(unit, text, filter)
      if aura and Plain(aura.spellId) and self:SpellName(aura.spellId) then return aura.spellId end
    end
  end
end

-- "7386", a spell link, or a name. A known name is stored as its ID (so it follows the
-- client language); an unknown one is tracked by the name as typed.
function ns:ParseSpell(text)
  text = tostring(text or ""):match("^%s*(.-)%s*$")
  if text == "" then return end
  local item = text:match("item:(%d+)")
  if item then
    local entry = self:ItemEntry(item)
    if entry then return entry end
    return nil, L.UNKNOWN_ID:format(text)
  end
  local id = tonumber(text) or tonumber(text:match("spell:(%d+)"))
  if id then
    if id > 0 and id == floor(id) and self:SpellName(id) then return id end
    return nil, L.UNKNOWN_ID:format(text)
  end
  text = text:match("^%[(.+)%]$") or text
  local found = self:SpellByName(text)
  if found then return found end
  return text, nil, true
end

-- Same spell watched the same way (the same spell may be watched on you and on the target,
-- one rank apart from all ranks, and yours apart from anyone's).
local function Exact(entry) return type(entry) == "table" and entry.exact or nil end
local function Same(a, b)
  if ns:EntryOn(a) ~= ns:EntryOn(b) or ns:EntryMine(a) ~= ns:EntryMine(b) then return false end
  local sa, sb = ns:EntrySpell(a), ns:EntrySpell(b)
  if sa == sb then return Exact(a) == Exact(b) end
  if Exact(a) or Exact(b) then return false end
  local na, nb = ns:SpellName(sa), ns:SpellName(sb)
  return na ~= nil and nb ~= nil and Fold(na) == Fold(nb)
end

local function Duplicate(spells, entry, except)
  for i, other in ipairs(spells) do
    if i ~= except and Same(other, entry) then return true end
  end
end
function ns:IsDuplicate(spells, entry, except) return Duplicate(spells, entry, except) == true end

-- entry: text typed (ID, link or name), a spell ID, or { spell =, on =, exact = }.
-- at: position in the row (default: last).
function ns:AddIcon(side, k, entry, at)
  local spells = self.db.rows[side][k]
  local spell, err, byName
  if type(entry) == "table" then
    spell = entry.spell
  else
    spell, err, byName = self:ParseSpell(entry)
    entry = spell
  end
  if not spell then return false, err end
  local name = self:SpellName(spell) or tostring(spell)
  if type(spell) == "number" then
    for i, other in ipairs(spells) do
      if type(self:EntrySpell(other)) == "string" and Same(other, entry) then
        spells[i] = entry -- a name typed by hand ("renew"): from now on followed by its ID
        self:LayoutIcons()
        self:RefreshOptions()
        return true, L.ADDED:format(name, RowName(side, k))
      end
    end
  end
  if Duplicate(spells, entry) then return false, L.DUPLICATE:format(name) end
  if #spells >= self.MAX_ICONS then return false, L.ROW_FULL:format(self.MAX_ICONS) end
  table.insert(spells, max(1, min(at or #spells + 1, #spells + 1)), entry)
  self:LayoutIcons()
  self:UpdateVisibility() -- every bar off: the icons alone may show the HUD now
  self:RefreshOptions()
  return true, (byName and L.ADDED_BY_NAME or L.ADDED):format(name, RowName(side, k))
end

function ns:RemoveIcon(side, k, i)
  table.remove(self.db.rows[side][k], i)
  self:LayoutIcons()
  self:UpdateVisibility()
  self:RefreshOptions()
end

-- Changes icon i: its spell (or rank), where it looks for its aura (auto, self, target, enemy
-- target, friend target), whether only that rank counts and whether only the aura you cast
-- counts. nil keeps the current value.
function ns:SetIconEntry(side, k, i, spell, on, exact, mine)
  local spells = self.db.rows[side][k]
  local entry = spells[i]
  if entry == nil then return false end
  if spell == nil then spell = self:EntrySpell(entry) end
  if on == nil then on = self:EntryOn(entry) end
  if exact == nil then exact = Exact(entry) end
  if mine == nil then mine = self:EntryMine(entry) end
  exact = exact and type(spell) == "number" or nil
  mine = mine or nil
  local changed = (on == "auto" and not exact and not mine) and spell or { spell = spell, on = on, exact = exact, mine = mine }
  if Duplicate(spells, changed, i) then return false, L.DUPLICATE:format(self:SpellName(spell) or tostring(spell)) end
  spells[i] = changed
  self:LayoutIcons()
  self:RefreshOptions()
  return true
end

function ns:SetIconCondition(side, k, i, on) return self:SetIconEntry(side, k, i, nil, on) end

---------------------------------------------------------------------------
-- Class spell lists (SpellCatalog.lua): { kind, rank 1 ID, rank 2 ID, ... } per spell
---------------------------------------------------------------------------
-- (alt: the same ranks under other IDs, as some spells have in Forever)
local catalogIndex -- spell ID and lower-case name -> { kind =, class =, ranks = { { rank, ID, other ID } known here },
                    --   name = the game's name, names = { English, French, German } (SpellNames.lua) }
local catalogByName -- lower-case name -> every record of that name (several classes, a cast and its aura)
local catalogList   -- every record, in the lists' order
local entryRec      -- each line of the lists -> its record (a spell in two lists: a record in each)
local function CatalogIndex()
  if catalogIndex then return catalogIndex end
  catalogIndex, catalogByName, catalogList, entryRec = {}, {}, {}, {}
  for _, class in ipairs(ns.SPELL_CATALOG or {}) do
    for _, spell in ipairs(class.spells) do
      local rec = { kind = spell[1], class = class.class, ranks = {}, names = ns.SPELL_NAMES and ns.SPELL_NAMES[spell[2]],
        everyone = spell.everyone }
      for r = 2, #spell do
        local id, alt = spell[r], spell.alt and spell.alt[r - 1] or nil
        if not ns:SpellName(id) then id, alt = alt, nil end
        local name = id and ns:SpellName(id)
        if name then
          rec.name = rec.name or name
          rec.ranks[#rec.ranks + 1] = { r - 1, id, alt or nil }
          catalogIndex[id] = rec
          if alt then catalogIndex[alt] = rec end
        end
      end
      if rec.name then
        local key = Fold(rec.name)
        if not catalogIndex[key] then catalogIndex[key] = rec end
        catalogByName[key] = catalogByName[key] or {}
        table.insert(catalogByName[key], rec)
        catalogList[#catalogList + 1] = rec
        entryRec[spell] = rec
      end
    end
  end
  return catalogIndex
end

-- The client's language: the class spells show the game's names in it, and the addon's own
-- names (SpellNames.lua) in the other languages.
local CLIENT = GetLocale and GetLocale() or "enUS"
if CLIENT == "enGB" then CLIENT = "enUS" end

-- A class spell's name in the addon's language, as the panel shows it. The hint after some
-- names (where the aura comes from: "Chilled (Frost Armor)") is added to the game's name.
function ns:CatalogName(rec)
  local own = rec.names and rec.names[self.NAME_LANGS[self.lang] or 0]
  if self.lang ~= CLIENT and own then return own end
  local hint = (own or (rec.names and rec.names[1]) or ""):match(" %b()$")
  if hint and rec.name:sub(-#hint) ~= hint then return rec.name .. hint end
  return rec.name
end

-- Search keys of a class spell: its names in the game's language, English, French, German.
local function Keys(rec)
  if not rec.keys then
    local keys, seen = {}, {}
    local function Add(name)
      local key = name and ns:SearchKey(name)
      if key and key ~= "" and not seen[key] then seen[key] = true; keys[#keys + 1] = key end
    end
    Add(rec.name)
    for i = 1, 9 do Add(rec.names and rec.names[i]) end -- (past the third: its old names)
    rec.keys = keys
  end
  return rec.keys
end

-- Does a class spell answer a search (a search key: ns:SearchKey)? An ID finds the spell it is
-- a rank of; text finds the names that contain it, in any of the languages.
function ns:CatalogMatches(rec, query)
  local id = tonumber(query)
  if id then
    for _, r in ipairs(rec.ranks) do if r[2] == id or r[3] == id then return true end end
    return false
  end
  for _, key in ipairs(Keys(rec)) do
    if key:find(query, 1, true) then return true end
  end
  return false
end

-- A class spell by its name in any language (case and accents aside).
function ns:CatalogByAnyName(text)
  local query = self:SearchKey(text)
  if query == "" or tonumber(query) then return end
  CatalogIndex()
  for _, rec in ipairs(catalogList) do
    for _, key in ipairs(Keys(rec)) do
      if key == query then return rec end
    end
  end
end

-- The IDs of one rank (several when the game has the same rank twice), for "this rank only".
function ns:RankIDs(spell)
  local ids = { [spell] = true }
  local rec = self:CatalogRecord(spell)
  for _, r in ipairs(rec and rec.ranks or {}) do
    if r[2] == spell or r[3] == spell then
      ids[r[2]] = true
      if r[3] then ids[r[3]] = true end
    end
  end
  return ids
end

-- The record of a line of the lists (SpellCatalog.lua), if this client knows the spell.
function ns:CatalogEntryRecord(spell)
  CatalogIndex()
  return entryRec[spell]
end

-- The class spell list entry of a spell (ID or name), if any.
function ns:CatalogRecord(spell)
  local index = CatalogIndex()
  if type(spell) == "string" then return index[Fold(spell)] end
  return index[spell]
end

-- The class spell list entries of a spell: its own and every other one of the same name.
function ns:CatalogRecords(spell, name)
  CatalogIndex()
  local list, seen = {}, {}
  local function Add(rec) if rec and not seen[rec] then seen[rec] = true; list[#list + 1] = rec end end
  Add(self:CatalogRecord(spell))
  for _, rec in ipairs(name and catalogByName[Fold(name)] or {}) do Add(rec) end
  return list
end

-- The ranks this client knows, { { rank, ID }, ... }, when there are more than one.
function ns:SpellRanks(spell)
  local rec = self:CatalogRecord(spell)
  if rec and #rec.ranks > 1 then return rec.ranks end
end

-- Moves icon i of one row to position j of the same or another row (drag and drop).
function ns:MoveIconTo(fromSide, fromK, i, toSide, toK, j)
  local from, to = self.db.rows[fromSide][fromK], self.db.rows[toSide][toK]
  local entry = from[i]
  if entry == nil then return false end
  if from ~= to then
    if Duplicate(to, entry) then
      return false, L.DUPLICATE:format(self:SpellName(self:EntrySpell(entry)) or tostring(self:EntrySpell(entry)))
    end
    if #to >= self.MAX_ICONS then return false, L.ROW_FULL:format(self.MAX_ICONS) end
  end
  table.remove(from, i)
  table.insert(to, max(1, min(j, #to + 1)), entry)
  self:LayoutIcons()
  self:RefreshOptions()
  return true
end

function ns:ClearRow(side, k)
  wipe(self.db.rows[side][k])
  self:LayoutIcons()
  self:UpdateVisibility()
  self:RefreshOptions()
end

---------------------------------------------------------------------------
-- Editing on the HUD (icons unlocked, on the Icons page): every row shows, the empty
-- ones too; a spell picked up in the spellbook is dropped on a row where it should go; an
-- icon is dragged to another place or row, or off the HUD to remove it.
---------------------------------------------------------------------------
local hudDrag -- the icon being dragged: { side, k, i, entry }, and where it would go
local ghost, marker

function ns:IconsEditable()
  return self:EditingIcons() and self.iconLayer:IsShown()
end

-- Every icon shown on the HUD (Clicks.lua).
function ns:ForEachIcon(fn)
  for _, side in ipairs(self.SIDES) do
    for _, row in pairs(rows[side]) do
      if row:IsShown() then
        for i = 1, #(row.spells or NONE) do
          if row.slots[i] then fn(row.slots[i]) end
        end
      end
    end
  end
end

-- For the mouse report (/cl souris): what each spell icon of the HUD reads, to tell why one keeps its look
function ns:HudIconsReport()
  local lines = { "HUD icons (spell, own icon, the game's icon and original, form, checked buttons, other icon, drawn):" }
  local function V(v) if issecretvalue(v) then return "(secret)" end return tostring(v) end
  local n = 0
  self:ForEachIcon(function(slot)
    if slot.item or not slot.name or n >= 30 then return end
    n = n + 1
    local icon, original
    if GetSpellTextureNow and slot.spell ~= nil then
      local ok, a, b = pcall(GetSpellTextureNow, slot.spell)
      if ok then icon, original = a, b end
    end
    local form, formIcon = FormIndex(slot.name)
    local actions = {}
    for _, action in ipairs(SpellActions(slot)) do
      if #actions >= 4 then break end
      local id = SpellOfAction(action)
      actions[#actions + 1] = ("%s:%s=%s(rest %s)%s"):format(action, V(id), V(ActionTexture(action)), V(id and restIcons[id]),
        (IsCurrentAction and SpellOn(IsCurrentAction, action)) and "*" or "")
    end
    local drawn = slot.icon and slot.icon.GetTexture and slot.icon:GetTexture()
    if slot.active and slot.active:IsShown() then
      local r, g, b
      if slot.active.GetVertexColor then r, g, b = slot.active:GetVertexColor() end
      drawn = ("%s, above the game's aura button %s (tint %.1f %.1f %.1f)"):format(V(drawn), V(slot.active:GetTexture()), r or 1, g or 1, b or 1)
    end
    for _, rec in pairs(slot.secure or {}) do
      if rec and rec.button and rec.button.IsShown and rec.button:IsShown() then
        drawn = V(drawn) .. " · game aura button shown (" .. V(rec.icon and rec.icon:GetTexture()) .. ")"
      end
    end
    lines[#lines + 1] = ("    %s (%s): own %s · game %s/%s · form %s %s · checked %s · buttons %s · other %s · drawn %s%s"):format(
      V(slot.name), V(slot.spell), V(slot.spellIcon), V(icon), V(original), V(form), V(formIcon), tostring(GameChecked(slot)),
      #actions > 0 and table.concat(actions, " ") or "none", V(ShownOn(slot)), V(drawn), slot.isChecked and " (gold border)" or "")
  end)
  if n == 0 then lines[#lines + 1] = "    none" end
  return lines
end

function ns:DraggingIcon() return hudDrag ~= nil end

-- What is held on the cursor, as a row entry: a spell's ID, or "item:ID" (from the bags).
local function CursorSpell()
  if not GetCursorInfo then return end
  local kind, a, _, spellID = GetCursorInfo()
  if kind == "spell" and type(spellID) == "number" and spellID > 0 then return spellID end
  if kind == "item" and type(a) == "number" then return ns:ItemEntry(a) end
end

local function Cursor(frame)
  local x, y = GetCursorPosition()
  local s = frame:GetEffectiveScale()
  return x / s, y / s
end

local function Inside(frame)
  if not frame:IsVisible() then return false end
  local x, y = Cursor(frame)
  local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
  return l ~= nil and x >= l and x <= r and y >= b and y <= t
end

-- Where in a row the cursor is: the place before the first icon whose middle is past it
-- (the icon being dragged left out: skip, else the HUD's own drag).
local function PlaceAt(row, skip)
  skip = skip or hudDrag
  local x = Cursor(row)
  local at = 1
  for i = 1, #(row.spells or NONE) do
    local slot = row.slots[i]
    if not (skip and skip.side == row.side and skip.k == row.k and skip.i == i) then
      local l, r = slot:GetLeft(), slot:GetRight()
      if l and x > (l + r) / 2 then at = at + 1 end
    end
  end
  return at
end

local function RowUnderCursor()
  for _, side in ipairs(ns.SIDES) do
    for _, row in pairs(rows[side]) do
      if row:IsShown() and Inside(row.hit) then return row end
    end
  end
end

-- A spell from the spellbook, or an item from the bags, let go over a row (or one of its
-- icons): added there.
local function DropSpell(row, at)
  local spellID = CursorSpell()
  if not spellID or not ns:IconsEditable() then return end
  local ok, msg = ns:AddIcon(row.side, row.k, spellID, at or PlaceAt(row))
  if ok and ns.chatDrop then ns:ChatDropPlaced() end -- a spell from the chat: a little time to move it
  if ok and ClearCursor then ClearCursor() end
  if not ok then ns:ShowError(msg) end
end

local function Ghost()
  if ghost then return ghost end
  ghost = CreateFrame("Frame", nil, UIParent)
  ghost:SetSize(30, 30)
  ghost:SetFrameStrata("TOOLTIP")
  ghost.tex = ghost:CreateTexture(nil, "ARTWORK")
  ghost.tex:SetAllPoints()
  ghost.tex:SetTexCoord(TRIM, 1 - TRIM, TRIM, 1 - TRIM)
  ghost.cross = ghost:CreateTexture(nil, "OVERLAY") -- let go here: removed
  ghost.cross:SetSize(20, 20)
  ghost.cross:SetPoint("BOTTOMRIGHT", 6, -6)
  ghost.cross:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
  ghost:SetAlpha(.85)
  ghost:Hide()
  return ghost
end

-- Where a dragged icon would land: a gold line before the icon that would follow, or after
-- the last one (skip: the icon dragged, left out).
local function Mark(row, at, skip)
  if not marker then
    marker = ns.iconLayer:CreateTexture(nil, "OVERLAY")
    marker:SetColorTexture(1, .82, 0, .9)
    marker:SetWidth(3)
  end
  marker:SetShown(row ~= nil)
  if not row then return end
  local others = {}
  for i = 1, #(row.spells or NONE) do
    if not (skip and skip.side == row.side and skip.k == row.k and skip.i == i) then others[#others + 1] = row.slots[i] end
  end
  marker:ClearAllPoints()
  marker:SetHeight(row:GetHeight())
  local next = others[at]
  if next then
    marker:SetPoint("RIGHT", next, "LEFT", -1, 0)
  elseif others[#others] then
    marker:SetPoint("LEFT", others[#others], "RIGHT", 1, 0)
  else
    marker:SetPoint("CENTER", row, "CENTER")
  end
end

-- The drag follows the cursor: the place it would land is marked; off the HUD, a cross says
-- the icon goes.
local function TrackDrag()
  local x, y = Cursor(UIParent)
  ghost:ClearAllPoints()
  ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
  local row = RowUnderCursor()
  hudDrag.row, hudDrag.at = row, row and PlaceAt(row)
  hudDrag.out = not row and not Inside(ns.hud)
  ghost.tex:SetVertexColor(1, hudDrag.out and .35 or 1, hudDrag.out and .35 or 1)
  ghost.cross:SetShown(hudDrag.out)
  Mark(row, hudDrag.at, hudDrag)
end

local watcher -- (below: runs while a drag lasts)

-- The drag is over: the ghost goes, the dragged icon is lit again.
local function StopDrag()
  local d = hudDrag
  hudDrag = nil
  ghost:Hide()
  Mark(nil)
  local from = rows[d.side] and rows[d.side][d.k]
  if from and from.slots[d.i] then from.slots[d.i]:SetAlpha(1) end
  -- a spell from the chat moved again: a new grace before the rows close
  if ns.chatDrop and ns.chatDrop.placed then ns:ChatDropPlaced() end
  return d
end

-- Still the icon picked up, in the profile it came from? (The options closing can switch
-- the HUD to another profile while the button is held.)
local function DragValid(d)
  local row = d.profile == ns.db and ns.db.rows[d.side] and ns.db.rows[d.side][d.k]
  return row and row[d.i] == d.entry and ns:IconsEditable() and ns.iconLayer:IsVisible()
end

-- Let go elsewhere than where it should: nothing moves.
local function CancelDrag()
  if not hudDrag then return end
  StopDrag()
  ns:LayoutIcons()
end

local function EndDrag()
  if not hudDrag then return end
  if not DragValid(hudDrag) then return CancelDrag() end
  TrackDrag()
  local d = StopDrag()
  if d.row then
    local ok, msg = ns:MoveIconTo(d.side, d.k, d.i, d.row.side, d.row.k, d.at)
    if not ok then
      ns:ShowError(msg)
      ns:LayoutIcons() -- the icon stays: its own look again
    end
  elseif d.out then
    ns:RemoveIcon(d.side, d.k, d.i)
  else
    ns:LayoutIcons()
  end
end

local function StartDrag(slot)
  if hudDrag or not ns:IconsEditable() then return end
  local entry = ns.db.rows[slot.side][slot.k][slot.index]
  if entry == nil then return end
  if GameTooltip then GameTooltip:Hide() end
  Ghost()
  hudDrag = { side = slot.side, k = slot.k, i = slot.index, entry = entry, profile = ns.db }
  watcher:Show()
  ghost.tex:SetTexture(slot.spellIcon)
  slot:SetAlpha(.3)
  ghost:Show()
  TrackDrag()
end

local function SlotTooltip(self)
  if not GameTooltip or hudDrag or not ns:IconsEditable() then return end
  ns:TooltipAt(self)
  local spell = self.spell
  if not (type(spell) == "number" and GameTooltip.SetSpellByID and pcall(GameTooltip.SetSpellByID, GameTooltip, spell)) then
    GameTooltip:SetText(self.name or tostring(spell))
  end
  GameTooltip:AddLine(L.HUD_ICON_TIP, 1, .82, 0, true)
  GameTooltip:Show()
end

function ns:EditableSlot(slot)
  slot:EnableMouse(false)
  slot:RegisterForDrag("LeftButton")
  slot:SetScript("OnDragStart", StartDrag)
  slot:SetScript("OnDragStop", EndDrag)
  slot:SetScript("OnReceiveDrag", function(self) DropSpell(self:GetParent(), self.index) end)
  slot:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" then -- a right-click takes it off the bar
      if hudDrag or not ns:IconsEditable() then return end
      if ns.db.rows[self.side][self.k][self.index] == nil then return end
      if GameTooltip then GameTooltip:Hide() end
      ns:RemoveIcon(self.side, self.k, self.index)
    elseif CursorSpell() then
      DropSpell(self:GetParent(), self.index)
    end
  end)
  slot:SetScript("OnEnter", SlotTooltip)
  slot:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

-- Each row's area while editing: the bar's width (or its icons', if wider), tinted, named
-- when empty; spells are dropped on it.
function ns:EditableRow(row)
  local hit = CreateFrame("Frame", nil, row)
  hit:SetPoint("CENTER")
  hit:SetFrameLevel(row:GetFrameLevel()) -- under the icons
  hit:EnableMouse(false)
  hit:Hide()
  local tint = hit:CreateTexture(nil, "BACKGROUND")
  tint:SetAllPoints()
  tint:SetColorTexture(.25, .6, 1, .25)
  hit.label = hit:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hit.label:SetPoint("CENTER")
  hit:SetScript("OnReceiveDrag", function() DropSpell(row) end)
  hit:SetScript("OnMouseUp", function() if CursorSpell() then DropSpell(row) end end)
  row.hit = hit
  function row:EditMode(on, width, height)
    hit:SetShown(on)
    hit:EnableMouse(on)
    if not on then return end
    hit:SetSize(width, height)
    hit.label:SetText(#(self.spells or NONE) == 0 and L.DROP_HERE:format(RowName(self.side, self.k)) or "")
  end
end

---------------------------------------------------------------------------
-- The options open: a spell held on the cursor (picked up in the spellbook) or dragged in the
-- options (from the class spells panel, or an icon of a row) opens the HUD's rows for it, even
-- locked, to be dropped there; they close again once it is let go.
---------------------------------------------------------------------------
local heldCursor, heldOptions
local held = CreateFrame("Frame")

local function SetHeld()
  local now = (heldCursor or heldOptions) and true or nil
  if now == ns.heldDrop then return end
  ns.heldDrop = now
  ns:LayoutIcons()
  ns:UpdateVisibility()
  ns:ApplyFade()
end

held:SetScript("OnEvent", function()
  heldCursor = CursorSpell() ~= nil
  SetHeld()
end)

function ns:WatchHeldSpell(on)
  if on then held:RegisterEvent("CURSOR_CHANGED") else held:UnregisterEvent("CURSOR_CHANGED") end
  heldCursor = on and CursorSpell() ~= nil
  if not on then heldOptions = nil end
  SetHeld()
end

-- A drag of the options starts (on) or ends.
function ns:HoldForOptions(on)
  heldOptions = on and self.optionsOpen or nil
  if not on then Mark(nil) end
  SetHeld()
end

-- The options' drag over the HUD: the row under the cursor and the place there (the icon
-- dragged left out: skip = { side, k, i }), marked; else nothing. Also whether the cursor is
-- over the HUD at all.
function ns:HUDDropAt(skip)
  local row = self:IconsEditable() and RowUnderCursor()
  if not row then
    Mark(nil)
    return nil, nil, nil, Inside(self.hud)
  end
  local at = PlaceAt(row, skip or {})
  Mark(row, at, skip)
  return row.side, row.k, at, true
end

function ns:HUDDropDone() Mark(nil) end

-- Drags end with the button let go (also when the icon went away meanwhile); they are
-- called off when the icons are locked again or the HUD shows another profile. (Only while
-- one lasts: hidden otherwise.)
watcher = CreateFrame("Frame")
watcher:Hide()
watcher:SetScript("OnUpdate", function(self)
  if not hudDrag then return self:Hide() end
  if not DragValid(hudDrag) then
    CancelDrag()
  elseif IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
    EndDrag()
  else
    TrackDrag()
  end
end)
