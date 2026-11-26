-- Clara Combo Points - profession cooldowns in the Professions micro button's tooltip: the Salt Shaker (leatherworking),
-- Mooncloth (tailoring) and every transmute (alchemy: Classic's, and WoW Forever's own found by their name), each with
-- the time left or "ready". This character's; Shift held (pressed or let go while it shows: drawn again), every one of
-- the player's characters that has one, its WoW account named: those of this WoW account, and those of the player's
-- other WoW accounts the sync brings (Sync.lua: only the player's own, never a friend's). They are kept in the gold
-- tracker's record of each character (ClaraMoneyDB, Modules/Money), which the sync already carries; without the gold
-- tracker, this character's alone. Read from the game: a recipe's own cooldown while the professions window shows it
-- (the sure one), the spell's cooldown at login and after a cast, the Salt Shaker's in the bags. Transmutes sharing one
-- time: one line. A box on Clara's page (on by default).

local ADDON, ns = ...
local L = ns.L

local issecret = issecretvalue or function() return false end
local floor, max = math.floor, math.max

-- The spells followed: 0 Mooncloth, 1 a transmute (more transmutes found by their name in the professions window)
local SPELLS = {
  [18560] = 0, -- Mooncloth
  [11479] = 1, [11480] = 1, [17187] = 1, [17559] = 1, [17560] = 1, [17561] = 1, [17562] = 1, [17563] = 1,
  [17564] = 1, [17565] = 1, [17566] = 1, [25146] = 1,
}
local SALT_SHAKER = 15846
local CHANGE = 60 -- seconds: a time this close to the one kept, the same

local P = {}
ns.ProfCD = P

function ns:ProfCooldowns() return not (self.sv and self.sv.profCooldowns == false) end
function ns:SetProfCooldowns(on)
  if not self.sv then return end
  if on then self.sv.profCooldowns = nil else self.sv.profCooldowns = false end
end

---------------------------------------------------------------------------
-- This character's, as read: { [key] = { e = when ready (time(); 0 ready), g = 1 a transmute } }
---------------------------------------------------------------------------
local live = {}
local extra = {} -- (transmutes found by their name: [spell] = 1)
P.live = live

local function Money() return ns.Money and ns.Money.db and ns.Money or nil end

local function MyKey()
  local G = Money()
  if G and G.Me then return (G.Me()) end
  local name = UnitName and UnitName("player")
  if type(name) ~= "string" or issecret(name) then return nil end
  return name .. "-" .. ((GetNormalizedRealmName and GetNormalizedRealmName()) or "")
end

local function Clean(t)
  local G = Money()
  if G and G.CleanTimers then return G.CleanTimers(t) end
  return next(t) and t or nil
end

-- Kept in the gold tracker's record (sent by the sync when it changes)
local function Same(a, b)
  a, b = a or {}, b or {}
  for k, v in pairs(a) do
    local w = b[k]
    if not w or math.abs((w.e or 0) - (v.e or 0)) >= CHANGE or w.g ~= v.g then return false end
  end
  for k in pairs(b) do if not a[k] then return false end end
  return true
end

local function Save()
  local G = Money()
  local key = MyKey()
  if not (G and key) then return end
  local rec = G.db.chars[key]
  if not rec and G.Record then G.Record(); rec = G.db.chars[key] end
  if not rec then return end
  if Same(rec.t, live) then return end
  rec.t = Clean(live)
  rec.at = time()
  if G.Touched then G.Touched("g", key) end
end

-- A time left (seconds) for a key; sure: the game's own answer for it (a recipe's, an item's), else a spell's 0 does
-- not undo a time known
local function Put(key, left, g, sure)
  if type(left) ~= "number" then return end
  local now = time()
  local old = live[key]
  if left <= 0 then
    if not sure and old and old.e > now then return end
    live[key] = { e = 0, g = g }
  else
    live[key] = { e = floor(now + left + 0.5), g = g }
  end
end

---------------------------------------------------------------------------
-- Read from the game
---------------------------------------------------------------------------
local function Known(id)
  local ok, yes = pcall(function() return IsPlayerSpell and IsPlayerSpell(id) end)
  if ok and yes == true then return true end
  ok, yes = pcall(function() return C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id) end)
  return ok and yes == true
end

