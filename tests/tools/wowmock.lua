-- Minimal WoW API mock for running Clara Combo Points outside the game.
-- Unknown widget methods raise errors so typos are caught.

local M = { frames = {}, regions = {}, eventFrames = {}, log = {} }
_G.MOCK = M

-- secret values ---------------------------------------------------------------
local secretMT = {}
local function boom() error("operation on secret value", 2) end
for _, k in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm", "__concat", "__len", "__eq", "__lt", "__le", "__index", "__newindex", "__call" }) do
  secretMT[k] = boom
end
secretMT.__tostring = function() return "<secret>" end
function M.Secret(v) return setmetatable({ __v = v }, secretMT) end
local function reveal(v) if getmetatable(v) == secretMT then return rawget(v, "__v") end return v end
M.reveal = reveal
function issecretvalue(v) return getmetatable(v) == secretMT end

-- game state ----------------------------------------------------------------
M.state = {
  class = "ROGUE", energy = 100, energyMax = 100,
  target = nil, -- { cp = n, dead = false, hostile = true, feign = false }
  secret = false, playerCP = 0, inCombat = false,
  physH = 1359, uiScale = 0.71, locale = "frFR",
}
local S = M.state

Enum = { PowerType = { Mana = 0, Rage = 1, Energy = 3, ComboPoints = 4 }, CombatLogMessageOrder = { Newest = 0, Oldest = 1 }, AddOnRestrictionState = { Inactive = 0, Activating = 1, Active = 2 } }
-- The game's aura buttons (and everything in them) are closed to addons while auras are
-- secret: a call counts in M.restrictedWhileSecret (the game would refuse it).
local function Guard(obj)
  if M.gameCall or not (C_Secrets and C_Secrets.ShouldAurasBeSecret()) then return end
  local f = obj
  while f do
    if rawget(f, "_restricted") then
      M.restrictedWhileSecret = (M.restrictedWhileSecret or 0) + 1
      return
    end
    f = rawget(f, "_parent")
  end
end
M.Guard = Guard
function UnitClass() return "Rogue", S.class end
function UnitFactionGroup(u) return S.faction or "Alliance", S.faction or "Alliance" end
function GetRealmName() return "Forever" end
function UnitRace(u) return "Human", "Human" end
function GetCurrentRegion() return 3 end
function ReloadUI() M.reloaded = (M.reloaded or 0) + 1 end
-- spells the character knows (S.knownSpells[id] = true), shapeshift form index (S.form)
function IsPlayerSpell(id) return (S.knownSpells or {})[id] == true end
function GetShapeshiftForm() return S.form or 0 end
function UnitName(u) if u == "target" and S.target then return S.target.name or "Target" end if u == "player" then return "Lola" end end
function UnitIsUnit(a, b) return a == b end
-- secure state drivers: M.stateDrivers[frame] = { state, value }
M.stateDrivers = {}
function RegisterStateDriver(frame, state, value) M.stateDrivers[frame] = { state, value } end
function UnregisterStateDriver(frame, state) M.stateDrivers[frame] = nil end
function SecureHandlerSetFrameRef(frame, name, ref) frame:SetAttribute("frameref-" .. name, ref) end
-- chat: M.sent holds what was sent ({ text, chatType })
M.sent = {}
C_ChatInfo = C_ChatInfo or {}
C_ChatInfo.SendChatMessage = function(text, chatType) table.insert(M.sent, { text, chatType }) end
ERR_LEARN_ABILITY_S = "You have learned a new ability: %s."
ERR_LEARN_SPELL_S = "You have learned a new spell: %s."
ERR_LEARN_PASSIVE_S = "You have learned a new passive effect: %s."
-- secure function hooks
function hooksecurefunc(a, b, c)
  local t, name, fn = _G, a, b
  if type(a) == "table" then t, name, fn = a, b, c end
  local old = t[name]
  if type(old) ~= "function" then return end
  t[name] = function(...) local r = { old(...) }; fn(...); return unpack(r) end
end
function UnitExists(u) if u == "target" then return S.target ~= nil end return u == "player" end
function UnitIsDead(u) return u == "target" and S.target and S.target.dead or false end
function UnitIsFeignDeath(u) return u == "target" and S.target and S.target.feign or false end
function UnitCanAttack(a, b) return b == "target" and S.target and S.target.hostile or false end
local function wrap(v) if S.secret then return M.Secret(v) end return v end
function UnitPower(u, p)
  if p == 3 then return wrap(math.floor(S.energy)) end
  if p == 1 then return wrap(math.floor(S.rage or 0)) end
  if p == 4 then return wrap(S.playerCP) end
  if p == 0 then return wrap(S.mana or 0) end
  return 0
end
function UnitHealth(u) return wrap(u == "player" and (S.health or 1000) or 0) end
function UnitHealthMax(u) return wrap(u == "player" and (S.healthMax or 1000) or 0) end
RAID_CLASS_COLORS = { ROGUE = { r = 1, g = .96, b = .41 }, DRUID = { r = 1, g = .49, b = .04 }, WARRIOR = { r = .78, g = .61, b = .43 } }
function UnitPowerType(u) local pt = S.powerType or 3; if S.secretPowerType then return M.Secret(pt) end return pt end
function UnitPowerMax(u, p) if p == 3 then return wrap(S.energyMax) end if p == 1 then return wrap(S.rageMax or 100) end if p == 0 then return wrap(S.manaMax or 0) end return 5 end
function UnitAffectingCombat(u) return S.inCombat end
function IsShiftKeyDown() return M.shift end
-- cursor in screen pixels (UIParent effective scale applied by the caller, like the client)
function GetCursorPosition() return M.cursorX or 0, M.cursorY or 0 end
function IsMouseButtonDown(b) return M.mouseDown == true end
-- M.cursorSpell: spell ID picked up in the spellbook
-- M.cursorItem: item ID picked up in the bags
function GetCursorInfo()
  if M.cursorSpell then return "spell", 12, "spell", M.cursorSpell end
  if M.cursorItem then return "item", M.cursorItem, "|Hitem:" .. M.cursorItem .. "|h[x]|h" end
end
function ClearCursor()
  local had = M.cursorSpell ~= nil or M.cursorItem ~= nil
  M.cursorSpell, M.cursorItem = nil, nil
  if had and M.eventFrames then M.Fire("CURSOR_CHANGED") end
