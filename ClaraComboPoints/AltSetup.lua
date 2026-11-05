-- Clara Combo Points - the game's own settings handed down to alts. A profile holds what a
-- character keeps for itself (its alts start without it): the action bars shown (2 to 8), every
-- game setting stored for that character only (the Options window's and the others), the Edit
-- Mode layout in use, its key bindings, the per-character settings of Clara's modules, and the
-- profile each addon using AceDB (most addons) has for this character. Settings stored for the
-- whole account (or the computer) are already every character's: not kept, so a later change of
-- them is never undone. (Other addons' own per-character files cannot be read by another addon.)
-- The profile picked as the alts' one goes, once, to each new character (level 5 or lower) at its
-- first login with the addon, out of combat; the interface is then offered a reload. A profile
-- can also be put on the current character by hand (the options window's header), and passed to
-- another account as a line of text (export / import). Profiles and the characters done are
-- account-wide (ClaraComboPointsDB.alts).

local ADDON, ns = ...
local L = ns.L

local min, max = math.min, math.max

local NEW_LEVEL = 5    -- up to this level, a character not done yet is a new one
local NAME_MAX = 32    -- a profile's name, in characters
local BARS_MAX = 12    -- action bar switches kept
local EXPORT_PREFIX = "CCPA1:" -- (a class tab's profiles: CCP1, Profiles.lua)
local MAX_IMPORT = 4194304 -- (the addons' settings with it: a long line)
local KEEP_DEPTH = 4 -- an addon's settings kept when no deeper than this (an export holds 8 levels at most)
-- Clara's modules' settings kept for each character (their SavedVariablesPerCharacter), whole
local CHAR_TABLES = { "ClaraClassicUICharDB", "ClaraLFGForeverCharDB", "WT_IgnoredSpells", "WT_HideWeaponSkillSwitcher",
  "WT_PriceFaction" }
-- game settings stored for a character that are its state rather than a setting: not handed down
local NOT_SETTINGS = { "^last", "^cameraSaved", "Tracked", "^lastTransmog" }

---------------------------------------------------------------------------
-- Saved data
---------------------------------------------------------------------------
-- How many tables deep a value goes (nil past the limit)
local function Depth(v, limit, d)
  d = d or 0
  if type(v) ~= "table" then return d end
  if d >= limit then return nil end
  local most = d + 1
  for k, x in pairs(v) do
    if type(k) == "table" then return nil end
    local n = Depth(x, limit, d + 1)
    if not n then return nil end
    if n > most then most = n end
  end
  return most
end

-- A copy of plain data (strings, numbers, booleans, tables of them)
local function Copy(v)
  local t = type(v)
  if t == "string" or t == "number" or t == "boolean" then return v end
  if t ~= "table" then return nil end
  local out = {}
  for k, x in pairs(v) do
    local kt = type(k)
    if kt == "string" or kt == "number" then
      local c = Copy(x)
      if c ~= nil then out[k] = c end
    end
  end
  return out
end

-- Key bindings: { set = 1 or 2, list = { { command, key, key... } } }
local function CleanBindings(b)
  if type(b) ~= "table" or type(b.list) ~= "table" then return nil end
  local list = {}
  for _, e in ipairs(b.list) do
    if type(e) == "table" and type(e[1]) == "string" then
      local entry = { e[1] }
      for j = 2, #e do if type(e[j]) == "string" and e[j] ~= "" then entry[#entry + 1] = e[j] end end
      if #entry > 1 then list[#list + 1] = entry end
    end
  end
  return { set = (b.set == 1 or b.set == 2) and b.set or 2, list = list }
end

local function CleanProfile(p)
  if type(p) ~= "table" then return nil end
  local cvars = {}
  if type(p.cvars) == "table" then
    for name, value in pairs(p.cvars) do
      if type(name) == "string" and type(value) == "string" then cvars[name] = value end
    end
  end
  local bars = {}
  if type(p.bars) == "table" then
    for i = 1, BARS_MAX do
      if type(p.bars[i]) ~= "boolean" then break end
      bars[i] = p.bars[i]
    end
  end
  local layout = p.layout
  if type(layout) ~= "table" or type(layout.kind) ~= "number" or type(layout.name) ~= "string"
    or (layout.index ~= nil and type(layout.index) ~= "number") then
    layout = nil
  else
    layout = { kind = layout.kind, name = layout.name, index = layout.index }
  end
  local chars = {}
  if type(p.chars) == "table" then
    for _, name in ipairs(CHAR_TABLES) do
      if p.chars[name] ~= nil and Depth(p.chars[name], KEEP_DEPTH + 1) then chars[name] = Copy(p.chars[name]) end
    end
  end
  local ace = {}
  if type(p.ace) == "table" then
    for name, a in pairs(p.ace) do
      if type(name) == "string" and type(a) == "table" and type(a.key) == "string" and type(a.data) == "table"
        and Depth(a.data, KEEP_DEPTH + 1) then
        ace[name] = { key = a.key, mine = a.mine and true or nil, data = Copy(a.data) }
      end
    end
  end
  return { cvars = cvars, bars = bars, layout = layout, bindings = CleanBindings(p.bindings), chars = chars, ace = ace,
    from = type(p.from) == "string" and p.from or nil, when = type(p.when) == "number" and p.when or nil }
end

-- Core.lua (InitDB): the saved data checked
function ns:InitAlts(sv)
  local alts = type(sv.alts) == "table" and sv.alts or {}
  local profiles = {}
  if type(alts.profiles) == "table" then
    for name, p in pairs(alts.profiles) do
      if type(name) == "string" and name ~= "" and #name <= NAME_MAX * 4 then profiles[name] = CleanProfile(p) end
    end
  end
  local done = {}
  if type(alts.done) == "table" then
    for who, v in pairs(alts.done) do if type(who) == "string" and v == true then done[who] = true end end
  end
  local default = type(alts.default) == "string" and profiles[alts.default] and alts.default or nil
  -- a save asked for once the interface is reloaded (the header's button, changes waiting for a reload)
  local after = alts.after
  if type(after) ~= "table" or type(after.name) ~= "string" or type(after.who) ~= "string" or type(after.when) ~= "number" then
    after = nil
  else
    after = { name = after.name, who = after.who, when = after.when }
  end
  sv.alts = { profiles = profiles, done = done, default = default, after = after }
end

local function Store()
  if not (ns.sv and ns.sv.alts) then return nil end
  return ns.sv.alts
end

local function Me()
  return UnitGUID and UnitGUID("player") or nil
end

---------------------------------------------------------------------------
-- What the game shows: read
---------------------------------------------------------------------------
-- The options of the game's Options window (its Game tab), by the console variable each sets.
local function OptionVariables()
  local found = {}
  local panel = SettingsPanel
  local settings = panel and type(panel.settings) == "table" and panel.settings
  if not settings then return found end
  local game = Settings and Settings.CategorySet and Settings.CategorySet.Game
  for setting, category in pairs(settings) do
    local ok, name = pcall(setting.GetVariable, setting)
    local inGame = game == nil
    if not inGame and type(category) == "table" and category.GetCategorySet then
      local okSet, set = pcall(category.GetCategorySet, category)
      inGame = okSet and set == game
    end
    if ok and type(name) == "string" and inGame then found[name] = true end
  end
  return found
end

-- Every game setting (console variable) the game has, the Options window's among them, but its state.
local function AllVariables()
  local found = OptionVariables()
  local get = C_Console and C_Console.GetAllCommands
  local ok, list = false, nil
  if get then ok, list = pcall(get) end
  if ok and type(list) == "table" then
    local CVAR = Enum and Enum.ConsoleCommandType and Enum.ConsoleCommandType.Cvar or 0
    for _, c in ipairs(list) do
      local name = type(c) == "table" and c.command
      if type(name) == "string" and c.commandType == CVAR then
        local skip = false
        for _, pattern in ipairs(NOT_SETTINGS) do if name:find(pattern) then skip = true break end end
        if not skip then found[name] = true end
      end
    end
  end
  return found
end

-- The key bindings in use (this character's own, or the account's)
local function ReadBindings()
  if not (GetNumBindings and GetBinding) then return nil end
  local list = {}
  for i = 1, GetNumBindings() do
    local t = { GetBinding(i) }
    if type(t[1]) == "string" then
      local entry = { t[1] }
      for j = 3, #t do if type(t[j]) == "string" and t[j] ~= "" then entry[#entry + 1] = t[j] end end
      if #entry > 1 then list[#list + 1] = entry end
    end
  end
  return { set = GetCurrentBindingSet and GetCurrentBindingSet() or 2, list = list }
end

-- This character's key in AceDB's tables ("Name - Realm")
local function AceKey()
  local who, realm = UnitName and UnitName("player"), GetRealmName and GetRealmName()
  return who and realm and (who .. " - " .. realm) or nil
end

-- Each AceDB table's profile for this character (the addons using AceDB: most of them)
local function ReadAce()
  local out, me = {}, AceKey()
  if not me then return out end
  for name, sv in pairs(_G) do
    if type(name) == "string" and type(sv) == "table" then
      local keys, profiles = rawget(sv, "profileKeys"), rawget(sv, "profiles")
      if type(keys) == "table" and type(profiles) == "table" then
        local key = rawget(keys, me)
        local data = type(key) == "string" and rawget(profiles, key)
        if type(data) == "table" and Depth(data, KEEP_DEPTH + 1) then
          out[name] = { key = key, mine = key == me or nil, data = Copy(data) }
        end
      end
    end
  end
  return out
end

-- Clara's modules' per-character settings
local function ReadChars()
  local out = {}
  for _, name in ipairs(CHAR_TABLES) do
    local v = rawget(_G, name)
    if v ~= nil and Depth(v, KEEP_DEPTH + 1) then out[name] = Copy(v) end
  end
  return out
end

-- A console variable this character keeps for itself, that an addon may set: its value.
local function OwnValue(name)
  if not (C_CVar and C_CVar.GetCVarInfo) then return nil end
  local value, _, _, perCharacter, locked, secure, readOnly = C_CVar.GetCVarInfo(name)
  if value == nil or not perCharacter or locked or secure or readOnly then return nil end
  return value
end

local function BarsForced()
  return C_GameRules and C_GameRules.IsMultiActionBarVisibilityForced and C_GameRules.IsMultiActionBarVisibilityForced()
end

local function ReadBars()
  local bars = {}
  if not GetActionBarToggles or BarsForced() then return bars end
  local n = min(select("#", GetActionBarToggles()), BARS_MAX)
  for i = 1, n do bars[i] = (select(i, GetActionBarToggles())) and true or false end
  return bars
end

-- Edit Mode's layouts, the presets first (as its own list has them), and the one in use.
local function Layouts()
  local manager = EditModeManagerFrame
  local info = manager and manager.layoutInfo
  if type(info) ~= "table" or type(info.layouts) ~= "table" then return nil end
  return info.layouts, info.activeLayout
end

local function LayoutKind(name)
  return Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType[name]
end

local function ReadLayout()
  local layouts, active = Layouts()
  local layout = layouts and active and layouts[active]
  if type(layout) ~= "table" or type(layout.layoutType) ~= "number" or type(layout.layoutName) ~= "string" then return nil end
  local preset = layout.layoutType == LayoutKind("Preset")
  return { kind = layout.layoutType, name = layout.layoutName, index = preset and active or nil }
end

---------------------------------------------------------------------------
-- Profiles
---------------------------------------------------------------------------
function ns:AltProfileNames()
  local names = {}
  local store = Store()
  if store then for name in pairs(store.profiles) do names[#names + 1] = name end end
  table.sort(names, function(a, b) return a:lower() < b:lower() end)
  return names
end

function ns:AltDefault()
  local store = Store()
  return store and store.default
end

function ns:SetAltDefault(name)
  local store = Store()
  if not store then return end
  store.default = name ~= nil and store.profiles[name] and name or nil
  if self.RefreshOptions then self:RefreshOptions() end
end

function ns:AltProfile(name)
  local store = Store()
  return store and name and store.profiles[name]
end

-- A name for a new profile: trimmed, not longer than limit letters (default: the most); nil if empty.
function ns:AltProfileName(text, limit)
  if type(text) ~= "string" then return nil end
  text = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("[|\n\r]", "")
  if text == "" then return nil end
  local chars = {}
  for ch in text:gmatch("[%z\1-\127\192-\255][\128-\191]*") do
    if #chars == (limit or NAME_MAX) then break end
    chars[#chars + 1] = ch
  end
  return table.concat(chars)
end

-- The current character's settings into a profile (made if new), which becomes the alts' one.
-- Returns the profile.
function ns:SaveAltProfile(name)
  local store = Store()
  name = self:AltProfileName(name)
  if not (store and name) then return nil end
  local cvars = {}
  for variable in pairs(AllVariables()) do
    local value = OwnValue(variable)
    if value ~= nil then cvars[variable] = value end
  end
  local who = UnitName and UnitName("player")
  local realm = GetRealmName and GetRealmName()
  local profile = { cvars = cvars, bars = ReadBars(), layout = ReadLayout(), bindings = ReadBindings(),
    chars = ReadChars(), ace = ReadAce(),
    from = who and (realm and realm ~= "" and (who .. " - " .. realm) or who) or nil, when = time and time() or nil }
  store.profiles[name] = profile
  store.default = name
  local me = Me()
  if me then store.done[me] = true end -- (its own settings already)
  if self.RefreshOptions then self:RefreshOptions() end
  return profile
end

-- Saved, and said once in the chat with what it holds.
function ns:SaveAltProfileSay(name)
  local profile = self:SaveAltProfile(name)
  if not profile then return nil end
  local lines = self:AltSummary(name) or {}
  self.Print(L.ALTS_SAVED:format(name) .. " " .. table.concat(lines, " · ", 1, min(2, #lines)))
  return profile
end

-- Saved once the interface is reloaded (changes waiting for a reload take effect first, and are written).
local AFTER_WINDOW = 900 -- (seconds: a save asked for longer ago than this is dropped)
function ns:SaveAltProfileAfterReload(name)
  local store, me = Store(), Me()
  if not (store and me) then return false end
  store.after = { name = name, who = me, when = time and time() or 0 }
  if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end
  return true
end

function ns:DeleteAltProfile(name)
  local store = Store()
  if not (store and name and store.profiles[name]) then return end
  store.profiles[name] = nil
  if store.default == name then store.default = nil end
  if self.RefreshOptions then self:RefreshOptions() end
end

-- One line of text holding a profile, to paste on another account (Profiles.lua's text form).
function ns:ExportAltProfile(name)
  local p = self:AltProfile(name)
  if not (p and self.Serialize and self.Encode64) then return nil end
  return EXPORT_PREFIX .. self.Encode64(self.Serialize({ v = 1, name = name, data = p }))
end

-- Reads an exported line into a new profile (its own name, or a numbered one if taken), which
-- becomes the alts' one. Returns true and the name, or false and why.
function ns:ImportAltProfile(text)
  local store = Store()
  if not store or type(text) ~= "string" then return false, L.ALTS_IMPORT_BAD end
  text = text:gsub("%s", "")
  if #text > MAX_IMPORT or text:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then return false, L.ALTS_IMPORT_BAD end
  local raw = self.Decode64 and self.Decode64(text:sub(#EXPORT_PREFIX + 1))
  local t = raw and self.Deserialize and self.Deserialize(raw)
  local data = type(t) == "table" and t.v == 1 and CleanProfile(t.data)
  if not data then return false, L.ALTS_IMPORT_BAD end
  local base = self:AltProfileName(t.name) or L.ALTS_IMPORTED
  local name = base
  for n = 2, 999 do
    if not store.profiles[name] then break end
    local suffix = " (" .. n .. ")"
    name = (self:AltProfileName(base, NAME_MAX - #suffix) or base) .. suffix
  end
  if store.profiles[name] then return false, L.ALTS_IMPORT_BAD end
  store.profiles[name] = data
  store.default = name
  if self.RefreshOptions then self:RefreshOptions() end
  return true, name
end

-- What a profile holds, in a few lines (the header's tooltip, the chat once saved).
function ns:AltSummary(name)
  local p = self:AltProfile(name)
  if not p then return nil end
  local options = 0
  for _ in pairs(p.cvars) do options = options + 1 end
  local shown = 0
  for _, on in ipairs(p.bars) do if on then shown = shown + 1 end end
  local lines = { L.ALTS_HOLDS:format(shown, #p.bars, options) }
  local addons = 0
  for _ in pairs(p.ace or {}) do addons = addons + 1 end
  for _ in pairs(p.chars or {}) do addons = addons + 1 end
  local keys = p.bindings and #p.bindings.list or 0
  if keys > 0 or addons > 0 then lines[#lines + 1] = L.ALTS_HOLDS_MORE:format(keys, addons) end
  if p.layout then lines[#lines + 1] = L.ALTS_HOLDS_LAYOUT:format(p.layout.name) end
  if p.layout and p.layout.kind == LayoutKind("Character") then lines[#lines + 1] = L.ALTS_LAYOUT_OWN end
  if p.from then
    local when = p.when and date and date("%Y-%m-%d", p.when)
    lines[#lines + 1] = when and L.ALTS_FROM_WHEN:format(p.from, when) or L.ALTS_FROM:format(p.from)
  end
  return lines
end

---------------------------------------------------------------------------
-- A profile put on this character
---------------------------------------------------------------------------
local function ApplyBars(bars)
  if #bars == 0 or not (SetActionBarToggles and GetActionBarToggles) or BarsForced() then return end
  local n = max(#bars, select("#", GetActionBarToggles()))
  local set, changed = {}, false
  for i = 1, n do
    local now = (select(i, GetActionBarToggles())) and true or false
    if bars[i] == nil then set[i] = now else set[i] = bars[i] end
    if set[i] ~= now then changed = true end
  end
  if changed then SetActionBarToggles(unpack(set, 1, n)) end
end

local function ApplyOptions(cvars)
  for name, value in pairs(cvars) do
    local now = OwnValue(name)
    if now ~= nil and now ~= value then C_CVar.SetCVar(name, value) end
  end
end

-- Its key bindings as this character's own (the keys not in it unbound), out of combat
local function ApplyBindings(b)
  if not (b and b.list and SetBinding and GetNumBindings and GetBinding) then return false end
  if InCombatLockdown and InCombatLockdown() then return false end
  local want = {}
  for _, e in ipairs(b.list) do
    for j = 2, #e do want[e[j]] = e[1] end
  end
  for i = 1, GetNumBindings() do
    local t = { GetBinding(i) }
    for j = 3, #t do
      local key = t[j]
      if type(key) == "string" and key ~= "" and want[key] == nil then SetBinding(key) end
    end
  end
  for key, command in pairs(want) do SetBinding(key, command) end
  if SaveBindings then SaveBindings(CHARACTER_BINDINGS or 2) end
  return true
end

-- Clara's modules' per-character settings (in use after the reload offered)
local function ApplyChars(chars)
  for name, v in pairs(chars or {}) do _G[name] = Copy(v) end
end

-- Each addon's AceDB profile: a shared one used as it is (made if this account has none of that name),
-- the other character's own copied as this character's own
local function ApplyAce(ace)
  local me = AceKey()
  if not me then return end
  for name, a in pairs(ace or {}) do
    local sv = rawget(_G, name)
    local keys, profiles = type(sv) == "table" and rawget(sv, "profileKeys"), type(sv) == "table" and rawget(sv, "profiles")
    if type(keys) == "table" and type(profiles) == "table" then
      if a.mine then
        profiles[me] = Copy(a.data)
        keys[me] = me
      else
        if type(profiles[a.key]) ~= "table" then profiles[a.key] = Copy(a.data) end
        keys[me] = a.key
      end
    end
  end
end

-- The layout of the same name (a preset: the same one); a layout of the other character only
-- is not there. Returns whether it is in use now.
local function ApplyLayout(want)
  local layouts, active = Layouts()
  if not (want and layouts and C_EditMode and C_EditMode.SetActiveLayout) then return false end
  local target
  if want.kind == LayoutKind("Preset") then
    local l = want.index and layouts[want.index]
    if l and l.layoutType == want.kind then target = want.index end
  else
    for i, l in ipairs(layouts) do
      if l.layoutName == want.name and l.layoutType ~= LayoutKind("Preset") then target = i break end
    end
  end
  if not target then return false end
  if target ~= active then C_EditMode.SetActiveLayout(target) end
  return true
end

local pending -- a profile to put on this character once out of combat and Edit Mode ready
local waiter = CreateFrame("Frame")
local reloadDue -- a profile put on this session, the reload it asked for not done yet
ns:AddReloadCheck(function() return reloadDue and L.ALTS_RELOAD_PROFILE:format(reloadDue) end)

local function Finish(name, asked)
  local p = ns:AltProfile(name)
  if not p then return end
  ApplyOptions(p.cvars)
  ApplyBars(p.bars)
  local layoutDone = ApplyLayout(p.layout)
  ApplyBindings(p.bindings)
  ApplyChars(p.chars)
  ApplyAce(p.ace)
  local store, me = Store(), Me()
  if store and me then store.done[me] = true end
  if ns.RefreshOptions then ns:RefreshOptions() end
  reloadDue = name
  local text = (asked and L.ALTS_APPLIED_ASK or L.ALTS_GOT_ASK):format(name)
  if p.layout and not layoutDone then text = text .. "\n\n" .. L.ALTS_LAYOUT_MISSING:format(p.layout.name) end
  local function Ask()
    ns:Ask(text, false, { L.RELOAD_UI, function()
      if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end
    end }, { L.ALTS_LATER })
  end
  -- (after the dialog that asked for it, if any, is gone: the game's dialogs are reused)
  if C_Timer and C_Timer.After then C_Timer.After(0, Ask) else Ask() end
end

local function TryPending()
  if not pending then return end
  if InCombatLockdown and InCombatLockdown() then
    waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  if pending.layout and not Layouts() then -- (Edit Mode not set up yet: its first layouts update)
    waiter:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    return
  end
  local job = pending
  pending = nil
  waiter:UnregisterAllEvents()
  Finish(job.name, job.asked)
end
waiter:SetScript("OnEvent", function()
  if C_Timer and C_Timer.After then C_Timer.After(0, TryPending) else TryPending() end
end)

-- asked: put on by hand (the header), rather than a new character's first login.
function ns:ApplyAltProfile(name, asked)
  local p = self:AltProfile(name)
  if not p then return false end
  pending = { name = name, asked = asked, layout = p.layout ~= nil }
  TryPending()
  return true
end

-- A new character's first login: the alts' profile, once. And a save asked for before the reload.
function ns:AltsAtLogin()
  local store, me = Store(), Me()
  local after = store and store.after
  if after then
    store.after = nil
    local fresh = time and (time() - after.when) <= AFTER_WINDOW
    if after.who == me and fresh then
      local function Save() ns:SaveAltProfileSay(after.name) end
      if C_Timer and C_Timer.After then C_Timer.After(3, Save) else Save() end -- (Edit Mode and the game's settings in place)
    end
  end
  if not (store and me and store.default) or store.done[me] then return end
  local level = UnitLevel and UnitLevel("player")
  if type(level) ~= "number" or level < 1 or level > NEW_LEVEL then return end
  local name = store.default
  local function Go() ns:ApplyAltProfile(name, false) end
  if C_Timer and C_Timer.After then C_Timer.After(2, Go) else Go() end -- (the game's own settings in place first)
end