-- A cooldown's seconds left from the game's start and duration. A cooldown begun before the computer was started has a
-- start below 0, or one past now (the game's clock wrapped round its 2^32 milliseconds): both counted as they are meant
local WRAP = 4294967.296
local function Left(start, dur)
  if type(start) ~= "number" or type(dur) ~= "number" or dur <= 2 or start == 0 then return 0 end
  local now = GetTime()
  if start > now then start = start - WRAP end
  return max(0, start + dur - now)
end
P.Left = Left

-- A spell's time left (seconds), 0 ready, nil not told
local function SpellLeft(id)
  if not (C_Spell and C_Spell.GetSpellCooldown) then return nil end
  local ok, start, dur = pcall(function()
    local info = C_Spell.GetSpellCooldown(id)
    return info.startTime, info.duration
  end)
  if not ok or issecret(start) or issecret(dur) or type(start) ~= "number" or type(dur) ~= "number" then return nil end
  return Left(start, dur)
end

local function TransmutePrefix()
  local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(11479)
  if type(name) ~= "string" or issecret(name) then return nil end
  return name:match("^(.-)%s*:")
end

-- The spells this character may know: Classic's, those found by name, those kept
local function Followed()
  local list = {}
  for id, g in pairs(SPELLS) do list[id] = g end
  for id in pairs(extra) do list[id] = 1 end
  for key, v in pairs(live) do
    local id = tonumber(key:match("^s(%d+)$"))
    if id and list[id] == nil then list[id] = v.g == 1 and 1 or 0 end
  end
  return list
end

-- At login, after a cast, as cooldowns change: the spells known, the Salt Shaker in the bags (not in a fight: the game
-- hides cooldowns then)
function P.Scan()
  if InCombatLockdown and InCombatLockdown() then return end
  for id, g in pairs(Followed()) do
    local key = "s" .. id
    if Known(id) or live[key] then
      local left = SpellLeft(id)
      if left then Put(key, left, g == 1 and 1 or nil, false)
      elseif not live[key] then Put(key, 0, g == 1 and 1 or nil, false) end
    end
  end
  local count = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(SALT_SHAKER, true) or 0
  if type(count) == "number" and count > 0 and C_Container and C_Container.GetItemCooldown then
    local start, dur = C_Container.GetItemCooldown(SALT_SHAKER)
    if type(start) == "number" and type(dur) == "number" and not issecret(start) and not issecret(dur) then
      Put("i" .. SALT_SHAKER, Left(start, dur), nil, true)
    end
  elseif type(count) == "number" and count == 0 then
    live["i" .. SALT_SHAKER] = nil
  end
  Save()
end

-- The professions window open: its recipes' own cooldowns (the sure ones), transmutes found by their name
function P.ScanRecipes()
  local T = C_TradeSkillUI
  if not (T and T.GetAllRecipeIDs and T.GetRecipeInfo and T.GetRecipeCooldown) then return end
  local ok, ids = pcall(T.GetAllRecipeIDs)
  if not ok or type(ids) ~= "table" then return end
  local prefix = TransmutePrefix()
  for _, id in ipairs(ids) do
    local g = SPELLS[id] or extra[id]
    if g == nil and prefix then
      local okN, info = pcall(T.GetRecipeInfo, id)
      local name = okN and type(info) == "table" and info.name
      if type(name) == "string" and not issecret(name) and name:sub(1, #prefix) == prefix and name:sub(#prefix + 1, #prefix + 1):match("[%s:]") then
        g = 1
        extra[id] = 1
      end
    end
    if g ~= nil then
      local okI, info = pcall(T.GetRecipeInfo, id)
      if okI and type(info) == "table" and info.learned then
        local okC, cd = pcall(T.GetRecipeCooldown, id)
        local left = okC and type(cd) == "number" and not issecret(cd) and cd or 0
        Put("s" .. id, left, g == 1 and 1 or nil, true)
      end
    end
  end
  Save()
end

---------------------------------------------------------------------------
-- The tooltip
---------------------------------------------------------------------------
local function Remaining(e) return max(0, (e or 0) - time()) end

local function Format(sec)
  if sec <= 0 then return L.PCD_READY end
  local d, h, m = floor(sec / 86400), floor(sec % 86400 / 3600), floor(sec % 3600 / 60)
  if d > 0 then return L.PCD_DAYS:format(d, h) end
  if h > 0 then return L.PCD_HOURS:format(h, m) end
  return L.PCD_MINUTES:format(max(1, m))
end
P.Format = Format

local function Label(key)
  local kind, id = key:match("^(%a)(%d+)$")
  id = tonumber(id)
  if kind == "i" then
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    return type(name) == "string" and not issecret(name) and name or L.PCD_SALT
  end
  local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
  return type(name) == "string" and not issecret(name) and name or ("#" .. tostring(id))
end

-- A character's lines: { label, seconds left }; transmutes sharing one time on one line
function P.Lines(t)
  local out, trans = {}, {}
  for key, v in pairs(t or {}) do
    if v.g == 1 then trans[#trans + 1] = { key = key, left = Remaining(v.e) }
    else out[#out + 1] = { Label(key), Remaining(v.e) } end
  end
  local groups, order = {}, {}
  for _, x in ipairs(trans) do
    local m = math.ceil(x.left / 60)
    if not groups[m] then groups[m] = {}; order[#order + 1] = m end
    table.insert(groups[m], x)
  end
  table.sort(order)
  for _, m in ipairs(order) do
    local list = groups[m]
    local label
    if #trans == 1 then label = Label(list[1].key)
    elseif #order == 1 then label = L.PCD_TRANSMUTES
    elseif #list == 1 then label = Label(list[1].key)
    else label = L.PCD_TRANSMUTES .. " (" .. #list .. ")" end
    out[#out + 1] = { label, list[1].left }
  end
  table.sort(out, function(a, b) return a[1] < b[1] end)
  return out
end

local function ClassHex(class)
  local color = class and ((C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class))
    or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
  if not color then return "ffffffff" end
  if color.GenerateHexColor then return color:GenerateHexColor() end
  return ("ff%02x%02x%02x"):format(floor((color.r or 1) * 255), floor((color.g or 1) * 255), floor((color.b or 1) * 255))
end

-- Every character with a cooldown: this one first, then this WoW account's, then the others' (by account, by name)
local function Characters()
  local G, me = Money(), MyKey()
  local list = {}
  if G then
    for key, rec in pairs(G.db.chars) do
      if key ~= me and type(rec) == "table" and type(rec.t) == "table" and next(rec.t) then
        list[#list + 1] = { key = key, rec = rec }
      end
    end
    local here = G.db.me
    table.sort(list, function(a, b)
      local ha, hb = a.rec.a == here, b.rec.a == here
      if ha ~= hb then return ha end
      if a.rec.a ~= b.rec.a then
        return tostring(G.AccountName and G.AccountName(a.rec.a) or a.rec.a) < tostring(G.AccountName and G.AccountName(b.rec.a) or b.rec.a)
      end
      return tostring(a.rec.n) < tostring(b.rec.n)
    end)
  end
  return list
end
P.Characters = Characters

local function Shift() return IsShiftKeyDown and IsShiftKeyDown() and true or false end

local function Rows(tip, t, indent)
  for _, line in ipairs(P.Lines(t)) do
    local ready = line[2] <= 0
    tip:AddDoubleLine((indent or "") .. line[1], Format(line[2]), 1, 1, 1, ready and 0.25 or 1, ready and 1 or 1, ready and 0.25 or 1)
  end
end

function P.AddTo(tip)
  if not (tip and ns:ProfCooldowns()) then return end
  local others = Characters()
  local mine = next(live) and live or nil
  if not mine and #others == 0 then return end
  tip:AddLine(" ")
  tip:AddLine(L.PCD_TITLE, 1, 0.82, 0)
  if not Shift() then
    if mine then Rows(tip, mine) else tip:AddLine(L.PCD_NONE, 0.6, 0.6, 0.6) end
    if #others > 0 then tip:AddLine(L.PCD_SHIFT_HINT, 0.5, 0.5, 0.5) end
  else
    local G = Money()
    local _, class = UnitClass("player")
    local myName = ns.FullName and ns:FullName("player") or UnitName("player")
    if mine then
      tip:AddLine(("|c%s%s|r"):format(ClassHex(class), tostring(myName)))
      Rows(tip, mine, "   ")
    end
    for _, c in ipairs(others) do
      local name = G and G.FullName and G.FullName(c.rec) or c.rec.n
      local account = G and G.db.me ~= c.rec.a and G.AccountName and G.AccountName(c.rec.a) or nil
      tip:AddDoubleLine(("|c%s%s|r"):format(ClassHex(c.rec.c), tostring(name)), account or "", 1, 1, 1, 0.6, 0.6, 0.6)
      Rows(tip, c.rec.t, "   ")
    end
  end
  tip:Show()
end

-- The micro menu's Professions button (the hammer): the game's own name, else the one whose tooltip says Professions
local function Button()
  local b = _G.ProfessionMicroButton
  if type(b) == "table" then return b end
  local want = type(PROFESSIONS_BUTTON) == "string" and PROFESSIONS_BUTTON or nil
  for _, f in ipairs(type(MICRO_BUTTONS) == "table" and MICRO_BUTTONS or {}) do
    local x = type(f) == "string" and _G[f] or f
    if type(x) == "table" and want and type(x.tooltipText) == "string" and x.tooltipText:find(want, 1, true) then return x end
  end
end
P.Button = Button

-- The button's tooltip drawn again (Shift pressed or let go while it shows)
local function Redraw()
  local b = Button()
  if not (b and GameTooltip and GameTooltip:IsShown() and GameTooltip:IsOwned(b)) then return end
  if b.EvaluateTooltipVisibility then pcall(b.EvaluateTooltipVisibility, b) else GameTooltip:ClearLines() end
  P.AddTo(GameTooltip)
end
P.Redraw = Redraw

local hooked = false
local function Hook()
  local b = Button()
  if hooked or not (b and b.HookScript) then return end
  hooked = true
  b:HookScript("OnEnter", function(self)
    pcall(P.Scan) -- (read again as it is hovered: the bags' and spells' times as they are now)
    if GameTooltip and GameTooltip:IsOwned(self) then P.AddTo(GameTooltip) end
  end)
end

-- /cl souris
function ns:ProfCooldownsReport()
  local n, keys = 0, {}
  for key, v in pairs(live) do n = n + 1; keys[#keys + 1] = key .. "=" .. Format(Remaining(v.e)) end
  table.sort(keys)
  return ("profession cooldowns: on %s, hooked %s, this character %d (%s), other characters with some %d, kept in the gold tracker %s"):format(
    tostring(self:ProfCooldowns()), tostring(hooked), n, table.concat(keys, ", "), #Characters(), tostring(Money() ~= nil))
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local wait = false
local function Soon(fn, delay)
  if wait then return end
  wait = true
  C_Timer.After(delay or 1, function() wait = false; fn() end)
end

local events = CreateFrame("Frame")
-- (a character with none of these cooldowns: the cooldown events not even heard)
local function Listen()
  local on = next(live) ~= nil
  for _, e in ipairs({ "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN" }) do
    if on then pcall(events.RegisterEvent, events, e) else pcall(events.UnregisterEvent, events, e) end
  end
end
local scan = P.Scan
function P.Scan() scan(); Listen() end
local scanRecipes = P.ScanRecipes
function P.ScanRecipes() scanRecipes(); Listen() end

local started = false
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, a, _, c)
  if event == "PLAYER_LOGIN" then
    Hook()
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "UNIT_SPELLCAST_SUCCEEDED",
      "MODIFIER_STATE_CHANGED" }) do
      pcall(self.RegisterEvent, self, e)
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    if started then return end
    started = true
    C_Timer.After(3, function()
      -- (what was kept for this character: its last times; the gold tracker's data ready by now)
      local G, key = Money(), MyKey()
      local rec = G and key and G.db.chars[key]
      if rec and type(rec.t) == "table" then
        for k, v in pairs(rec.t) do if not live[k] then live[k] = { e = v.e, g = v.g } end end
      end
      P.Scan()
    end)
  elseif event == "MODIFIER_STATE_CHANGED" then
    if a == "LSHIFT" or a == "RSHIFT" then Redraw() end
  elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then
    Soon(P.ScanRecipes, 0.5)
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    if a == "player" and not issecret(c) and (SPELLS[c] or extra[c] or live["s" .. tostring(c)]) then
      C_Timer.After(1, function() P.ScanRecipes(); P.Scan() end)
    end
  else
    Soon(P.Scan, 2)
  end
end)
