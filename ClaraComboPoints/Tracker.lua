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
local dirty

local function Plain(v)
  if not issecretvalue(v) and type(v) == "number" then return v end
end

-- Lower case, accented capitals included (string.lower leaves "É" or "Ü" as they are).
local function Fold(s)
  return (s:lower():gsub("\195([\128-\158])", function(c) return "\195" .. string.char(c:byte() + 32) end))
end
ns.Fold = function(_, s) return Fold(s) end

function ns:SpellIcon(spell)
  if GetSpellTexture then
    local ok, icon = pcall(GetSpellTexture, spell)
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
-- The button frame art, cut in nine so it fits square icons and combo-point-shaped cells
-- alike (corners keep their size, edges stretch). Without atlas info: drawn whole.
local frameArt
local function FrameArt()
  if frameArt == nil then
    frameArt = false
    if C_Texture and C_Texture.GetAtlasInfo then
      local ok, info = pcall(C_Texture.GetAtlasInfo, FRAME_ATLAS)
      if ok and type(info) == "table" and info.file and Plain(info.leftTexCoord) then
        frameArt = { file = info.file, info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord }
      end
    end
  end
  return frameArt
end

local PIECES = { -- column, row (1 = left/top, 2 = middle, 3 = right/bottom)
  { 1, 1 }, { 2, 1 }, { 3, 1 }, { 1, 2 }, { 3, 2 }, { 1, 3 }, { 2, 3 }, { 3, 3 },
}

local function LayoutFrame(owner, pieces, w, h)
  local art = FrameArt()
  if not art then
    pieces[1]:SetAllPoints()
    pieces[1]:SetAtlas(FRAME_ATLAS)
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
          LayoutFrame(slot, slot.frame, w, size)
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
          slot.name = self:SpellName(spell)
          slot.byName = type(spell) == "string"
          slot.spellIcon = self:SpellIcon(spell)
          if slot.spellIcon == QUESTION_MARK and slot.name then slot.spellIcon = self:SeenIcon(slot.name) end
          slot.hasCooldown = HasCooldown(slot)
        end
        row:Show()
      end
    end
    if side == "above" then self:AnchorMoverText(anchor) end
  end
  self:SyncAuraButtons()
  self:MarkIconsDirty() -- states read on the next frame, once
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

local function SetSlot(slot, look, aura, unit)
  slot.cd:Clear()
  slot.cd:SetReverse(false)
  if slot.cd.SetHideCountdownNumbers then slot.cd:SetHideCountdownNumbers(not look.timers) end
  slot.count:SetText("")
  local running
  if ns.preview then
    -- a sample: lit, with a cooldown under way
    slot.icon:SetTexture(slot.spellIcon)
    slot.icon:SetDesaturated(false)
    slot:SetAlpha(1)
    slot:Show()
    slot.cd:SetCooldown(GetTime() - 15, 45)
    return
  end
  if aura then
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
    running = SpellCooldown(slot)
  end
  if not (aura and Plain(aura.applications) and aura.applications > 1) then
    local charges = Charges(slot)
    if charges ~= nil then slot.count:SetText(charges) end
  end
  local lit = aura or running or slot.hasCooldown
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
  for _, side in ipairs(self.SIDES) do
    for _, row in pairs(rows[side]) do
      for i = 1, #(row.spells or {}) do
        local slot = row.slots[i]
        local aura, unit, otherRank
        if slot.name then aura, unit, otherRank = FindAura(slot) end
        SetSlot(slot, look, aura, unit)
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
  for _, rec in ipairs(ns:CatalogRecords(slot.spell, slot.name)) do
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
      local n = row:IsShown() and #(row.spells or {}) or 0
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
      for i = 1, #(row.spells or {}) do
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
local function CatalogIndex()
  if catalogIndex then return catalogIndex end
  catalogIndex, catalogByName, catalogList = {}, {}, {}
  for _, class in ipairs(ns.SPELL_CATALOG or {}) do
    for _, spell in ipairs(class.spells) do
      local rec = { kind = spell[1], class = class.class, ranks = {}, names = ns.SPELL_NAMES and ns.SPELL_NAMES[spell[2]] }
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
    for i = 1, 3 do Add(rec.names and rec.names[i]) end
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
-- Editing on the HUD (icons unlocked, Position on the bar page): every row shows, the empty
-- ones too; a spell picked up in the spellbook is dropped on a row where it should go; an
-- icon is dragged to another place or row, or off the HUD to remove it.
---------------------------------------------------------------------------
local hudDrag -- the icon being dragged: { side, k, i, entry }, and where it would go
local ghost, marker