end
C_Texture = { GetAtlasInfo = function(atlas)
  return { file = "ATLAS:" .. atlas, leftTexCoord = 0, rightTexCoord = 1, topTexCoord = 0, bottomTexCoord = 1, width = 46, height = 45 }
end }
-- is the cursor over a shown region (its rect, as the game's IsMouseOver)?
function M.MouseOver(r)
  if not r:IsVisible() then return false end
  M.ResetLayout()
  local l, b, w, h = M.AbsRect(r)
  local x, y = M.cursorX or 0, M.cursorY or 0
  return x >= l and x <= l + w and y >= b and y <= b + h
end
-- an options group box: the tooltip-border backdrop, or the character sheet's bronze border art
function M.IsGroupBox(f)
  if f._backdrop and f._backdrop.edgeFile and f._backdrop.edgeFile:find("Tooltip") then return true end
  return f.border ~= nil and f.border._atlas == "common-insideframe"
end
-- puts the cursor on the centre of a region
function M.CursorOn(r, dx)
  M.ResetLayout()
  local l, b, w, h = M.AbsRect(r)
  M.cursorX, M.cursorY = l + w / 2 + (dx or 0), b + h / 2
end

-- spells: id -> { name, icon, rage cost }; names are per client language in the real game
M.SPELLS = {
  [78] = { "Heroic Strike", 132282, 15 }, [11567] = { "Heroic Strike", 132282, 15 }, [845] = { "Cleave", 132338, 20 },
  [6807] = { "Maul", 132136, 15 }, [9881] = { "Maul", 132136, 15 }, [22842] = { "Frenzied Regeneration", 132091, 0 },
  [1464] = { "Slam", 132340, 15 }, [7386] = { "Sunder Armor", 132363, 15 }, [11597] = { "Sunder Armor", 132363, 15 },
  [1160] = { "Demoralizing Shout", 132366, 10 }, [1715] = { "Hamstring", 132316, 10 }, [6673] = { "Battle Shout", 132333, 10 },
  [2687] = { "Bloodrage", 132277, 0 }, [6774] = { "Slice and Dice", 132306, 0 }, [1943] = { "Rupture", 132302, 0 },
  [139] = { "Renew", 135953, 0 }, [425270] = { "Renew", 135953, 0 }, [6074] = { "Renew", 135953, 0 }, [6075] = { "Renew", 135953, 0 },
  [774] = { "Rejuvenation", 136081, 0 }, [1058] = { "Rejuvenation", 136081, 0 },
  [1243] = { "Power Word: Fortitude", 135987, 0 }, [1244] = { "Power Word: Fortitude", 135987, 0 },
  [6788] = { "Weakened Soul", 136066, 0 }, [8921] = { "Moonfire", 136096, 0 }, [8924] = { "Moonfire", 136096, 0 },
  [16870] = { "Clearcasting", 136170, 0 },
  [768] = { "Cat Form", 132115, 0 }, [5487] = { "Bear Form", 132276, 0 }, [9634] = { "Dire Bear Form", 132276, 0 },
  [1238122] = { "Feral Charge", 132183, 5 }, [1082] = { "Claw", 132140, 0 }, [2457] = { "Battle Stance", 132349, 0 },
  [71] = { "Defensive Stance", 132341, 0 }, [100] = { "Charge", 132337, 0 },
  [8017] = { "Rockbiter Weapon", 136086, 0 }, [16314] = { "Rockbiter Weapon", 136086, 0 },
  [8232] = { "Windfury Weapon", 136018, 0 }, [8233] = { "Windfury Weapon", 136018, 0 }, [8024] = { "Flametongue Weapon", 135814, 0 },
  [8679] = { "Instant Poison", 132273, 0 }, [17538] = { "Elixir of the Mongoose", 134812, 0 }, [17534] = { "Healing Potion", 134833, 0 },
  [25122] = { "Brilliant Wizard Oil", 134727, 0 }, [99002] = { "Forever Venom", 132290, 0 },
  [403] = { "Lightning Bolt", 136048, 0 }, [331] = { "Healing Wave", 136052, 0 }, [8042] = { "Earth Shock", 136026, 0 },
  -- the General tab and the races
  [6603] = { "Attack", 133478, 0 }, [5019] = { "Shoot", 132317, 0 }, [75] = { "Auto Shot", 135493, 0 },
  [2383] = { "Find Herbs", 133939, 0 }, [2580] = { "Find Minerals", 136025, 0 },
  [1259799] = { "Elune's Light", 136057, 0 }, [20580] = { "Shadowmeld", 132089, 0 },
  [1259718] = { "Will to Survive", 136129, 0 }, [20600] = { "Perception", 136090, 0 },
  [1259823] = { "Eureka!", 4226119, 0 }, [20589] = { "Escape Artist", 132309, 0 },
  [20594] = { "Stoneform", 136225, 0 }, [3481] = { "Find Treasure", 135727, 0 },
  [1259705] = { "Read Leyline", 236219, 0 }, [1259416] = { "Walk on Air", 132845, 0 },
  [20577] = { "Cannibalize", 132278, 0 }, [7744] = { "Will of the Forsaken", 136187, 0 },
  [20549] = { "War Stomp", 132368, 0 }, [20572] = { "Blood Fury", 135726, 0 }, [1299026] = { "Shatter Curse", 136082, 0 },
  [20554] = { "Berserking", 135727, 0 }, [1260270] = { "Rapid Regeneration", 1850550, 0 }, [1259686] = { "Skysight", 1029587, 0 },
  [1038] = { "Salvation", 135967, 0 }, [25895] = { "Mass Salvation", 135910, 0 },
  [1784] = { "Stealth", 132320, 0 }, [5215] = { "Prowl", 132089, 0 }, [6770] = { "Sap", 132310, 0 },
  [9005] = { "Pounce", 132142, 0 },
}
-- specialisations: S.spec (index), S.specNames = { name, ... } (the character's class)
C_SpecializationInfo = C_SpecializationInfo or {}
C_SpecializationInfo.GetSpecialization = function() return S.spec end
C_SpecializationInfo.GetSpecializationInfo = function(n) return 100 + n, (S.specNames or {})[n] end
function GetSpecializationInfoForClassID(classID, n) return 200 + n, (S.classSpecNames or {})[classID .. ":" .. n] end
-- the stance bar: S.forms = { spell ID, ... } (a druid's forms, a warrior's stances)
function GetNumShapeshiftForms() return #(S.forms or {}) end
function GetShapeshiftFormInfo(i)
  local id = (S.forms or {})[i]
  if id then return M.SPELLS[id] and M.SPELLS[id][2], S.form == i, true, id end
end
-- spell tooltips: S.tooltips[id] = { "line", ... } (else the spell's name alone)
C_TooltipInfo = C_TooltipInfo or {}
C_TooltipInfo.GetSpellByID = function(id)
  local lines = {}
  for _, text in ipairs((S.tooltips or {})[id] or { M.SPELLS[id] and M.SPELLS[id][1] or "?" }) do
    lines[#lines + 1] = { leftText = text }
  end
  M.tooltipReads = (M.tooltipReads or 0) + 1
  return { lines = lines }
end
M.HARMFUL = { ["Sunder Armor"] = true, ["Hamstring"] = true, ["Demoralizing Shout"] = true, ["Rupture"] = true, ["Moonfire"] = true }
M.HELPFUL = { ["Battle Shout"] = true, ["Bloodrage"] = true, ["Slice and Dice"] = true, ["Renew"] = true, ["Rejuvenation"] = true,
  ["Power Word: Fortitude"] = true }
M.KNOWN = { ["Heroic Strike"] = 11567, ["Sunder Armor"] = 11597, ["Maul"] = 9881, ["Cleave"] = 845, ["Slam"] = 1464,
  ["Bloodrage"] = 2687, ["Hamstring"] = 1715, ["Battle Shout"] = 6673, ["Demoralizing Shout"] = 1160 }
local function spellRow(spell)
  if type(spell) == "number" then return M.SPELLS[spell], spell end
  local id = M.KNOWN[spell]
  if id then return M.SPELLS[id], id end
end
C_Spell = {
  -- picked up: on the cursor (M.cursorSpell), if the character knows it and it is not passive
  PickupSpell = function(id)
    if (S.knownSpells or {})[id] and not (S.passiveSpells or {})[id] then M.cursorSpell = id; M.Fire("CURSOR_CHANGED") end
  end,
  GetSpellName = function(spell) local r = spellRow(spell); return r and r[1] end,
  GetSpellSubtext = function(spell) return (S.subtexts or {})[spell] end,
  GetSpellTexture = function(spell) local r = spellRow(spell); return r and r[2] end,
  GetSpellInfo = function(spell) local r, id = spellRow(spell); if r then return { name = r[1], spellID = id, iconID = r[2] } end end,
  -- S.cooldowns[name] = { start, duration, gcd }; S.charges[name] = { current, max }
  GetSpellCooldown = function(spell)
    local r, id = spellRow(spell); if not r then return nil end
    local cd = (S.cooldowns or {})[r[1]]
    if not cd then return { startTime = 0, duration = 0, isEnabled = true, isActive = false, modRate = 1 } end
    local info = { startTime = cd[1], duration = cd[2], isEnabled = true, isActive = cd[2] > 0, modRate = 1, isOnGCD = cd[3] or false }
    if S.secretCooldowns then info.startTime = M.Secret(cd[1]); info.duration = M.Secret(cd[2]) end
    return info
  end,
  GetSpellCooldownDuration = function(spell, ignoreGCD)
    local r = spellRow(spell); if not r then return nil end
    local cd = (S.cooldowns or {})[r[1]]
    if not cd or (cd[3] and ignoreGCD) then return { _start = 0, _duration = 0 } end
    return { _start = cd[1], _duration = cd[2] }
  end,
  GetSpellCharges = function(spell)
    local r = spellRow(spell); if not r then return nil end
    local c = (S.charges or {})[r[1]]
    if not c then return nil end
    return { currentCharges = S.secretCooldowns and M.Secret(c[1]) or c[1], maxCharges = c[2], isActive = c[1] < c[2], cooldownStartTime = 0, cooldownDuration = 0, chargeModRate = 1 }
  end,
  IsSpellHarmful = function(spell) local r = spellRow(spell); return r ~= nil and M.HARMFUL[r[1]] == true end,
  IsSpellHelpful = function(spell) local r = spellRow(spell); return r ~= nil and M.HELPFUL[r[1]] == true end,
  IsCurrentSpell = function(spell)
    if type(spell) == "string" then local r, id = spellRow(spell); return id ~= nil and S.queued == id end
    return S.queued == spell
  end,
  GetSpellPowerCost = function(spell)
    local r, id = spellRow(spell); if not r then return nil end
    local mana = (S.manaCosts or {})[id]
    if mana then return { { type = 0, name = "MANA", cost = mana, minCost = mana } } end
    if r[3] == 0 then return {} end
    return { { type = 1, name = "RAGE", cost = r[3], minCost = r[3] } }
  end,
}
function UnitCastingInfo(u)
  local c = u == "player" and S.casting
  if not c then return nil end
  return M.SPELLS[c][1], M.SPELLS[c][1], M.SPELLS[c][2], 0, 1500, false, "cast", false, c
end
-- auras: S.auras[unit] = { { name =, icon =, applications =, duration =, expirationTime =, harmful =, id =, spellId = } }
-- (id: aura instance ID, else its index; S.secretAuras: hidden from addons, as in combat)
local function auraCopy(a, i)
  local copy = {}
  for k, v in pairs(a) do copy[k] = v end
  copy.auraInstanceID = a.id or i
  if S.secretFields then copy.applications = M.Secret(a.applications); copy.expirationTime = M.Secret(a.expirationTime) end
  return copy
end
-- (filter PLAYER: only the auras the player cast, a.source == "player"; others' have a.source "other")
local function auraFits(a, filter)
  filter = filter or ""
  if filter:find("PLAYER") and (a.source or "player") ~= "player" then return false end
  return (filter:find("HARMFUL") ~= nil) == (a.harmful == true)
end
local function auraByID(unit, id)
  for i, a in ipairs((S.auras or {})[unit] or {}) do if (a.id or i) == id then return a end end
end
C_UnitAuras = {
  GetAuraDataBySpellName = function(unit, name, filter)
    M.auraLookups = (M.auraLookups or 0) + 1
    if S.secretAuras then return nil end
    if unit == "target" and not S.target then return nil end
    for i, a in ipairs((S.auras or {})[unit] or {}) do
      if a.name == name and auraFits(a, filter) then return auraCopy(a, i) end
    end
  end,
  GetAuraDataByIndex = function(unit, index, filter)
    if S.secretAuras then return nil end
    local n = 0
    for i, a in ipairs((S.auras or {})[unit] or {}) do
      if auraFits(a, filter) then n = n + 1; if n == index then return auraCopy(a, i) end end
    end
  end,
  GetUnitAuraInstanceIDs = function(unit, filter)
    if unit == "target" and not S.target then return nil end
    local ids = {}
    for i, a in ipairs((S.auras or {})[unit] or {}) do if auraFits(a, filter) then ids[#ids + 1] = a.id or i end end
    return ids
  end,
  GetAuraDuration = function(unit, id)
    local a = auraByID(unit, id)
    if a and a.duration then return { _start = a.expirationTime - a.duration, _duration = a.duration } end
  end,
  GetAuraApplicationDisplayCount = function(unit, id, minCount) return M.Secret("x") end,
}
function UnitGUID(u)
  if u == "player" then return "Player-1" end
  if u == "target" and S.target then return S.target.guid or "Creature-1" end
end
-- the game's menus: M.menu holds the last one opened; M.MenuPick(text) clicks an entry
local MenuRoot
function MenuRoot(menu)
  local root = {}
  function root:CreateTitle(text) table.insert(menu.items, { kind = "title", text = text }) end
  function root:CreateDivider() table.insert(menu.items, { kind = "divider" }) end
  function root:CreateRadio(text, isSelected, setSelected, data)
    local item = { kind = "radio", text = text, isSelected = isSelected, setSelected = setSelected, data = data, initializers = {} }
    function item:AddInitializer(fn) table.insert(self.initializers, fn) end
    table.insert(menu.items, item)
    return item
  end
  function root:SetScrollMode(h) assert(type(h) == "number"); menu.scrollExtent = h end
  function root:CreateButton(text, callback, data)
    local item = { kind = "button", text = text, callback = callback, data = data, items = {} }
    table.insert(menu.items, item)
    return MenuRoot(item) -- (a submenu: its entries in item.items)
  end
  function root:CreateCheckbox(text, isSelected, setSelected, data)
    table.insert(menu.items, { kind = "checkbox", text = text, isSelected = isSelected, setSelected = setSelected, data = data })
  end
  return root
end
-- a context menu: open until a pick, a press outside it (M.Press) or another menu
local MenuObject = {}
MenuObject.__index = MenuObject
function MenuObject:IsShown() return self._shown == true end
function MenuObject:Close() self._shown = false; if M.menu == self then M.menu = nil end end
function MenuObject:GetOwnerRegion() return self.owner end
MenuUtil = { CreateContextMenu = function(owner, generator)
  if M.menu then M.menu:Close() end
  M.menu = setmetatable({ owner = owner, items = {}, _shown = true }, MenuObject)
  M.menusOpened = (M.menusOpened or 0) + 1
  generator(owner, MenuRoot(M.menu))
  return M.menu
end }
-- A mouse press: open menus close unless the frame pressed handles it (as the game's
-- GLOBAL_MOUSE_DOWN), then the click.
function M.Press(frame, button)
  button = button or "LeftButton"
  local handles = frame.HandlesGlobalMouseEvent and frame:HandlesGlobalMouseEvent(button, "GLOBAL_MOUSE_DOWN")
  if not handles and M.menu then M.menu:Close() end
  local down = frame._scripts and frame._scripts.OnMouseDown -- a click: the press first
  if down then down(frame, button) end
  if frame.Click then frame:Click(button) end
end
function M.MenuItem(text)
  for _, item in ipairs(M.menu and M.menu.items or {}) do if item.text == text then return item end end
end
-- an entry of a submenu (parent: the entry that opens it)
function M.MenuSubPick(parent, text)
  local p = assert(M.MenuItem(parent), "no menu entry " .. tostring(parent))
  for _, item in ipairs(p.items or {}) do
    if item.text == text then
      if item.kind == "radio" or item.kind == "checkbox" then item.setSelected(item.data) else item.callback(item.data) end
      if M.menu then M.menu:Close() end
      return
    end
  end
  error("no submenu entry " .. tostring(text))
end
function M.MenuPick(text)
  local item = assert(M.MenuItem(text), "no menu entry " .. tostring(text))
  if item.kind == "radio" or item.kind == "checkbox" then item.setSelected(item.data) else item.callback(item.data) end
  if M.menu then M.menu:Close() end
end
function GetComboPoints(u, t)
  if t ~= "target" then error("bad unit") end
  if not S.target or not S.target.hostile then return wrap(0) end
  return wrap(S.target.cp)
end
function InCombatLockdown() return S.inCombat end
function GetLocale() return S.locale end
function PlaySound() end
SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 1 }
function GetTime() return M.now or 0 end
function IsLoggedIn() return M.loggedIn ~= false end
-- the game's text colors
local function Color(r, g, b) return { r = r, g = g, b = b, GetRGBA = function(self) return self.r, self.g, self.b, 1 end } end
NORMAL_FONT_COLOR = NORMAL_FONT_COLOR or Color(1, .82, 0)
HIGHLIGHT_FONT_COLOR = HIGHLIGHT_FONT_COLOR or Color(1, 1, 1)
RED_FONT_COLOR = RED_FONT_COLOR or Color(1, .1, .1)
-- strsplit (the game's): the pieces of a string between a separator
function strsplit(sep, text, limit)
  local out, pos = {}, 1
  while true do
    if limit and #out == limit - 1 then out[#out + 1] = text:sub(pos) break end
    local s, e = text:find(sep, pos, true)
    if not s then out[#out + 1] = text:sub(pos) break end
    out[#out + 1] = text:sub(pos, s - 1)
    pos = e + 1
  end
  return unpack(out)
end
-- the items worn (S.inventory[slot] = item ID)
function GetInventoryItemID(unit, slot) return unit == "player" and (S.inventory or {})[slot] or nil end
function GetInventoryItemLink(unit, slot)
  local id = GetInventoryItemID(unit, slot)
  return id and ("|cffffffff|Hitem:" .. id .. "|h[item " .. id .. "]|h|r") or nil
end
-- the clock in seconds (the game's time()): the mock's own, from a fixed date
function time() return 1700000000 + math.floor(M.now or 0) end
C_Timer = { After = function(d, fn) M.timers = M.timers or {}; table.insert(M.timers, fn) end }
-- tickers: M.tickers holds those running; M.Tick() runs each once
M.tickers = {}
C_Timer.NewTicker = function(d, fn)
  local h = { fn = fn }
  function h:Cancel() for i, x in ipairs(M.tickers) do if x == self then table.remove(M.tickers, i) break end end end
  table.insert(M.tickers, h)
  return h
end
function M.Tick() for _, h in ipairs({ unpack(M.tickers) }) do h.fn(h) end end
-- items: M.ITEMS[id] = { name, icon, class, subclass, spell name, spell ID }; S.bags[id] = count;
-- S.itemCooldowns[id] = { start, duration }; S.uncachedItems[id]: data not loaded yet
M.ITEMS = {
  [13446] = { "Major Healing Potion", 134833, 0, 1, "Healing Potion", 17534 },
  [13452] = { "Elixir of the Mongoose", 134812, 0, 2, "Elixir of the Mongoose", 17538 },
  [6947] = { "Instant Poison", 132273, 0, 0, "Instant Poison", 8679 },
  [20749] = { "Brilliant Wizard Oil", 134727, 0, 6, "Brilliant Wizard Oil", 25122 },
  [12404] = { "Dense Sharpening Stone", 135252, 7, 0, "Sharpen Blade V", 16138 },
  [99001] = { "Forever Venom", 132290, 0, 0, "Forever Venom", 99002 },
}
local function itemRow(i)
  local id = type(i) == "number" and i or tonumber(tostring(i):match("item:(%d+)"))
  return id and M.ITEMS[id], id
end
C_Item = C_Item or {}
C_Item.GetItemNameByID = function(i) local r, id = itemRow(i); if r and not (S.uncachedItems or {})[id] then return r[1] end end
C_Item.GetItemIconByID = function(i) local r = itemRow(i); return r and r[2] end
C_Item.GetItemInfoInstant = function(i) local r, id = itemRow(i); if r then return id, "Consumable", "x", "", r[2], r[3], r[4] end end
C_Item.GetItemSpell = function(i) local r = itemRow(i); if r and r[5] then return r[5], r[6] end end
C_Item.GetItemCount = function(i) local _, id = itemRow(i); return (S.bags or {})[id] or 0 end
C_Item.GetItemCooldown = function(i)
  local _, id = itemRow(i); local c = (S.itemCooldowns or {})[id]
  if c then return c[1], c[2], true end
  return 0, 0, true
end
C_Item.RequestLoadItemDataByID = function(i) M.itemRequests = (M.itemRequests or 0) + 1 end
-- weapon enchantments: S.weaponEnchants[0 main hand / 1 off hand] = { { enchantID =, timeLeft = ms, charges =, enchantIconID =, enchantType = } }
C_Item = C_Item or {}
C_Item.GetWeaponEnchantInfo = function(slot)
  local list = {}
  for i, e in ipairs((S.weaponEnchants or {})[slot] or {}) do
    list[i] = { hasEnchant = true, enchantType = e.enchantType or 3, timeLeft = e.timeLeft or 0, charges = e.charges or 0,
      enchantID = e.enchantID, enchantIconID = e.enchantIconID or 0 }
  end
  return list
end
function M.RunTimer(i) local fn = table.remove(M.timers, i or 1); if fn then fn() end end
UISpecialFrames = {}
tinsert = table.insert
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
SlashCmdList = {}
M.out = print
function print(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring(select(i, ...)) end table.insert(M.log, table.concat(t, " ")) end

local KNOWN_EVENTS = {}
for _, e in ipairs({ "ACHIEVEMENT_EARNED", "ACTIONBAR_HIDEGRID", "ACTIONBAR_PAGE_CHANGED", "ACTIONBAR_SHOWGRID", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_STATE", "ACTIVE_COMBAT_CONFIG_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "ADDON_LOADED", "ADDON_RESTRICTION_STATE_CHANGED", "ARCHAEOLOGY_FIND_COMPLETE", "ARTIFACT_DIGSITE_COMPLETE", "ARTIFACT_XP_UPDATE", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_SHOW", "AURA_DATA_PROVIDER_SWITCH", "AZERITE_ITEM_EXPERIENCE_CHANGED", "BAG_CONTAINER_UPDATE", "BAG_NEW_ITEMS_UPDATED", "BAG_UPDATE", "BAG_UPDATE_COOLDOWN", "BAG_UPDATE_DELAYED", "BANKFRAME_CLOSED", "BANKFRAME_OPENED", "BATTLE_PET_CURSOR_CLEAR", "BN_FRIEND_INVITE_ADDED", "BN_FRIEND_INVITE_LIST_INITIALIZED", "BN_FRIEND_INVITE_REMOVED", "BOSS_KILL", "CANCEL_SUMMON", "CHANNEL_UI_UPDATE", "CHARACTER_POINTS_CHANGED", "CHAT_MSG_ADDON", "CHAT_MSG_BG_SYSTEM_NEUTRAL", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_CHANNEL", "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER", "CHAT_MSG_COMBAT_XP_GAIN", "CHAT_MSG_COMMUNITIES_CHANNEL", "CHAT_MSG_EMOTE", "CHAT_MSG_GUILD", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_MONSTER_EMOTE", "CHAT_MSG_OFFICER", "CHAT_MSG_OPENING", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_SAY", "CHAT_MSG_SYSTEM", "CHAT_MSG_TRADESKILLS", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_YELL", "CINEMATIC_START", "CINEMATIC_STOP", "CLOSE_TABARD_FRAME", "COMBAT_LOG_EVENT_UNFILTERED", "COMBAT_RATING_UPDATE", "COMBO_TARGET_CHANGED", "COMPANION_UPDATE", "CONFIRM_DISENCHANT_ROLL", "CONFIRM_LOOT_ROLL", "CONFIRM_SUMMON", "CONFIRM_XP_LOSS", "CRITERIA_UPDATE", "CURRENCY_DISPLAY_UPDATE", "CURRENT_SPELL_CAST_CHANGED", "CURSOR_CHANGED", "CVAR_UPDATE", "DELETE_ITEM_CONFIRM", "DIEL_CYCLE_CHANGED", "DISABLE_XP_GAIN", "DISPLAY_EVENT_TOASTS", "DISPLAY_SIZE_CHANGED", "DUEL_REQUESTED", "EDIT_MODE_LAYOUTS_UPDATED", "ENABLE_XP_GAIN", "ENCOUNTER_END", "ENCOUNTER_LOOT_RECEIVED", "ENCOUNTER_START", "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONFIGS_CHANGED", "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED", "GET_ITEM_INFO_RECEIVED", "GLOBAL_MOUSE_DOWN", "GLOBAL_MOUSE_UP", "GOSSIP_CLOSED", "GOSSIP_SHOW", "GROUP_INVITE_CONFIRMATION", "GROUP_LEFT", "GROUP_ROSTER_UPDATE", "GUILD_MOTD", "GUILD_REGISTRAR_CLOSED", "GUILD_REGISTRAR_SHOW", "GUILD_ROSTER_UPDATE", "HEIRLOOMS_UPDATED", "HONOR_LEVEL_UPDATE", "HONOR_XP_UPDATE", "INPUT_DEVICE_INTERFACE_TRANSITION", "INSPECT_READY", "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "INVENTORY_SEARCH_UPDATE", "ITEM_DATA_LOAD_RESULT", "ITEM_LOCKED", "ITEM_LOCK_CHANGED", "ITEM_TEXT_READY", "LEARNED_SPELL_IN_SKILL_LINE", "LFG_LIST_AVAILABILITY_UPDATE", "LFG_LIST_SEARCH_FAILED", "LFG_LIST_SEARCH_RESULTS_RECEIVED", "LFG_LIST_SEARCH_RESULT_UPDATED", "LFG_PROPOSAL_FAILED", "LFG_PROPOSAL_SHOW", "LFG_PROPOSAL_SUCCEEDED", "LOADING_SCREEN_DISABLED", "LOOT_BIND_CONFIRM", "LOOT_CLOSED", "LOOT_OPENED", "LOOT_READY", "LOOT_SLOT_CHANGED", "LOOT_SLOT_CLEARED", "MAIL_CLOSED", "MAIL_FAILED", "MAIL_INBOX_UPDATE", "MAIL_LOCK_SEND_ITEMS", "MAIL_SEND_SUCCESS", "MAIL_SHOW", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "MAJOR_FACTION_UNLOCKED", "MERCHANT_CLOSED", "MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL", "MERCHANT_SHOW", "MINIMAP_UPDATE_TRACKING", "MINIMAP_UPDATE_ZOOM", "MIRROR_TIMER_START", "MIRROR_TIMER_STOP", "MODIFIER_STATE_CHANGED", "MOUNT_JOURNAL_SEARCH_UPDATED", "MOUNT_JOURNAL_USABILITY_CHANGED", "NAME_PLATE_CREATED", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "NEW_HOUSING_ITEM_ACQUIRED", "NEW_MOUNT_ADDED", "NEW_PET_ADDED", "NEW_TOY_ADDED", "NEW_WARBAND_SCENE_ADDED", "OPEN_TABARD_FRAME", "PARTY_INVITE_REQUEST", "PARTY_KILL", "PARTY_LEADER_CHANGED", "PARTY_MEMBER_DISABLE", "PARTY_MEMBER_ENABLE", "PET_BAR_UPDATE", "PET_BAR_UPDATE_USABLE", "PET_BATTLE_CLOSE", "PET_BATTLE_LEVEL_CHANGED", "PET_BATTLE_OPENING_START", "PET_BATTLE_OVER", "PET_DISMISS_START", "PET_JOURNAL_LIST_UPDATE", "PET_JOURNAL_PETS_HEALED", "PET_JOURNAL_PET_DELETED", "PET_STABLE_CLOSED", "PET_STABLE_SHOW", "PET_STATS_UPDATE", "PET_UI_UPDATE", "PING_SYSTEM_ERROR", "PLAYERBANKSLOTS_CHANGED", "PLAYER_ALIVE", "PLAYER_AVG_ITEM_LEVEL_UPDATE", "PLAYER_CONTROL_GAINED", "PLAYER_CONTROL_LOST", "PLAYER_DEAD", "PLAYER_ENTERING_BATTLEGROUND", "PLAYER_ENTERING_WORLD", "PLAYER_ENTER_COMBAT", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_FARSIGHT_FOCUS_CHANGED", "PLAYER_FLAGS_CHANGED", "PLAYER_FOCUS_CHANGED", "PLAYER_GAINS_VEHICLE_DATA", "PLAYER_GUILD_UPDATE", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_IN_COMBAT_CHANGED", "PLAYER_LEAVE_COMBAT", "PLAYER_LEVEL_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_LOGIN", "PLAYER_LOGOUT", "PLAYER_LOSES_VEHICLE_DATA", "PLAYER_MAX_LEVEL_UPDATE", "PLAYER_MONEY", "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_PVP_RANK_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ROLES_ASSIGNED", "PLAYER_SOFT_ENEMY_CHANGED", "PLAYER_SOFT_FRIEND_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_STARTED_MOVING", "PLAYER_SWING", "PLAYER_TALENT_UPDATE", "PLAYER_TARGET_CHANGED", "PLAYER_UNGHOST", "PLAYER_UPDATE_RESTING", "PLAYER_XP_UPDATE", "PLAY_MOVIE", "PORTRAITS_UPDATED", "PVP_TIMER_UPDATE", "QUEST_ACCEPTED", "QUEST_ACCEPT_CONFIRM", "QUEST_AUTOCOMPLETE", "QUEST_COMPLETE", "QUEST_DATA_LOAD_RESULT", "QUEST_DETAIL", "QUEST_FINISHED", "QUEST_GREETING", "QUEST_LOG_UPDATE", "QUEST_PROGRESS", "QUEST_REMOVED", "QUEST_WATCH_LIST_CHANGED", "RAID_TARGET_UPDATE", "RECENT_ALLIES_CACHE_UPDATE", "RECENT_ALLIES_DATA_READY", "RECENT_ALLY_DATA_UPDATED", "REPORT_PLAYER_RESULT", "RESURRECT_REQUEST", "SHIPMENT_CRAFTER_CLOSED", "SHIPMENT_CRAFTER_OPENED", "SKILL_LINES_CHANGED", "SOCIAL_QUEUE_UPDATE", "SOCIAL_UI_SYSTEM_STATUS_UPDATED", "SOUNDKIT_FINISHED", "SPELLS_CHANGED", "SPELL_DATA_LOAD_RESULT", "SPELL_POWER_CHANGED", "SPELL_UPDATE_CHARGES", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_ICON", "SPELL_UPDATE_USABLE", "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "SUPER_TRACKING_CHANGED", "TAXIMAP_CLOSED", "TAXIMAP_OPENED", "TIME_PLAYED_MSG", "TOOLTIP_DATA_UPDATE", "TOYS_UPDATED", "TRACKED_HOUSE_CHANGED", "TRACKED_RECIPE_UPDATE", "TRADE_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "TRADE_SKILL_DETAILS_UPDATE", "TRADE_SKILL_ITEM_CRAFTED_RESULT", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_SHOW", "TRAINER_CLOSED", "TRAINER_DESCRIPTION_UPDATE", "TRAINER_SERVICE_INFO_NAME_UPDATE", "TRAINER_SHOW", "TRAINER_UPDATE", "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRANSMOGRIFY_CLOSE", "TRANSMOGRIFY_OPEN", "TRANSMOG_COLLECTION_SOURCE_ADDED", "TRANSMOG_COLLECTION_SOURCE_REMOVED", "TRANSMOG_COLLECTION_UPDATED", "UI_ERROR_MESSAGE", "UI_SCALE_CHANGED", "UNIT_ATTACK", "UNIT_ATTACK_POWER", "UNIT_ATTACK_SPEED", "UNIT_AURA", "UNIT_CLASSIFICATION_CHANGED", "UNIT_COMBAT", "UNIT_CONNECTION", "UNIT_DAMAGE", "UNIT_DIED", "UNIT_DISPLAYPOWER", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "UNIT_EXITING_VEHICLE", "UNIT_FACTION", "UNIT_FLAGS", "UNIT_HAPPINESS", "UNIT_HEALTH", "UNIT_INVENTORY_CHANGED", "UNIT_LEVEL", "UNIT_MAXHEALTH", "UNIT_MAXPOWER", "UNIT_NAME_UPDATE", "UNIT_PET", "UNIT_PET_EXPERIENCE", "UNIT_PET_TRAINING_POINTS", "UNIT_PORTRAIT_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_POWER_UPDATE", "UNIT_QUEST_LOG_CHANGED", "UNIT_RANGEDDAMAGE", "UNIT_RANGED_ATTACK_POWER", "UNIT_RESISTANCES", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_FAILED_QUIET", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELL_HASTE", "UNIT_STATS", "UNIT_TARGET", "UNIT_TARGETABLE_CHANGED", "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "UPDATE_ACTIVE_BATTLEFIELD", "UPDATE_BINDINGS", "UPDATE_BONUS_ACTIONBAR", "UPDATE_CHAT_COLOR", "UPDATE_CHAT_WINDOWS", "UPDATE_EXHAUSTION", "UPDATE_EXTRA_ACTIONBAR", "UPDATE_FACTION", "UPDATE_FLOATING_CHAT_WINDOWS", "UPDATE_INVENTORY_ALERTS", "UPDATE_INVENTORY_DURABILITY", "UPDATE_MOUSEOVER_UNIT", "UPDATE_MULTI_CAST_ACTIONBAR", "UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_PENDING_MAIL", "UPDATE_POSSESS_BAR", "UPDATE_SHAPESHIFT_COOLDOWN", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS", "UPDATE_SHAPESHIFT_USABLE", "UPDATE_TRADESKILL_CAST_STOPPED", "UPDATE_UI_WIDGET", "UPDATE_VEHICLE_ACTIONBAR", "VOICE_CHAT_CHANNEL_ACTIVATED", "VOICE_CHAT_CHANNEL_DEACTIVATED", "VOICE_CHAT_OUTPUT_DEVICES_UPDATED", "WARBAND_SCENE_FAVORITES_UPDATED", "WEAPON_ENCHANT_CHANGED", "WEAPON_SLOT_CHANGED", "WHO_LIST_UPDATE", "WORLD_CURSOR_TOOLTIP_UPDATE", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do KNOWN_EVENTS[e] = true end -- (every event of the game the addon names: Blizzard_APIDocumentationGenerated)
for _, e in ipairs({ "ADDON_LOADED", "CVAR_UPDATE", "EDIT_MODE_LAYOUTS_UPDATED", "GLOBAL_MOUSE_UP", "MAIL_SHOW", "MAIL_CLOSED", "PLAYER_FOCUS_CHANGED", "UNIT_COMBAT", "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "MAIL_SEND_SUCCESS", "MAIL_FAILED", "PLAYER_LEVEL_UP", "MERCHANT_CLOSED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED",
  "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "UNIT_POWER_FREQUENT", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_HEALTH",
  "UNIT_FLAGS", "UNIT_DIED", "GLOBAL_MOUSE_DOWN", "COMBAT_LOG_MESSAGE", "UNIT_DISPLAYPOWER", "UPDATE_SHAPESHIFT_FORM", "PLAYER_LOGOUT",
  "PLAYER_REGEN_ENABLED", "UNIT_AURA", "CURRENT_SPELL_CAST_CHANGED", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
  "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_DELAYED",
  "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "ADDON_RESTRICTION_STATE_CHANGED", "GROUP_ROSTER_UPDATE",
  "ZONE_CHANGED_NEW_AREA", "CURSOR_CHANGED", "CHAT_MSG_SYSTEM", "LEARNED_SPELL_IN_SKILL_LINE", "SPELLS_CHANGED",
  "CHAT_MSG_EMOTE", "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE",
  "CHARACTER_POINTS_CHANGED", "TRAIT_CONFIG_UPDATED", "UPDATE_SHAPESHIFT_FORMS", "UNIT_INVENTORY_CHANGED",
  "WEAPON_ENCHANT_CHANGED", "PLAYER_SWING", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "GET_ITEM_INFO_RECEIVED",
  "MODIFIER_STATE_CHANGED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UPDATE_BINDINGS",
  "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "QUEST_LOG_UPDATE",
  "PLAYER_EQUIPMENT_CHANGED", "UNIT_TARGET", "CHAT_MSG_CHANNEL", "CHAT_MSG_ADDON", "CHAT_MSG_CHANNEL_NOTICE",
  "CHAT_MSG_CHANNEL_NOTICE_USER", "ENCOUNTER_START", "ENCOUNTER_END", "INSTANCE_ENCOUNTER_ENGAGE_UNIT",
  "PLAYER_STARTED_MOVING", "MAIL_INBOX_UPDATE", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED",
  "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_CLOSE", "RAID_TARGET_UPDATE", "UNIT_SPELLCAST_SENT", "CRAFT_UPDATE", "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONFIGS_CHANGED", "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED", "ITEM_DATA_LOAD_RESULT", "PET_DISMISS_START", "PLAYER_PVP_RANK_CHANGED", "SKILL_LINES_CHANGED", "SPELL_DATA_LOAD_RESULT", "TRAINER_SHOW", "TRAINER_UPDATE", "UPDATE_FACTION", "PLAYER_MONEY", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", "GROUP_JOINED", "REPLICATE_ITEM_LIST_UPDATE", "CLUB_STREAMS_LOADED", "CLUB_ADDED", "INITIAL_CLUBS_LOADED", "REPLACE_ENCHANT", "TRADE_REPLACE_ENCHANT", "REPLACE_TRADESKILL_ENCHANT" }) do KNOWN_EVENTS[e] = true end

-- widgets -------------------------------------------------------------------
local Base = {}
local classes = {}
M.classes = classes
local function class(name, parent)
  local c = setmetatable({}, { __index = parent })
  c.__name = name
  classes[name] = c
  return c
end
local function instMT(c)
  return {
    __index = function(t, k)
      local v = c[k]
      if v == nil then
        return nil -- like the client: a missing method is nil (calling it still errors)
      end
      return v
    end,
  }
end

local Region = class("Region", Base)
function Region:SetPoint(point, rel, relPoint, x, y)
  Guard(self)
  if type(rel) == "number" then rel, relPoint, x, y = nil, nil, rel, relPoint end
  if type(rel) == "string" then rel = _G[rel] end
  self._points = self._points or {}
  -- replace same point
  for i = #self._points, 1, -1 do if self._points[i][1] == point then table.remove(self._points, i) end end
  table.insert(self._points, { point, rel or self._parent, relPoint or point, x or 0, y or 0 })
end
function Region:ClearAllPoints() Guard(self); self._points = {} end
function Region:GetPoint(i)
  local p = self._points and self._points[i or 1]
  if p then return p[1], p[2], p[3], p[4], p[5] end
end
function Region:SetAllPoints(rel)
  rel = rel or self._parent
  self._points = { { "TOPLEFT", rel, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0 } }
end
function Region:SetSize(w, h) self._w, self._h = w, h end
function Region:SetWidth(w) self._w = w end
function Region:SetHeight(h) self._h = h end
function Region:GetWidth() return M.Rect(self) and select(3, M.Rect(self)) or (self._w or 0) end
function Region:GetHeight() local r = { M.Rect(self) } return r[4] or (self._h or 0) end
function Region:GetSize() return self:GetWidth(), self:GetHeight() end
function Region:Show() self._shown = true end
function Region:Hide() self._shown = false; if self._scripts and self._scripts.OnHide then self._scripts.OnHide(self) end end
function Region:SetShown(v) if v then self:Show() else self:Hide() end end
function Region:IsShown() return self._shown ~= false end
function Region:SetAlpha(a) self._alpha = a end
function Region:GetAlpha() return self._alpha or 1 end
function Region:GetParent() return self._parent end
function Region:SetParent(p) self._parent = p; if self._kind ~= "Texture" and self._kind ~= "FontString" then self._level = ((p and p._level) or 1) + 1 end end
function Region:IsVisible() return self:IsShown() and (not self._parent or self._parent:IsVisible()) end
function Region:IsMouseOver() return M.MouseOver(self) end
function Region:GetLeft() local l = M.Rect(self) return l end
function Region:GetRect() return M.Rect(self) end
function Region:GetRight() local l, b, w = M.Rect(self) return l and l + w end
function Region:GetBottom() local _, b = M.Rect(self) return b end
function Region:GetTop() local _, b, _, h = M.Rect(self) return b and b + h end
function Region:GetEffectiveScale() if self._kind == "Texture" or self._kind == "FontString" then return self._parent:GetEffectiveScale() end return 1 end

local Texture = class("Texture", Region)
function Texture:SetColorTexture(r, g, b, a) self._color = { r, g, b, a or 1 }; self._file = nil; self._vc = nil end
function Texture:SetTexture(f) self._file = f; self._color = nil; self._vc = nil; return true end
function Texture:SetHorizTile(on) self._htile = on end
function Texture:SetVertTile(on) self._vtile = on end
function Texture:SetTexCoord(...) Guard(self); self._tc = { ... } end
function Texture:SetBlendMode(m) self._blend = m end
function Texture:SetDrawLayer(layer, sub) self._layer = layer; self._sublayer = sub end
function Texture:GetDrawLayer() return self._layer, self._sublayer or 0 end
function Texture:SetGradient(orientation, a, b) self._gradient = { orientation, a, b } end
function Texture:SetAtlas(a) self._atlas = a end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end
function Texture:SetVertexColor(r, g, b, a) self._vc = { r, g, b, a or 1 } end
function Texture:SetDesaturated(v) self._desat = v and true or false end
function Texture:GetTexture() return self._file end
function Texture:AddMaskTexture(m) assert(m._mask, "not a mask"); self._masks = self._masks or {}; table.insert(self._masks, m) end

local FontString = class("FontString", Region)
function FontString:SetFont(path, size, flags)
  Guard(self)
  if type(path) ~= "string" or type(size) ~= "number" then error("bad SetFont args") end
  if M.badFonts and M.badFonts[path] then return false end
  self._font = { path, size, flags }; return true
end
function FontString:GetFont() if self._font then return unpack(self._font) end end
-- font objects an addon makes (CreateFont): a font file and size, for SetFontObject
local MadeFont = {}
MadeFont.__index = MadeFont
function MadeFont:SetFont(path, size, flags)
  if type(path) ~= "string" or type(size) ~= "number" then error("bad SetFont args") end
  if M.badFonts and M.badFonts[path] then return false end
  self._font = { path, size, flags }; return true
end
function MadeFont:GetFont() if self._font then return unpack(self._font) end end
function CreateFont(name)
  assert(type(name) == "string" and _G[name] == nil, "CreateFont needs a new global name")
  local f = setmetatable({ _name = name }, MadeFont)
  _G[name] = f
  M.madeFonts = M.madeFonts or {}
  M.madeFonts[name] = f
  return f
end
local FONT_OBJECTS = { GameFontNormalLarge = 16, GameFontNormal = 12, GameFontHighlight = 12, GameFontNormalSmall = 10,
  GameFontHighlightSmall = 10, GameFontDisableSmall = 10, ChatFontNormal = 14, GameFontNormalOutline = 12, GameFontHighlightOutline = 12,
  GameFontHighlightHuge = 20 }
function FontString:SetFontObject(o)
  if type(o) == "table" and getmetatable(o) == MadeFont then
    self._font = { o._font and o._font[1] or "OBJ:" .. o._name, o._font and o._font[2] or 10, "" }
    self._fontObject = o._name
    return
  end
  if type(o) == "table" then o = o._name end
  self._font = { "OBJ:" .. tostring(o), FONT_OBJECTS[o] or 10, "" }
  self._fontObject = o
end
FONT_OBJECTS.NumberFontNormal = 14
for name in pairs(FONT_OBJECTS) do _G[name] = { _name = name, GetFont = function() return "Fonts\\ARIALN.TTF", FONT_OBJECTS[name], "OUTLINE" end } end
function FontString:SetText(t)
  if not self._font then error("FontString:SetText(): Font not set") end
  if t ~= nil and type(t) ~= "string" and type(t) ~= "number" and not issecretvalue(t) then error("bad SetText arg " .. type(t)) end
  self._text = t
end
function FontString:GetText() return self._text end
function FontString:SetTextColor(r, g, b, a) self._tc = { r, g, b, a or 1 } end
function FontString:GetTextColor() local c = self._tc or { 1, 1, 1, 1 } return c[1], c[2], c[3], c[4] end
function FontString:GetFontObject() return self._fontObject and _G[self._fontObject] or nil end
function FontString:SetJustifyH(j) self._jh = j end
function FontString:SetWordWrap() end
function FontString:SetJustifyV(j) self._jv = j end
function FontString:SetSpacing(n) self._spacing = n end
-- what the game draws of a text: colour codes and inline textures take no room
local function plainText(t)
  return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "  "))
end
M.PlainText = plainText
local function textWidth(fs, t)
  local size = fs._font and fs._font[2] or 10
  if MEASURE then return MEASURE(fs._font and fs._font[1] or "OBJ", size, t) end
  return #t * size * 0.5
end
-- wrapped text: lines of the set width, word by word as the game wraps them (at most its
-- maximum number of lines)
function FontString:GetStringHeight()
  local size = self._font and self._font[2] or 10
  local w = self._w
  local lines = 0
  for para in (plainText(reveal(self._text)) .. "\n"):gmatch("(.-)\n") do
    if w and w > 0 then
      local n, cur = 1, ""
      for word in para:gmatch("%S+") do
        local try = cur == "" and word or cur .. " " .. word
        if cur ~= "" and textWidth(self, try) > w then n = n + 1; cur = word else cur = try end
      end
      lines = lines + n
    else
      lines = lines + 1
    end
  end
  if self._maxLines and self._maxLines > 0 then lines = math.min(lines, self._maxLines) end
  return lines * (size + (self._spacing or 0))
end
function FontString:SetMaxLines(n) self._maxLines = n end
function FontString:SetFormattedText(fmt, ...) -- (a secret among its values: a secret text, as the game makes it)
  local args, secret = { ... }, false
  for i = 1, select("#", ...) do if issecretvalue(args[i]) then secret = true; args[i] = reveal(args[i]) end end
  local text = string.format(fmt, unpack(args, 1, select("#", ...)))
  self:SetText(secret and M.Secret(text) or text)
end
function FontString:GetStringWidth()
  return textWidth(self, plainText(reveal(self._text)))
end
FontString.GetUnboundedStringWidth = FontString.GetStringWidth
function FontString:IsTruncated() return false end
function FontString:SetShadowColor(r, g, b, a) self._shadow = { r, g, b, a } end
function FontString:SetShadowOffset(x, y) self._shadowOffset = { x, y } end
function Texture:SetRotation(r) self._rotation = r end

local Frame = class("Frame", Region)
function Frame:SetScript(name, fn)
  self._scripts = self._scripts or {}; self._scripts[name] = fn
  -- (as the game: a shown child's OnShow runs too as its parent shows)
  local p = rawget(self, "_parent")
  if name == "OnShow" and fn and p and not (p._showKids and p._showKids[self]) then
    p._showKids = p._showKids or {}; p._showKids[self] = true
  end
end
function Frame:IsProtected() return self._protected == true, false end
function Frame:GetScript(name) return self._scripts and self._scripts[name] end
function Frame:HookScript(name, fn)
  local old = self:GetScript(name)
  self:SetScript(name, old and function(...) old(...); fn(...) end or fn)
end
local function KidsShow(self)
  for kid in pairs(self._showKids or {}) do
    if kid._parent == self and kid:IsShown() then
      if kid._scripts and kid._scripts.OnShow then kid._scripts.OnShow(kid) end
      KidsShow(kid)
    end
  end
end
function Frame:Show()
  local was = self:IsShown(); self._shown = true
  if not was and self._scripts and self._scripts.OnShow then self._scripts.OnShow(self) end
  if not was and M.showKids then KidsShow(self) end
end
function Frame:CreateTexture(name, layer)
  local t = setmetatable({ _parent = self, _layer = layer or "ARTWORK", _kind = "Texture" }, instMT(Texture))
  table.insert(M.regions, t); return t
end
function Frame:CreateFontString(name, layer, template)
  local fs = setmetatable({ _parent = self, _layer = layer or "ARTWORK", _kind = "FontString" }, instMT(FontString))
  if template then fs:SetFontObject(template) end
  table.insert(M.regions, fs); return fs
end
function Frame:SetClampedToScreen(v) self._clamped = v end
function Frame:SetClampRectInsets(l, r, t, b) self._clampInsets = { l, r, t, b } end
function Frame:CreateMaskTexture(name, layer)
  local t = setmetatable({ _parent = self, _layer = layer or "ARTWORK", _kind = "Texture", _mask = true }, instMT(Texture))
  table.insert(M.regions, t); return t
end
function Frame:SetClipsChildren(v) self._clips = v end
function Frame:GetName() return self._name end
function Frame:SetMovable(v) self._movable = v end
function Frame:GetFrameStrata()
  local f = self
  while f do if f._strata then return f._strata end f = f._parent end
  return "MEDIUM"
end
function Frame:EnableMouse(v) self._mouse = v end
function Frame:EnableMouseWheel(v) self._wheel = v end
function Frame:RegisterForDrag() end
function Frame:SetDontSavePosition() end
function Frame:SetFrameLevel(l) self._level = l end
function Frame:GetFrameLevel() return self._level or 1 end
function Frame:SetFrameStrata(s) self._strata = s end
function Frame:SetToplevel() end
function Frame:EnableKeyboard(on) self._keyboard = on end
function Frame:SetPropagateKeyboardInput(on)
  if S.inCombat then error("SetPropagateKeyboardInput in combat") end
  self._propagate = on
end
-- a key pressed while a frame takes the keyboard: OnKeyDown, then OnChar for a character
function M.Key(frame, key, char)
  if frame._scripts.OnKeyDown then frame._scripts.OnKeyDown(frame, key) end
  if char and frame._scripts.OnChar then frame._scripts.OnChar(frame, char) end
end
function Frame:Raise() self._raised = (self._raised or 0) + 1 end
function Frame:SetHitRectInsets(l, r, t, b) self._hit = { l, r, t, b } end
function Frame:SetID(id) self._id = id end
function Frame:GetID() return self._id or 0 end
function Frame:SetScale(s) assert(type(s) == "number" and s > 0, "bad scale"); self._scale = s end
function Frame:GetScale() return self._scale or 1 end
function Frame:GetEffectiveScale() local p = self._parent; return (self._scale or 1) * (p and p:GetEffectiveScale() or 1) end
function Frame:GetCenter()
  local l, b, w, h = M.Rect(self)
  if not l then return nil end
  return l + w / 2, b + h / 2
end
function Frame:StartMoving() assert(self._movable, "not movable"); self._moving = true end
function Frame:StopMovingOrSizing() self._moving = false end
function Frame:RegisterEvent(e)
  if not KNOWN_EVENTS[e] then error("Attempt to register unknown event \"" .. e .. "\"") end
  self._events = self._events or {}; self._events[e] = true; M.eventFrames[self] = true
end
function Frame:RegisterUnitEvent(e, u, u2) self:RegisterEvent(e); self._unitFilter = self._unitFilter or {}; self._unitFilter[e] = { u, u2 } end
function Frame:UnregisterEvent(e) if self._events then self._events[e] = nil end end
function Frame:UnregisterAllEvents() self._events = {}; self._unitFilter = nil end
function Frame:IsVisible()
  local f = self
  while f do if not f:IsShown() then return false end f = f._parent end
  return true
end

local Button = class("Button", Frame)
function Button:Click(button)
  if self._disabled then return end
  if self._kind == "CheckButton" then self._checked = not self._checked end
  local scripts = self._scripts
  if scripts and scripts.PreClick then scripts.PreClick(self, button or "LeftButton") end
  if scripts and scripts.OnClick then scripts.OnClick(self, button or "LeftButton") end
  if scripts and scripts.PostClick then scripts.PostClick(self, button or "LeftButton") end
end
function Button:RegisterForClicks(...) self._clicks = { ... } end
function Button:SetDisabledTexture(t) self._disabledTexture = t end
function Button:Disable() self._disabled = true end
function Button:Enable() self._disabled = false end
function Button:IsEnabled() return not self._disabled end
function Button:SetText(t)
  if not self._textFS then self._textFS = self:CreateFontString(nil, "OVERLAY", self._normalFont or "GameFontNormal"); self._textFS:SetPoint("CENTER") end
  self._textFS:SetText(t)
end
function Button:GetText() return self._textFS and self._textFS._text end
function Button:GetFontString() return self._textFS end
function Button:SetNormalFontObject(o)
  if type(o) == "table" then o = o._name end
  self._normalFont = o
  if self._textFS then self._textFS:SetFontObject(o) end
end
function Button:SetHighlightFontObject() end
function Button:SetDisabledFontObject(o) self._disabledFont = o end
function Button:SetEnabled(v) self._disabled = not v end
function Button:SetNormalTexture(t) self._normalTex = t end
function Button:SetPushedTexture(t) self._pushedTex = t end
function Button:GetNormalTexture()
  if not self._ntex then self._ntex = self:CreateTexture(nil, "ARTWORK"); self._ntex:SetAllPoints() end
  return self._ntex
end
local function StateTexture(self, key, layer)
  if not self[key] then self[key] = self:CreateTexture(nil, layer); self[key]:SetAllPoints() end
  return self[key]
end
function Button:GetPushedTexture() return StateTexture(self, "_ptex", "ARTWORK") end
function Button:GetDisabledTexture() return StateTexture(self, "_dtex", "ARTWORK") end
function Button:GetHighlightTexture() return StateTexture(self, "_htex", "HIGHLIGHT") end
function Button:SetHighlightTexture(t) self._highlightTex = t end
function Button:SetButtonState(state, locked) self._state = state end
function Button:LockHighlight() self._locked = true end
function Button:UnlockHighlight() self._locked = false end
local CheckButton = class("CheckButton", Button)
function CheckButton:SetChecked(v) self._checked = v and true or false end
function CheckButton:GetChecked() return self._checked or false end
function CheckButton:SetCheckedTexture(t) self._checkedTex = t end
function CheckButton:GetCheckedTexture() return StateTexture(self, "_ctex", "OVERLAY") end

local StatusBar = class("StatusBar", Frame)
function StatusBar:SetStatusBarTexture(f)
  self._bartex = f
  if not self._fill then
    self._fill = setmetatable({ _parent = self, _layer = "ARTWORK", _kind = "Texture", _fillOf = self }, instMT(Texture))
  end
end
function StatusBar:GetStatusBarTexture() return self._fill end
function StatusBar:SetMinMaxValues(a, b) self._min, self._max = a, b end
function StatusBar:GetMinMaxValues() return self._min, self._max end
function StatusBar:SetValue(v, interp)
  if v == nil then error("SetValue(nil)") end
  if type(v) ~= "number" and not issecretvalue(v) then error("bad SetValue") end
  self._value = v
end
function StatusBar:GetValue() return self._value end
function StatusBar:SetStatusBarColor(r, g, b, a) self._barcolor = { r, g, b, a or 1 } end

local Slider = class("Slider", Frame)
function Slider:SetOrientation() end
function Slider:SetMinMaxValues(a, b) self._min, self._max = a, b end
function Slider:GetMinMaxValues() return self._min or 0, self._max or 0 end
function Slider:SetValueStep(s) self._step = s end
function Slider:SetObeyStepOnDrag() end
function Slider:SetThumbTexture(f)
  self._thumb = self._thumb or self:CreateTexture(nil, "OVERLAY")
  self._thumb:SetTexture(f)
end
function Slider:GetThumbTexture() return self._thumb end
function Slider:SetValue(v)
  v = math.max(self._min, math.min(self._max, v))
  local old = self._value; self._value = v
  if old ~= v and self._scripts and self._scripts.OnValueChanged then self._scripts.OnValueChanged(self, v, false) end
end
function Slider:GetValue() return self._value or self._min end

local EditBox = class("EditBox", Frame)
function EditBox:SetAutoFocus() end
function EditBox:SetNumeric() end
function EditBox:SetMaxLetters(n) self._maxLetters = n end
function EditBox:GetMaxLetters() return self._maxLetters or 0 end
function EditBox:SetFontObject(o) self._fontObject = o end
function EditBox:GetFontObject() return self._fontObject end
function EditBox:SetJustifyH() end
function EditBox:SetTextInsets() end
function EditBox:SetText(t) self._text = tostring(t) end
function EditBox:SetMultiLine(v) self._multi = v end
function EditBox:HighlightText() self._highlighted = true end
function EditBox:SetCursorPosition(p) self._cursor = p end
-- typing (or pasting) into the box: OnTextChanged with userInput
function M.Type(e, text)
  e._text = text
  if e._scripts and e._scripts.OnTextChanged then e._scripts.OnTextChanged(e, true) end
end
function EditBox:GetText() return self._text or "" end
function EditBox:ClearFocus()
  local had = self._focus
  self._focus = false
  if had and self._scripts and self._scripts.OnEditFocusLost then self._scripts.OnEditFocusLost(self) end
end
function EditBox:HasFocus() return self._focus or false end
function EditBox:SetFocus() self._focus = true; M.focus = self end
function GetCurrentKeyBoardFocus() if M.focus and M.focus._focus then return M.focus end end

local ScrollFrame = class("ScrollFrame", Frame)
function ScrollFrame:SetScrollChild(c) self._child = c; c._scrollParent = self; c._points = { { "TOPLEFT", self, "TOPLEFT", 0, 0 } } end
function ScrollFrame:GetScrollChild() return self._child end
function ScrollFrame:SetVerticalScroll(v) self._vs = v end -- (what is anchored to the child moves: absRect)
function ScrollFrame:GetVerticalScroll() return self._vs or 0 end
function ScrollFrame:GetVerticalScrollRange()
  if not self._child then return 0 end
  M.ResetLayout()
  return math.max(0, self._child:GetHeight() - self:GetHeight())
end
function ScrollFrame:UpdateScrollChildRect() end

local ColorSelect = class("ColorSelect", Frame)
local AuraContainer = class("AuraContainer", Frame)

local Cooldown = class("Cooldown", Frame)
function Cooldown:SetCooldown(start, duration, modRate)
  if issecretvalue(start) or issecretvalue(duration) then error("SetCooldown: secret argument from tainted code") end
  if duration > 0 then self._cd = { start, duration } else self._cd = nil end
end
function Cooldown:SetCooldownFromDurationObject(d, clearIfZero)
  if d._duration > 0 then self._cd = { d._start, d._duration } elseif clearIfZero ~= false then self._cd = nil end
end
function Cooldown:Clear() self._cd = nil end
function Cooldown:SetHideCountdownNumbers(v) Guard(self); self._hideNumbers = v end
function Cooldown:SetCountdownAbbrevThreshold(s) self._abbrev = s end
function Cooldown:SetDrawBling(v) self._bling = v end
function Cooldown:SetDrawEdge(v) self._edge = v end
function Cooldown:SetDrawSwipe(v) self._swipe = v end
function Cooldown:SetSwipeColor(...) self._swipeColor = { ... } end
function Cooldown:SetReverse(v) Guard(self); self._reverse = v end
function Cooldown:GetCountdownFontString()
  if not self._countdown then self._countdown = self:CreateFontString(nil, "OVERLAY"); self._countdown:SetPoint("CENTER") end
  return self._countdown
end

function CreateFrame(kind, name, parent, template)
  local c = classes[kind]
  if not c then error("unknown frame type " .. tostring(kind)) end
  if template and template ~= "BackdropTemplate" and not M.TEMPLATES[template] then error("unknown template: " .. template) end
  local f = setmetatable({ _parent = parent, _kind = kind, _name = name }, instMT(c))
  if parent then f._level = (parent._level or 1) + 1 end
  if template and M.TEMPLATES[template] then
    f._template = template
    M.TEMPLATES[template](f)
  end
  if template == "BackdropTemplate" then
    f.SetBackdrop = function(self, info) self._backdrop = info; self._bdColor = nil; self._bdBorder = nil end
    f.SetBackdropColor = function(self, ...) assert(self._backdrop, "SetBackdropColor without backdrop"); self._bdColor = { ... } end
    f.SetBackdropBorderColor = function(self, ...) assert(self._backdrop, "SetBackdropBorderColor without backdrop"); self._bdBorder = { ... } end
  end
  if parent then f._level = (parent._level or 1) + 1 end
  -- secure templates make the frame protected, and its parents with it (as the game)
  if template and template:find("^Secure") then
    f._secure = true
    local p = parent
    while p do p._protected = true; p = p._parent end
  end
  table.insert(M.frames, f)
  if name then _G[name] = f end
  return f
end

-- Blizzard templates used by the Classic theme (structure only)
M.TEMPLATES = {}

-- The game's aura containers (Blizzard_AuraContainer): an addon gives each aura slot a filter
-- and spell IDs; the game itself shows the matching aura in the slot's button, in and out of
-- combat. Spell IDs match only buffs on assistable units and debuffs on enemies. Setting them
-- up while auras are secret is counted in M.secureCallsWhileSecret (it must not happen).
C_Secrets = { ShouldAurasBeSecret = function() return S.inCombat == true or S.secretAuras == true end }
M.containers = {}
local function SecureCall(c, what)
  if C_Secrets.ShouldAurasBeSecret() then M.secureCallsWhileSecret = (M.secureCallsWhileSecret or 0) + 1; M.lastSecureCall = what end
end
M.TEMPLATES.CustomAuraContainerTemplate = function(c)
  assert(c._kind == "AuraContainer", "CustomAuraContainerTemplate needs an AuraContainer")
  c._slots = {}
  c._unit = "none"
  table.insert(M.containers, c)
  function c:SetUnit(u) assert(type(u) == "string"); self._unit = u end
  function c:SetEditModePreviewEnabled(v) self._editPreview = v end
  function c:UpdateAllAuras() self._updates = (self._updates or 0) + 1 end
  function c:AddAuraSlot(key, filter, options)
    SecureCall(self, "AddAuraSlot")
    assert(not self._slots[key], "aura slot already exists")
    local b = CreateFrame("Button", nil, self)
    b._auraButton = true
    function b:SetIcon(t) assert(t._parent == self or (t._parent and t._parent._parent == self), "icon not a child"); self._icon = t end
    function b:SetDurationCooldown(cd) assert(cd._parent == self, "cooldown not a child"); self._cd = cd end
    function b:SetApplicationCount(fs) self._count = fs end
    function b:SetHideTooltipInCombat() end
    b:Hide()
    local slot = { key = key, filter = filter, ids = (options.candidateFilters or {}).includeSpellIDs, enabled = true, button = b }
    self._slots[key] = slot
    if options.initializeFrame then options.initializeFrame(b) end
    b._restricted = true
    return b
  end
  function c:SetAuraSlotCandidateFilters(key, filters)
    SecureCall(self, "SetAuraSlotCandidateFilters")
    self._slots[key].ids = filters.includeSpellIDs
  end
  function c:SetAuraSlotEnabled(key, on)
    SecureCall(self, "SetAuraSlotEnabled")
    self._slots[key].enabled = on
  end
end
-- what the game shows in each aura slot (run every frame)
function M.UpdateContainers()
  M.gameCall = true
  for _, c in ipairs(M.containers) do
    for _, slot in pairs(c._slots) do
      local b, found = slot.button
      if c:IsVisible() and slot.enabled and slot.ids then
        local unit = c._unit
        local harmful = slot.filter:find("HARMFUL") ~= nil
        local hostile = unit == "target" and S.target and S.target.hostile
        local exists = unit == "player" or (unit == "target" and S.target ~= nil)
        local permitted = exists and ((harmful and hostile) or (not harmful and not hostile))
        if permitted then
          for _, a in ipairs((S.auras or {})[unit] or {}) do
            if (a.harmful == true) == harmful and a.spellId and slot.ids[a.spellId]
              and not (slot.filter:find("PLAYER") and (a.source or "player") ~= "player") then found = a break end
          end
        end
      end
      if found then
        b:Show()
        if b._icon then b._icon:SetTexture(found.icon) end
        if b._cd then
          if found.duration and found.duration > 0 then b._cd:SetCooldown(found.expirationTime - found.duration, found.duration) else b._cd:Clear() end
        end
        if b._count then b._count:SetText((found.applications or 0) > 1 and found.applications or "") end
      else
        b:Hide()
      end
    end
  end
  M.gameCall = false
end
local function tex(f, layer) return f:CreateTexture(nil, layer or "BACKGROUND") end
M.TEMPLATES.PortraitFrameTemplate = function(f)
  f.Bg = tex(f)
  f.NineSlice = CreateFrame("Frame", nil, f); f.NineSlice:SetAllPoints()
  f.PortraitContainer = CreateFrame("Frame", nil, f); f.PortraitContainer:SetSize(1, 1); f.PortraitContainer:SetPoint("TOPLEFT")
  f.PortraitContainer.portrait = f.PortraitContainer:CreateTexture(nil, "OVERLAY")
  f.PortraitContainer.portrait:SetSize(62, 62); f.PortraitContainer.portrait:SetPoint("TOPLEFT", -5, 7)
  f.TitleContainer = CreateFrame("Frame", nil, f); f.TitleContainer:SetHeight(20)
  f.TitleContainer:SetPoint("TOPLEFT", 58, -1); f.TitleContainer:SetPoint("TOPRIGHT", -24, -1)
  f.TitleContainer.TitleText = f.TitleContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.TitleContainer.TitleText:SetPoint("TOP", 0, -5); f.TitleContainer.TitleText:SetPoint("LEFT"); f.TitleContainer.TitleText:SetPoint("RIGHT")
  f.CloseButton = CreateFrame("Button", nil, f, "UIPanelCloseButton"); f.CloseButton:SetPoint("TOPRIGHT", 1, 0)
end
M.TEMPLATES.DefaultPanelTemplate = function(f)
  f.Bg = tex(f)
  f.NineSlice = CreateFrame("Frame", nil, f); f.NineSlice:SetAllPoints()
  f.TitleContainer = CreateFrame("Frame", nil, f); f.TitleContainer:SetHeight(20)
  f.TitleContainer:SetPoint("TOPLEFT", 30, -1); f.TitleContainer:SetPoint("TOPRIGHT", -24, -1)
  f.TitleContainer.TitleText = f.TitleContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.TitleContainer.TitleText:SetPoint("TOP", 0, -5); f.TitleContainer.TitleText:SetPoint("LEFT"); f.TitleContainer.TitleText:SetPoint("RIGHT")
  f.SetTitle = function(self, t) self.TitleContainer.TitleText:SetText(t) end
end
M.TEMPLATES.UIPanelScrollFrameTemplate = function(f)
  f.ScrollBar = CreateFrame("Slider", nil, f)
  f.ScrollBar:SetPoint("TOPLEFT", f, "TOPRIGHT", 6, -16); f.ScrollBar:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", 6, 16)
  f.ScrollBar:SetWidth(16); f.ScrollBar:SetMinMaxValues(0, 0)
end
M.TEMPLATES.UIPanelCloseButton = function(b)
  b:SetSize(24, 24)
  b:SetScript("OnClick", function(self) self:GetParent():Hide() end)
end
M.TEMPLATES.TooltipBackdropTemplate = function(f) end -- (a tooltip's border and back)
-- the game's nine-slice borders (NineSliceUtil lays a layout's pieces) and its dialog title plate
local NINE = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge" }
NineSliceUtil = { ApplyLayoutByName = function(f, layout)
  f.layoutType = layout
  for _, key in ipairs(NINE) do f[key] = f[key] or tex(f, "BORDER") end
end }
M.TEMPLATES.NineSlicePanelTemplate = function(f) if f.layoutType then NineSliceUtil.ApplyLayoutByName(f, f.layoutType) end end
M.TEMPLATES.DialogHeaderTemplate = function(f)
  f:SetSize(200, 39)
  f.LeftBG, f.RightBG, f.CenterBG = tex(f), tex(f), tex(f)
  f.Text = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  f.Setup = function(self, text) self.Text:SetText(text) end
end
M.TEMPLATES.InsetFrameTemplate = function(f)
  f.Bg = tex(f, "BACKGROUND"); f.NineSlice = CreateFrame("Frame", nil, f); f.NineSlice:SetAllPoints()
end
M.TEMPLATES.UIPanelButtonTemplate = function(b)
  b.Left, b.Middle, b.Right = tex(b), tex(b), tex(b)
  b:SetNormalFontObject("GameFontNormal")
end
M.TEMPLATES.UICheckButtonTemplate = function(b)
  b:SetSize(32, 32)
  b.Text = b:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"); b.Text:SetPoint("LEFT", b, "RIGHT", -2, 0)
  b.text = b.Text
end
M.TEMPLATES.UISliderTemplate = function(s)
  s:SetHitRectInsets(0, 0, -10, -10) -- as in Blizzard's XML
  s.NineSlice = CreateFrame("Frame", nil, s); s.NineSlice:SetAllPoints()
  s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal"); s:GetThumbTexture():SetSize(32, 32)
end
M.TEMPLATES.UISliderTemplateWithLabels = function(s)
  M.TEMPLATES.UISliderTemplate(s)
  s.Text = s:CreateFontString(nil, "ARTWORK", "GameFontHighlight"); s.Text:SetPoint("BOTTOM", s, "TOP")
  s.Low = s:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"); s.Low:SetText("LOW")
  s.High = s:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"); s.High:SetText("HIGH")
end
M.TEMPLATES.SearchBoxTemplate = function(e) -- (the game's search box: its magnifier, grey "Search", clear cross)
  e.Left, e.Middle, e.Right = tex(e), tex(e), tex(e)
  e.searchIcon = tex(e)
end
M.TEMPLATES.InputBoxTemplate = function(e)
  e.Left, e.Middle, e.Right = tex(e), tex(e), tex(e)
end
M.TEMPLATES.CooldownFrameTemplate = function(c) c:SetAllPoints(c._parent) end
-- the game's secure action button: a click casts what its attributes say (M.casts)
M.TEMPLATES.SecureHandlerStateTemplate = function(f) f._protected = true end -- (its _onstate-<name> snippets: test61)
M.TEMPLATES.SecureActionButtonTemplate = function(b)
  b._secure = true
  b:SetScript("OnClick", function(self, button)
    if InCombatLockdown() and not self._placedForCombat then end
    local n = button == "LeftButton" and "1" or "2" -- (an attribute of the button's number, else the plain one)
    local function Attr(key) local v = self:GetAttribute(key .. n); if v == nil then v = self:GetAttribute(key) end return v end
    local kind = Attr("type")
    if kind == "spell" then M.casts = M.casts or {}; table.insert(M.casts, Attr("spell")) end
    if kind == "macro" then M.casts = M.casts or {}; table.insert(M.casts, "macro:" .. tostring(Attr("macrotext"))) end
  end)
end
M.TEMPLATES.PanelTabButtonTemplate = function(t)
  t:SetSize(10, 32)
  for _, k in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive" }) do t[k] = tex(t); t[k]:SetWidth(k:find("Middle") and 1 or 20) end
  t.Text = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); t.Text:SetPoint("CENTER")
  t._textFS = t.Text
  local parent = t:GetParent(); parent.Tabs = parent.Tabs or {}; table.insert(parent.Tabs, t)
  t:SetScript("OnShow", function(self) PanelTemplates_TabResize(self, 0) end)
end
M.TEMPLATES.PanelTopTabButtonTemplate = function(t)
  t:SetSize(10, 32)
  for _, k in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive" }) do t[k] = tex(t); t[k]:SetWidth(k:find("Middle") and 1 or 20) end
  t.Text = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); t.Text:SetPoint("CENTER")
  t._textFS = t.Text
  t.isTopTab = true
  local parent = t:GetParent(); parent.Tabs = parent.Tabs or {}; table.insert(parent.Tabs, t)
  t:SetScript("OnShow", function(self) PanelTemplates_TabResize(self, 0) end)
end
-- as the game: text + 20, at least the two side textures (about 70 wide on the screenshots);
-- or exactly absoluteSize wide (not under the side textures)
function PanelTemplates_TabResize(tab, padding, absoluteSize)
  if absoluteSize then tab:SetWidth(math.max(40, absoluteSize)) return end
  tab:SetWidth(math.max(70, tab.Text:GetStringWidth() + 20 + (padding or 0)))
end
function PanelTemplates_SelectTab(tab) tab._selected = true; tab:Disable() end
function PanelTemplates_DeselectTab(tab) tab._selected = false; tab:Enable() end

-- the game's dialog boxes (12.x GameDialog): M.popup is the one shown; M.PopupClick(i) clicks
-- button i, M.PopupEscape() presses Escape
StaticPopupDialogs = {}
function StaticPopup_Show(which, a1, a2, data)
  local info = assert(StaticPopupDialogs[which], "unknown dialog " .. tostring(which))
  assert(not (info.OnAccept and info.OnButton1), "OnAccept and OnButton1")
  assert(not (info.OnCancel and info.OnButton2), "OnCancel and OnButton2")
  local buttons = {}
  for i = 1, 4 do if info["button" .. i] then buttons[i] = info["button" .. i] end end
  M.popup = { which = which, info = info, data = data, text = info.text:format(a1, a2), buttons = buttons }
  return M.popup
end
function M.PopupClick(i)
  local pop = assert(M.popup, "no dialog shown")
  assert(pop.buttons[i], "no button " .. i)
  M.popup = nil
  local info = pop.info
  local fn = info.selectCallbackByIndex and info["OnButton" .. i] or (i == 1 and info.OnAccept) or (i == 2 and info.OnCancel) or (i == 3 and info.OnAlt)
  if fn then fn(pop, pop.data, "clicked") end
function GameTooltip:SetItemByID(id) self._lines = { "item:" .. id } end
end
function M.PopupEscape()
  local pop = assert(M.popup, "no dialog shown")
  assert(pop.info.hideOnEscape, "Escape does not close it")
  M.popup = nil
  if pop.info.OnEscape then pop.info.OnEscape(pop, pop.data, "clicked")
  elseif pop.info.OnCancel and not pop.info.noCancelOnEscape then pop.info.OnCancel(pop, pop.data, "clicked") end
end

-- the game's options panel (Esc > Options): addon pages registered as canvases
M.settingsCategories = {}
Settings = {
  RegisterCanvasLayoutCategory = function(frame, name)
    assert(type(name) == "string" and frame, "canvas needs a frame and a name")
    local category = { frame = frame, name = name, ID = #M.settingsCategories + 100 }
    function category:GetID() return self.ID end
    return category, { GetFrame = function() return frame end }
  end,
  RegisterAddOnCategory = function(category) table.insert(M.settingsCategories, category) end,
  RegisterCanvasLayoutSubcategory = function(parent, frame, name)
    assert(parent and frame and type(name) == "string", "subcategory needs a parent, a frame and a name")
    local category = { frame = frame, name = name, parent = parent, ID = #M.settingsCategories + 100 }
    function category:GetID() return self.ID end
    table.insert(M.settingsCategories, category)
    return category
  end,
  OpenToCategory = function(id) M.openedCategory = id end,
}
function M.ShowSettingsPage(category)
  local f = category.frame
  f._parent = SettingsPanel; f:SetAllPoints(SettingsPanel)
  SettingsPanel:Show(); f:Show()
  if f.OnRefresh then f:OnRefresh() end
end

GameTooltip = { _shown = false }
function GameTooltip:SetOwner(o) self._owner = o; self._lines = {} end
function GameTooltip:SetText(t) self._lines = { t } end
function GameTooltip:AddLine(t) table.insert(self._lines, t) end
function GameTooltip:SetSpellByID(id) self._lines = { "spell:" .. id } end
function GameTooltip:SetItemByID(id) self._lines = { "item:" .. id } end
function GameTooltip:Show() self._shown = true end
function GameTooltip:Hide() self._shown = false; self._owner = nil end
function GameTooltip:IsOwned(o) return self._owner == o end
function GameTooltip:AddDoubleLine(l, r) table.insert(self._lines, tostring(l) .. "\t" .. tostring(r)) end
function GameTooltip_Hide() GameTooltip:Hide() end
function StaticPopup_Hide(which) if M.popup and M.popup.which == which then M.popup = nil end end
function GetMoneyString(copper)
  local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  return (g > 0 and g .. "g " or "") .. ((g > 0 or s > 0) and s .. "s " or "") .. c .. "c"
end
GREEN_FONT_COLOR = { r = .1, g = 1, b = .1 }; HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 }
GREEN_FONT_COLOR_CODE = "|cff20ff20"
OKAY, CANCEL, YES, NO = "Okay", "Cancel", "Yes", "No"
NUM_BAG_SLOTS = 4
bit = bit or { band = function(a, b)
  local r, p = 0, 1
  while a > 0 and b > 0 do
    if a % 2 == 1 and b % 2 == 1 then r = r + p end
    a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2
  end
  return r
end }
-- the game's options: vertical subcategories and settings it keeps (BuyEmAll's page)
Settings.VarType = { Boolean = "boolean", Number = "number", String = "string" }
function Settings.RegisterVerticalLayoutSubcategory(parent, name)
  local category = { name = name, parent = parent, ID = #M.settingsCategories + 200, settings = {}, rows = {} }
  function category:GetID() return self.ID end
  M.subcategories = M.subcategories or {}
  M.subcategories[name] = category
  M.subcategoryList = M.subcategoryList or {}
  table.insert(M.subcategoryList, category)
  return category, { AddInitializer = function(_, init) table.insert(category.rows, init) end }
end
-- the rows the game's helpers make (an initializer: its setting, its kind, whether it is on)
local function Initializer(category, setting, kind, extra)
  local init = { setting = setting, kind = kind, predicates = {} }
  for k, v in pairs(extra or {}) do init[k] = v end
  function init:AddModifyPredicate(fn) table.insert(self.predicates, fn) end
  function init:IsOn() for _, fn in ipairs(self.predicates) do if not fn() then return false end end return true end
  if setting then setting.init = init end
  if category and category.rows then table.insert(category.rows, init) end
  return init
end
function Settings.CreateSliderOptions(min, max, step)
  return { min = min, max = max, step = step, SetLabelFormatter = function(self, where, fn) self.formatter = fn end }
end
function Settings.CreateSlider(category, setting, options, tooltip)
  setting.slider, setting.tooltip = options, tooltip
  return Initializer(category, setting, "slider", { options = options })
end
function Settings.CreateControlTextContainer()
  local data = {}
  return { Add = function(_, value, label) table.insert(data, { value = value, label = label }) end, GetData = function() return data end }
end
function Settings.CreateDropdown(category, setting, options, tooltip)
  setting.dropdown, setting.tooltip = options, tooltip
  return Initializer(category, setting, "dropdown")
end
function CreateSettingsButtonInitializer(name, buttonText, onClick, tooltip, search)
  return { kind = "button", name = name, buttonText = buttonText, click = onClick, tooltip = tooltip }
end
function CreateSettingsListSectionHeaderInitializer(text) return { kind = "header", name = text } end
function Settings.RegisterProxySetting(category, variable, kind, name, default, get, set)
  local setting = { variable = variable, name = name, default = default, GetValue = function() return get() end,
    SetValue = function(_, v) set(v) end }
  category.settings[#category.settings + 1] = setting
  return setting
end
function Settings.CreateCheckbox(category, setting, tooltip)
  setting.checkbox, setting.tooltip = true, tooltip
  return Initializer(category, setting, "checkbox")
end

-- screen ----------------------------------------------------------------------
UIParent = CreateFrame("Frame", "UIParent")
UIParent._scale = S.uiScale
function M.ScreenSize() -- in UIParent units
  local h = 768 / (S.uiScale or .71) -- (a test that wiped the state: the default screen)
  return h * 2560 / (S.physH or 1359), h
end
UIParent.GetCenter = function() local w, h = M.ScreenSize(); return w / 2, h / 2 end

-- Layout: rect in the region's own frame units -> convert through effective scales.
-- We compute absolute rects (in "effective-scale-1" units) then convert.
local function effScale(r)
  if r._kind == "Texture" or r._kind == "FontString" then return r._parent:GetEffectiveScale() end
  return r:GetEffectiveScale()
end

local absCache
local function absRect(r) -- returns left, bottom, width, height in absolute units (eff scale 1)
  if r == UIParent then
    local w, h = M.ScreenSize(); local s = UIParent:GetEffectiveScale()
    return 0, 0, w * s, h * s
  end
  if absCache[r] then return unpack(absCache[r]) end
  absCache[r] = { 0, 0, 0, 0 } -- cycle guard
  if r._fillOf then
    local bar = r._fillOf
    local bl, bb, bw, bh = absRect(bar)
    local v = reveal(bar._value) or 0
    local frac = math.max(0, math.min(1, (v - bar._min) / (bar._max - bar._min)))
    absCache[r] = { bl, bb, bw * frac, bh }
    return bl, bb, bw * frac, bh
  end
  local s = effScale(r)
  local pts = r._points or {}
  local L, R, T, B, CX, CY
  for _, p in ipairs(pts) do
    local point, rel, relPoint, x, y = p[1], p[2], p[3], p[4], p[5]
    rel = rel or UIParent
    local rl, rb, rw, rh = absRect(rel)
    local px, py
    if relPoint:find("LEFT") then px = rl elseif relPoint:find("RIGHT") then px = rl + rw else px = rl + rw / 2 end
    if relPoint:find("TOP") then py = rb + rh elseif relPoint:find("BOTTOM") then py = rb else py = rb + rh / 2 end
    if rel._kind == "Frame" or rel._kind ~= "Texture" then
      if rel._scrollParent then py = py + (rel._scrollParent._vs or 0) * s end
    end
    px, py = px + x * s, py + y * s
    if point:find("LEFT") then L = px elseif point:find("RIGHT") then R = px else CX = px end
    if point:find("TOP") then T = py elseif point:find("BOTTOM") then B = py else CY = py end
  end
  local w = r._w and r._w * s
  local h = r._h and r._h * s
  if r._kind == "FontString" and not w then
    w = r:GetStringWidth() * s; h = (r._font and r._font[2] or 10) * s
    if L and R then w = R - L end
  elseif r._kind == "FontString" and not h then -- a set width: as tall as its wrapped text
    h = r:GetStringHeight() * s
  end
  w = w or 0; h = h or 0
  local left = L or (R and R - w) or (CX and CX - w / 2) or 0
  if L and R then w = R - L end
  local bottom = B or (T and T - h) or (CY and CY - h / 2) or 0
  if T and B then h = T - B end
  absCache[r] = { left, bottom, w, h }
  return left, bottom, w, h
end

function M.Rect(r) -- in the region's own units
  absCache = {}
  local l, b, w, h = absRect(r)
  local s = effScale(r)
  return l / s, b / s, w / s, h / s
end
function M.AbsRect(r) absCache = absCache or {}; return absRect(r) end
function M.ResetLayout() absCache = {} end

-- driving -----------------------------------------------------------------------
-- EventUtil (Blizzard_SharedXML): a callback once an addon is loaded, the game's own frame waiting
M.addonWaits = {}
EventUtil = EventUtil or {}
function EventUtil.ContinueOnAddOnLoaded(name, fn)
  local any, loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name)
  if loaded or (loaded == nil and any) then return fn() end
  M.addonWaits[name] = M.addonWaits[name] or {}
  table.insert(M.addonWaits[name], fn)
end
function M.Fire(event, ...)
  if event == "ADDON_LOADED" and M.addonWaits[(...)] then
    local waits = M.addonWaits[(...)]
    M.addonWaits[(...)] = nil
    for _, fn in ipairs(waits) do fn() end
  end
  -- (a copy: handlers register and unregister events meanwhile, as the game allows)
  local list = {}
  for f in pairs(M.eventFrames) do list[#list + 1] = f end
  for _, f in ipairs(list) do
    if f._events and f._events[event] then
      local u = f._unitFilter and f._unitFilter[event]
      if not u or u[1] == (...) or u[2] == (...) then f._scripts.OnEvent(f, event, ...) end
    end
  end
end
function M.Frame(dt)
  M.now = (M.now or 0) + dt
  for _, f in ipairs(M.frames) do
    if f._scripts and f._scripts.OnUpdate and f:IsVisible() then f._scripts.OnUpdate(f, dt) end
  end
  M.UpdateContainers()
end

SettingsPanel = CreateFrame("Frame", "SettingsPanel", UIParent)
SettingsPanel:SetSize(665, 601); SettingsPanel:SetPoint("CENTER")
SettingsPanel:Hide()
function SettingsPanel:Close(skip) self._closedWithSkip = skip; self:Hide() end

-- ColorPickerFrame mock (12.x behaviour)
ColorPickerFrame = CreateFrame("Frame", "ColorPickerFrame", UIParent)
ColorPickerFrame:Hide()
local cp = { r = 1, g = 1, b = 1, a = 1 }
function ColorPickerFrame:SetupColorPickerAndShow(info)
  self.swatchFunc, self.opacityFunc, self.cancelFunc = info.swatchFunc, info.opacityFunc, info.cancelFunc
  self.opacity = info.opacity
  cp.r, cp.g, cp.b = info.r, info.g, info.b
  if self.swatchFunc then self.swatchFunc() end -- OnColorSelect during setup (alpha still stale)
  if self.opacityFunc then self.opacityFunc() end
  self:Show(); cp.a = self.opacity
end
function ColorPickerFrame:GetColorRGB() return cp.r, cp.g, cp.b end
function ColorPickerFrame:GetColorAlpha() return cp.a end
function M.PickColor(r, g, b, a) cp.r, cp.g, cp.b, cp.a = r, g, b, a; ColorPickerFrame.swatchFunc(); if ColorPickerFrame.opacityFunc then ColorPickerFrame.opacityFunc() end end
function M.PickerOkay() ColorPickerFrame.swatchFunc(); if ColorPickerFrame.opacityFunc then ColorPickerFrame.opacityFunc() end; ColorPickerFrame:Hide() end
function M.PickerCancel() ColorPickerFrame.cancelFunc(); ColorPickerFrame:Hide() end
function M.SetStaleAlpha(a) cp.a = a end

-- Group and instance (S.group: nil / "party" / "raid"; S.instance: { kind = "party" / "raid",
-- maxPlayers, groupSize })
function IsInRaid() return S.group == "raid" end
function IsInGroup() return S.group == "party" or S.group == "raid" end
function IsInInstance()
  if S.instance then return true, S.instance.kind end
  return false, "none"
end
function GetInstanceInfo()
  local i = S.instance or {}
  return "Somewhere", i.kind or "none", 0, "", i.maxPlayers or 0, 0, false, 0, i.groupSize or 0
end

-- The game's slider with steppers (MinimalSliderWithSteppersTemplate): callbacks per owner.
MinimalSliderWithSteppersMixin = { Event = { OnValueChanged = "OnValueChanged" }, Label = { Left = 1, Right = 2, Top = 3, Min = 4, Max = 5 } }
M.TEMPLATES.MinimalSliderWithSteppersTemplate = function(f)
  f:SetSize(250, 40)
  f._callbacks = {}
  f.Slider = CreateFrame("Slider", nil, f)
  f.Slider:SetMinMaxValues(0, 1)
  f.Back, f.Forward = CreateFrame("Button", nil, f), CreateFrame("Button", nil, f)
  function f:RegisterCallback(event, fn, owner)
    self._callbacks[event] = self._callbacks[event] or {}
    self._callbacks[event][owner] = fn
  end
  function f:Init(value, minV, maxV, steps)
    self.Slider:SetMinMaxValues(minV, maxV)
    self.Slider:SetValueStep((maxV - minV) / steps)
    self.Slider:SetValue(value)
    self.Slider:SetScript("OnValueChanged", function(_, v)
      for owner, fn in pairs(self._callbacks.OnValueChanged or {}) do fn(owner, v) end
    end)
  end
  function f:SetValue(v) self.Slider:SetValue(v) end
end

-- The game's tagged menus (Blizzard_Menu): descriptions an addon inserts into
-- (Menu.ModifyMenu), each element's initializers giving its size, resetters on release.
HUD_EDIT_MODE_MENU = "Edit Mode"
local Description = {}
Description.__index = Description
local function NewDescription(kind, text, callback)
  return setmetatable({ kind = kind, text = text, callback = callback, initializers = {}, resetters = {}, elements = {} }, Description)
end
function Description:AddInitializer(fn) table.insert(self.initializers, fn) end
function Description:AddResetter(fn) table.insert(self.resetters, fn) end
function Description:SetTooltip(fn) self.tooltip = fn end
function Description:SetEnabled(v) self.enabled = v end
function Description:Insert(d, index)
  if index then table.insert(self.elements, index, d) else table.insert(self.elements, d) end
  return d
end
function Description:EnumerateElementDescriptions() return ipairs(self.elements) end
function Description:CreateButton(text, callback) return self:Insert(NewDescription("button", text, callback)) end
function Description:CreateTitle(text) return self:Insert(NewDescription("title", text)) end
function Description:CreateCheckbox(text, isSelected, setSelected)
  local d = NewDescription("checkbox", text); d.isSelected, d.setSelected = isSelected, setSelected
  return self:Insert(d)
end
function Description:CreateDivider() return self:Insert(NewDescription("divider")) end
function Description:CreateRadio(text, isSelected, setSelected, data)
  local d = NewDescription("radio", text); d.isSelected, d.setSelected, d.data = isSelected, setSelected, data
  return self:Insert(d)
end
function Description:QueueDivider() return self:Insert(NewDescription("divider")) end -- (laid at once: the next element follows it)
MenuUtil.CreateRadio = function(text, isSelected, setSelected, data)
  local d = NewDescription("radio", text); d.isSelected, d.setSelected, d.data = isSelected, setSelected, data
  return d
end
MenuResponse = MenuResponse or { Close = 1, Open = 2, Refresh = 3, CloseAll = 4 }
MenuUtil.CreateFrame = function() return NewDescription("frame") end
MenuUtil.CreateButton = function(text, callback) return NewDescription("button", text, callback) end
MenuUtil.GetElementText = function(d) return d.text end
MenuUtil.CreateDivider = function() return NewDescription("divider") end
MenuUtil.CreateTitle = function(text) return NewDescription("title", text) end
MenuUtil.CreateCheckbox = function(text, isSelected, setSelected)
  local d = NewDescription("checkbox", text); d.isSelected, d.setSelected = isSelected, setSelected
  return d
end
UNIT_FRAME_DROPDOWN_SUBSECTION_TITLE_OTHER = "Other Options"
ADD_FRIEND = "Add Friend"
M.menuModifiers = {}
Menu = { ModifyMenu = function(tag, fn)
  M.menuModifiers[tag] = M.menuModifiers[tag] or {}
  table.insert(M.menuModifiers[tag], fn)
end }
-- The portrait's menu as the game builds it (its Other Options part), then the addons' changes,
-- then shown: each element gets a frame, sized by its initializers.
function M.OpenUnitMenu(which)
  M.CloseUnitMenu()
  local root = NewDescription("root")
  root:CreateTitle("Lola")
  root:CreateButton("Set Focus")
  root:CreateDivider()
  root:CreateTitle("Other Options")
  root:CreateButton(HUD_EDIT_MODE_MENU)
  root:CreateButton("Voice Chat")
  root:CreateButton("Leave Party")
  for _, fn in ipairs(M.menuModifiers["MENU_UNIT_" .. (which or "SELF")] or {}) do fn(UIParent, root, {}) end
  local shown = { root = root, frames = {} }
  M.menuPool = M.menuPool or {}
  for i, d in ipairs(root.elements) do
    local frame = table.remove(M.menuPool) or CreateFrame("Frame", nil, UIParent)
    frame:SetParent(UIParent)
    frame:Show()
    frame:SetSize(1, 1)
    frame._description = d
    for _, init in ipairs(d.initializers) do
      local w, h = init(frame, d, shown)
      if w and h then frame:SetSize(w, h) end
    end
    shown.frames[i] = frame
  end
  M.unitMenu = shown
  return shown
end
function M.UnitMenuTexts()
  local out = {}
  for i, d in ipairs(M.unitMenu.root.elements) do out[i] = d.text or ("<" .. d.kind .. ">") end
  return out
end
function M.CloseUnitMenu()
  local shown = M.unitMenu
  if not shown then return end
  for _, frame in ipairs(shown.frames) do
    for _, reset in ipairs(frame._description.resetters) do reset(frame) end
    frame:Hide()
    table.insert(M.menuPool, frame) -- reused by the next menu, maybe for another element
  end
  M.unitMenu = nil
end

-- another addon (its own toc and name): ClassicFriendsList
function M.LoadAddonAs(dir, tocName, addonName, ns)
  local toc = assert(io.open(dir .. "/" .. tocName, "rb")):read("*a")
  for file in toc:gmatch("[^\r\n]+") do
    if not file:match("^##") and file:match("%.lua$") then
      local f = assert(io.open(dir .. "/" .. file:gsub("\\", "/"), "rb"))
      local chunk = assert(loadstring(f:read("*a"), "@" .. file)); f:close()
      chunk(addonName, ns)
    end
  end
end
-- (the built-in Clique needs its libraries, loaded by XML, which this mock does not read: its files are left out unless
-- a test asks for them, M.withClique, and loads those libraries itself)
function M.LoadAddon(dir, ns)
  -- (and the module off, unless asked: its newer AceDB is not loaded for the other modules' tests either)
  local db = rawget(_G, "ClaraComboPointsDB")
  local cliqueOff = not M.withClique and not (type(db) == "table" and type(db.qol) == "table" and db.qol.clique ~= nil)
  if cliqueOff then
    if type(db) ~= "table" then db = {}; ClaraComboPointsDB = db end
    db.qol = type(db.qol) == "table" and db.qol or {}
    db.qol.clique = false
  end
  local toc = assert(io.open(dir .. "/ClaraComboPoints.toc", "rb")):read("*a")
  for file in toc:gmatch("[^\r\n]+") do
    if not file:match("^##") and file:match("%.lua$") and (M.withClique or not file:find("Modules\\Clique\\", 1, true)) then
      local f = assert(io.open(dir .. "/" .. file:gsub("\\", "/"), "rb"))
      local chunk = assert(loadstring(f:read("*a"), "@" .. file)); f:close()
      chunk("ClaraComboPoints", ns)
    end
  end
end

-- attributes (secure frames read them)
function classes.Frame:SetAttribute(k, v) self._attrs = self._attrs or {}; self._attrs[k] = v end
function classes.Frame:GetAttribute(k) return self._attrs and self._attrs[k] end
-- In combat the game blocks these on protected frames (secure ones and their parents): the call
-- does nothing and M.blocked records it (a test can then fail on it).
M.blocked = {}
local function Guarded(c, name)
  local fn = rawget(c, name)
  if not fn then return end
  c[name] = function(self, ...)
    if S.inCombat and (self._secure or self._protected) then
      table.insert(M.blocked, name .. " on " .. tostring(self._name or self._kind))
      return
    end
    return fn(self, ...)
  end
end
for _, n in ipairs({ "SetPoint", "ClearAllPoints", "SetSize", "SetShown", "Show", "Hide", "SetAllPoints", "SetWidth", "SetHeight" }) do Guarded(classes.Region, n) end
for _, n in ipairs({ "Show", "Hide", "SetScale", "SetAttribute", "SetShown", "SetFrameLevel", "EnableMouse", "SetParent" }) do Guarded(classes.Frame, n) end

-- the chat: ChatFrame1 keeps its lines (M.chat); debugstack returns M.stack, the files of the
-- code that writes (the game's chat by default)
ChatFrame1 = CreateFrame("Frame", "ChatFrame1", UIParent)
M.chat = {}
function ChatFrame1:AddMessage(text) table.insert(M.chat, text) end
function ChatFrame1:RemoveMessagesByPredicate(pred)
  for i = #M.chat, 1, -1 do if pred(M.chat[i]) then table.remove(M.chat, i) end end
end
DEFAULT_CHAT_FRAME = ChatFrame1
WorldFrame = CreateFrame("Frame", "WorldFrame")
NUM_CHAT_WINDOWS = 1
function debugstack() return M.stack or "[Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrame.lua]:10: in function <...>" end

-- more units (S.units[token] = { name, guid, player, enemy, attackable, dead, level, class, classification,
-- controlled }), beside the target above; the map and the channels (S.map = { id, x, y, name }, S.subzone,
-- S.channels = { name, ... } joined in order; M.joined: the joins asked; M.addonSent: the addon messages)
local function Unit(u) return S.units and S.units[u] end
local oldName, oldGUID, oldExists, oldDead, oldAttack = UnitName, UnitGUID, UnitExists, UnitIsDead, UnitCanAttack
function UnitName(u) local x = Unit(u) if x then return x.name end return oldName(u) end
function UnitGUID(u) local x = Unit(u) if x then return x.guid end return oldGUID(u) end
function UnitExists(u) if Unit(u) then return true end return oldExists(u) end
function UnitIsDead(u) local x = Unit(u) if x then return x.dead or false end return oldDead(u) end
function UnitCanAttack(a, b) local x = Unit(b) if x then return x.attackable or false end return oldAttack(a, b) end
function UnitIsPlayer(u) local x = Unit(u) return x and x.player or false end
function UnitIsEnemy(a, b) local x = Unit(b) return x and x.enemy or false end
function UnitPlayerControlled(u) local x = Unit(u) return x and (x.player or x.controlled) or false end
function UnitLevel(u) local x = Unit(u) return x and x.level or 60 end
function UnitClassification(u) local x = Unit(u) return x and x.classification or "normal" end
function UnitOnTaxi() return S.taxi or false end
function strtrim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
function Ambiguate(name) return (name:gsub("%-.*$", "")) end
function IsInGuild() return S.guild or false end
function GetSubZoneText() return S.subzone or "" end
function FlashClientIcon() M.flashed = (M.flashed or 0) + 1 end
function Screenshot() M.shots = (M.shots or 0) + 1 end
function GetBindingKey(name) return S.bindings and S.bindings[name] end
function GetBindingText(key) return key end
C_Map = C_Map or {}
C_Map.GetBestMapForUnit = function(u) return S.map and S.map.id end
C_Map.GetPlayerMapPosition = function(map, u)
  if not (S.map and S.map.x) then return end
  return { GetXY = function() return S.map.x, S.map.y end }
end
C_Map.GetMapInfo = function(map) return { mapID = map, name = S.map and S.map.name or "Map" } end
C_Map.CanSetUserWaypointOnMap = C_Map.CanSetUserWaypointOnMap or function() return true end
C_Map.SetUserWaypoint = C_Map.SetUserWaypoint or function(point) M.waypoint = point end
UiMapPoint = UiMapPoint or { CreateFromCoordinates = function(map, x, y) return { uiMapID = map, x = x, y = y } end }
M.joined, M.addonSent = {}, {}
function GetChannelList()
  local out = {}
  for i, name in ipairs(S.channels or {}) do out[#out + 1] = i; out[#out + 1] = name; out[#out + 1] = false end
  return unpack(out)
end
function GetChannelName(name)
  for i, n in ipairs(S.channels or {}) do if n:lower() == tostring(name):lower() then return i, n end end
  return 0
end
function JoinChannelByName(name) table.insert(M.joined, name) end
C_ChatInfo.RegisterAddonMessagePrefix = function(prefix) M.prefixes = M.prefixes or {}; M.prefixes[prefix] = true return true end
C_ChatInfo.SendAddonMessage = function(prefix, text, chatType, target) table.insert(M.addonSent, { prefix, text, chatType, target }) end
local oldSend = C_ChatInfo.SendChatMessage
C_ChatInfo.SendChatMessage = function(text, chatType, lang, target)
  if S.hardware == false and chatType == "CHANNEL" then error("SendChatMessage: hardware event needed") end
  oldSend(text, chatType)
  M.sent[#M.sent][3] = target
end

function HideUIPanel(f) if f then f:Hide() end end
return M