function ns:IconsEditable()
  return self.db ~= nil and self.db.iconsLocked == false and self.iconLayer:IsShown()
end

local function CursorSpell()
  if not GetCursorInfo then return end
  local kind, _, _, spellID = GetCursorInfo()
  if kind == "spell" and type(spellID) == "number" and spellID > 0 then return spellID end
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
-- (the icon being dragged left out).
local function PlaceAt(row)
  local x = Cursor(row)
  local at = 1
  for i = 1, #(row.spells or {}) do
    local slot = row.slots[i]
    if not (hudDrag and hudDrag.side == row.side and hudDrag.k == row.k and hudDrag.i == i) then
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

-- A spell from the spellbook let go over a row (or one of its icons): added there.
local function DropSpell(row, at)
  local spellID = CursorSpell()
  if not spellID or not ns:IconsEditable() then return end
  local ok, msg = ns:AddIcon(row.side, row.k, spellID, at or PlaceAt(row))
  if ok and ClearCursor then ClearCursor() end
  if msg then ns.Print(msg) end
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
  marker = ns.iconLayer:CreateTexture(nil, "OVERLAY")
  marker:SetColorTexture(1, .82, 0, .9)
  marker:SetWidth(3)
  marker:Hide()
  return ghost
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
  marker:SetShown(row ~= nil)
  if row then
    -- before the icon that would follow, or after the last one
    local others = {}
    for i = 1, #(row.spells or {}) do
      if not (hudDrag.side == row.side and hudDrag.k == row.k and hudDrag.i == i) then others[#others + 1] = row.slots[i] end
    end
    marker:ClearAllPoints()
    marker:SetHeight(row:GetHeight())
    local next = others[hudDrag.at]
    if next then
      marker:SetPoint("RIGHT", next, "LEFT", -1, 0)
    elseif others[#others] then
      marker:SetPoint("LEFT", others[#others], "RIGHT", 1, 0)
    else
      marker:SetPoint("CENTER", row, "CENTER")
    end
  end
end

-- The drag is over: the ghost goes, the dragged icon is lit again.
local function StopDrag()
  local d = hudDrag
  hudDrag = nil
  ghost:Hide()
  marker:Hide()
  local from = rows[d.side] and rows[d.side][d.k]
  if from and from.slots[d.i] then from.slots[d.i]:SetAlpha(1) end
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
      if msg then ns.Print(msg) end
      ns:LayoutIcons() -- the icon stays: its own look again
    end
  elseif d.out then
    local spell = ns:EntrySpell(d.entry)
    ns:RemoveIcon(d.side, d.k, d.i)
    ns.Print(L.REMOVED:format(ns:SpellName(spell) or tostring(spell), RowName(d.side, d.k)))
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
  ghost.tex:SetTexture(slot.spellIcon)
  slot:SetAlpha(.3)
  ghost:Show()
  TrackDrag()
end

local function SlotTooltip(self)
  if not GameTooltip or hudDrag or not ns:IconsEditable() then return end
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
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
      local entry = ns.db.rows[self.side][self.k][self.index]
      if entry == nil then return end
      local spell = ns:EntrySpell(entry)
      if GameTooltip then GameTooltip:Hide() end
      ns:RemoveIcon(self.side, self.k, self.index)
      ns.Print(L.REMOVED:format(ns:SpellName(spell) or tostring(spell), RowName(self.side, self.k)))
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
    hit.label:SetText(#(self.spells or {}) == 0 and L.DROP_HERE:format(RowName(self.side, self.k)) or "")
  end
end

-- Drags end with the button let go (also when the icon went away meanwhile); they are
-- called off when the icons are locked again or the HUD shows another profile.
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
  if not hudDrag then return end
  if not DragValid(hudDrag) then
    CancelDrag()
  elseif IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
    EndDrag()
  else
    TrackDrag()
  end
end)
