-- ClassicUI Forever built in: the three changes, each file loaded alone over stand-ins (lupa, Lua 5.1).
local ADDON = ...
local MOD = ADDON .. "/Modules/ClassicUI/"
local function readfile(p) local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return s end
local fails = 0
local function check(c, m) print((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

-- a stand-in that answers anything (a function returning a stand-in, or a field)
local anymeta
local function Any(name) return setmetatable({ __name = name }, anymeta) end
anymeta = { __index = function(t, k) local v = Any(k) rawset(t, k, v) return v end, __call = function() return Any("call") end }

local function Load(file, ns, env)
  env = env or {}
  setmetatable(env, { __index = function(t, k) local v = rawget(_G, k) if v ~= nil then return v end return Any(k) end })
  local fn = assert(loadstring(readfile(MOD .. file), "@" .. file))
  setfenv(fn, env)
  fn("ClaraComboPoints", { ClassicUIRuns = true, ClassicUIPrivate = ns })
  return env
end

-- a region keeping its anchors
local function Region(name)
  local r = { name = name, points = {} }
  function r:ClearAllPoints() self.points = {} end
  function r:SetPoint(p, rel, rp, x, y) self.points[p] = { rel, rp, x, y } end
  function r:SetParent() end function r:SetDrawLayer() end function r:SetWidth() end function r:SetSize() end
  function r:GetSize() return 128, 64 end function r:GetPoint() return "TOPLEFT", nil, "TOPLEFT", 0, -10 end
  return r
end

print("== the party portraits' debuff ring (Units/PartyPetFrames.lua)")
do
  local ns = setmetatable({}, anymeta)
  ns.Path = function(t, ...) for _, k in ipairs({ ... }) do t = type(t) == "table" and t[k] or nil end return t end
  ns.SetPointOnce = function(r, ...) r:ClearAllPoints() r:SetPoint(...) end
  ns.Dress, ns.FadeKeys, ns.Near = function() end, function() end, function(a, b) return math.abs(a - b) < 1 end
  ns.IsSecret = function() return false end
  ns.AnySecret = function() return false end
  local UF = setmetatable({ frames = {}, taken = {}, active = true }, anymeta)
  for _, k in ipairs({ "Update", "Host", "BarBg", "Cover", "BarTexts", "AttachOverlays", "KeepBar", "HideHost", "DressGlow" }) do
    UF[k] = function() return Any(k) end
  end
  UF.On = function() return true end
  UF.Busy = function() return false end
  ns.UF = UF
  ns.CreateBar = function() local b = Region("bar") function b:SetStatusBarColor() end return b end
  ns.OwnFrame = function() return Region("art") end
  local frame = Region("party1")
  frame.unit = "party1"
  function frame:GetFrameLevel() return 3 end
  frame.Portrait, frame.Texture, frame.Name = Region("Portrait"), Region("Texture"), Region("Name")
  local status = Region("Status")
  frame.PartyMemberOverlay = { Status = status }
  local env = { PartyFrame = { PartyMemberFramePool = { GetNumActive = function() return 1 end,
    EnumerateActive = function() local done return function() if not done then done = true return frame end end end } } }
  Load("Units/PartyPetFrames.lua", ns, env)
  UF.SkinParty()
  local p = status.points.TOPLEFT
  check(p and p[1] == frame.Portrait and p[3] == -8 and p[4] == 5, "skinned: the ring on the portrait, where the game had it (-8, 5 of it)")
  local pp = frame.Portrait.points.TOPLEFT
  check(pp and pp[3] == 7 and pp[4] == -14, "the portrait itself at 7, -14 (the game's at 7, -6: 8 lower)")
  -- the game lays its art again (a level up in the group, a join in a fight): its anchor back, then ours again
  status:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, -1)
  frame.Texture.GetAtlas = function() return "UI-HUD-UnitFrame-Party-PortraitOn" end
  UF.frames[frame] = UF.frames[frame] or {}
  UF.KeepParty()
  p = status.points.TOPLEFT
  check(p and p[1] == frame.Portrait, "the game's art laid again: the ring back on the portrait")
  UF.taken.party = true
  UF.RestoreParty()
  p = status.points.TOPLEFT
  check(p and p[1] == frame and p[3] == -1 and p[4] == -1, "restored: the game's own spot")
end

print("== the Who list's menu (Social/WhoList.lua)")
do
  local ns = setmetatable({ db = {}, L = setmetatable({}, { __index = function(_, k) return k end }) }, anymeta)
  ns.IsSecret, ns.Safe = function() return false end, function(v, d) if v == nil then return d end return v end
  local S = setmetatable({}, anymeta)
  ns.social = S
  S.WhoFilterEntries = function()
    return { { "Class", sub = function() return {} end }, { "Race", sub = function() return {} end }, { "Zone", sub = function() return {} end } }
  end
  local header
  S.HeaderRow = function(panel, host, columns, onClick, arrow)
    header = setmetatable({ Text = { SetText = function(self, t) self.text = t end }, GetHeight = function() return 24 end }, anymeta)
    arrow(header, { key = "zone" })
    return Any("headerRow")
  end
  local arrowButton
  ns.NewFrame = function(kind, name, parent)
    local f = setmetatable({ scripts = {} }, anymeta)
    f.SetScript = function(self, ev, fn) self.scripts[ev] = fn end
    if parent == header then arrowButton = f end
    return f
  end
  local entries
  ns.TreeMenu = function(e) entries = e return setmetatable({}, anymeta) end
  local applied
  ns.RegisterModule = function(name, m) if name == "whoList" then applied = m end end
  ns.WhenCalm = function(_, fn) fn() end
  ns.EventFrame = function() return setmetatable({}, anymeta) end
  ns.ListOffset = function() return 0 end
  S.RowCount = function() return 0 end
  S.NewPanel = function() local p = setmetatable({ rows = {} }, anymeta) p.IsShown = function() return false end return p end
  local env = { FriendsFrame = setmetatable({}, anymeta), CLASS = "Class", GUILD = "Guild", ZONE = "Zone", RACE = "Race",
    NAME = "Name", LEVEL = "Level", WHO_SORT_LABEL = "Sort By", UnitName = function() return "Me" end }
  Load("Social/WhoList.lua", ns, env)
  applied.apply()
  check(arrowButton and arrowButton.scripts.OnClick, "the arrow on the middle column's header")
  arrowButton.scripts.OnClick()
  local labels = {}
  for _, e in ipairs(entries or {}) do labels[#labels + 1] = e[1] end
  check(table.concat(labels, ", ") == "Class, Race, Zone, Guild, Sort By", "the menu: " .. table.concat(labels, ", "))
  local class, race, zone, guild = entries[1], entries[2], entries[3], entries[4]
  check(class.sub and class.pick and class.radio and race.sub and race.pick and zone.sub and zone.pick, "Class, Race, Zone: a click sorts, their filters on hover")
  check(not guild.sub and guild.pick, "Guild: a click, no filters")
  race.pick()
  check(ns.db.whoColumn == "race" and header.Text.text == "Race" and race.radio() and not zone.radio() and not class.radio(),
    "Race: the middle column shows the race, sorted by it")
  class.pick()
  check(class.radio() and not race.radio() and ns.db.whoColumn == "race", "Class: sorted by class, the middle column kept")
  zone.pick()
  check(ns.db.whoColumn == "zone" and header.Text.text == "Zone" and zone.radio() and not class.radio(), "Zone: the middle column, sorted by it")
  guild.pick()
  check(ns.db.whoColumn == "guild" and header.Text.text == "Guild" and guild.radio(), "Guild: the middle column, sorted by it")
  check(class.close and race.close and zone.close and guild.close and not entries[5].close,
    "Class, Race, Zone and Guild shut the menu once picked; Sort By opens its submenu")
end

print("== a row with a submenu and a pick (UI/Menus.lua)")
do
  local src = readfile(MOD .. "UI/Menus.lua")
  local body = src:match("local function RowClick%(row%)(.-)\nend")
  check(body and body:find("if entry.sub and not %(entry.toggle or entry.pick or entry.click%) then"), "a click: its pick when it has one, else its submenu")
  check(src:find("if row.entry and row.entry.sub then OpenSub%(level, row%)"), "on hover: its submenu, as before")
  local body2 = src:match("(local function RowClick%(row%).-\nend)")
  local redrawn, opened = 0, 0
  local fn = assert(loadstring("local Redraw, OpenSub = ...\n" .. body2 .. "\nreturn RowClick"))
  setfenv(fn, { PlaySound = function() end, SOUNDKIT = {} })
  local RowClick = fn(function() redrawn = redrawn + 1 end, function() opened = opened + 1 end)
  local root = { shown = true }
  function root:Hide() self.shown = false end
  local level = { root = root }
  local picked = 0
  local function Row(entry) return { entry = entry, GetParent = function() return level end } end
  RowClick(Row({ "Zone", sub = {}, pick = function() picked = picked + 1 end, close = true }))
  check(picked == 1 and not root.shown and redrawn == 0, "a row with close: picked, then the whole menu shut")
  root.shown = true
  RowClick(Row({ "Ascending", pick = function() picked = picked + 1 end }))
  check(picked == 2 and root.shown and redrawn == 1, "a plain pick: the menu kept open, its marks redrawn")
  RowClick(Row({ "Sort By", sub = {} }))
  check(opened == 1 and root.shown, "a submenu row: its submenu opens")
end

print("== the pet's loyalty with its rank (Character/CharacterSheet.lua)")
do
  local src = readfile(MOD .. "Character/CharacterSheet.lua")
  local body = src:match("(local function LoyaltyLine%(name%).-\nend)")
  check(body ~= nil, "LoyaltyLine there")
  local function Strings(file)
    local L = {}
    for k, v in readfile(MOD .. "Locales/" .. file):gmatch('L%["(PET_LOYALTY_[%u_]+)"%] = "([^"]*)"') do L[k] = v end
    return L
  end
  local en = Strings("enUS.lua")
  local function Line(L, name)
    local fn = assert(loadstring(body .. "\nreturn LoyaltyLine(...)"))
    setfenv(fn, { ns = { L = L }, tostring = tostring })
    return fn(name)
  end
  check(Line(en, "Faithful") == "Loyalty rank 5 - Faithful", "Faithful: " .. tostring(Line(en, "Faithful")))
  check(Line(en, "Rebellious") == "Loyalty rank 1 - Rebellious" and Line(en, "Best Friend") == "Loyalty rank 6 - Best Friend",
    "Rebellious 1, Best Friend 6")
  check(Line(en, "Unruly") == "Loyalty rank 2 - Unruly" and Line(en, "Submissive") == "Loyalty rank 3 - Submissive"
    and Line(en, "Dependable") == "Loyalty rank 4 - Dependable", "Unruly 2, Submissive 3, Dependable 4")
  check(Line(en, "Something else") == "Something else", "a name not known: as it is")
  local fr = setmetatable(Strings("frFR.lua"), { __index = en })
  check(Line(fr, "Fidèle") == "Rang de loyauté 5 - Fidèle", "French: " .. tostring(Line(fr, "Fidèle")))
  local it = setmetatable(Strings("itIT.lua"), { __index = en })
  check(Line(it, "Fedele") == "Fedele", "a language without the names: the name as it is")
end

print("== a reputation bar's fill (Character/CharacterLists.lua)")
do
  local src = readfile(MOD .. "Character/CharacterLists.lua")
  local chunk = src:match("(local fillShare = setmetatable.-\nlocal function FitFill%(bar%).-\nend)")
  check(chunk ~= nil, "SizeFill and FitFill there")
  local fn = assert(loadstring(chunk .. "\nreturn fillShare, SizeFill, FitFill"))
  setfenv(fn, { setmetatable = setmetatable, math = math, type = type })
  local fillShare, SizeFill, FitFill = fn()
  local function Bar(width)
    local fill = { shown = true, widths = {} }
    function fill:SetWidth(w) self.width = w; self.widths[#self.widths + 1] = w end
    function fill:Hide() self.shown = false end
    function fill:Show() self.shown = true end
    return { Fill = fill, fcuiInset = 2, GetWidth = function() return width end }
  end
  local function NoZero(bar) for _, w in ipairs(bar.Fill.widths) do if w < 0.5 then return false end end return true end
  local bar = Bar(137)
  fillShare[bar] = 0; FitFill(bar)
  check(not bar.Fill.shown and NoZero(bar), "0/6000: the fill hidden, never sized 0 wide")
  fillShare[bar] = 0.5; FitFill(bar)
  check(bar.Fill.shown and bar.Fill.width == 67.5, "half: shown, half the bar (" .. tostring(bar.Fill.width) .. ")")
  fillShare[bar] = 1; FitFill(bar)
  check(bar.Fill.width == 135, "full: the bar's width less its inset")
  SizeFill(bar, 400)
  check(bar.Fill.width == 135 and bar.Fill.shown, "a width past the bar: kept inside it")
  SizeFill(bar, 0)
  check(not bar.Fill.shown and NoZero(bar), "the client's width 0: hidden")
  local unlaid = Bar(0)
  fillShare[unlaid] = 0.7; FitFill(unlaid)
  check(not unlaid.Fill.shown and NoZero(unlaid), "a row not laid out yet (0 wide): hidden until its size lands")
  check(src:find('if left == 0 and top == 1 and type%(right%) == "number" and right >= 0 and right <= 1 then fillShare%[bar%] = right end'),
    "a row first dressed after the client's update: its share read from the fill's crop")
  check(src:find('Take%(fill, "art", "layer", "size", "points", "masks", "shown"%)'), "its shown state given back with the rest")
end

print("== the hunter's pet icons (Units/PetIcons.lua)")
do
  local now = 1000
  local PetFrame = { left = 100, top = 500, level = 5 }
  setmetatable(PetFrame, { __index = function(_, k)
    if k == "GetLeft" then return function(self) return self.left end end
    if k == "GetTop" then return function(self) return self.top end end
    if k == "GetEffectiveScale" then return function() return 1 end end
    if k == "GetFrameLevel" then return function(self) return self.level end end
    return function() end
  end })
  local made = {}
  local function Region(kind, parent)
    local f = { kind = kind, parent = parent, scripts = {}, shown = true, level = 1 }
    function f:SetSize(w, h) self.w, self.h = w, h end
    function f:SetFrameLevel(l) self.level = l end
    function f:GetFrameLevel() return self.level end
    function f:CreateTexture() local t = Region("Texture", self) function t:SetTexture(x) self.texture = x end return t end
    function f:CreateFontString() local t = Region("FontString", self) function t:SetText(x) self.text = x end return t end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:Hide() self.shown = false end
    function f:Show() self.shown = true end
    function f:SetShown(v) self.shown = v and true or false end
    function f:IsShown() return self.shown end
    function f:SetCooldown(st, d) self.cdStart, self.cdDur = st, d end
    function f:Clear() self.cdStart, self.cdDur = nil, nil end
    function f:GetEffectiveScale() return 1 end
    function f:GetLeft() return self.point and self.point[2] == PetFrame and PetFrame.left + self.point[4] or self.left end
    function f:GetTop() return self.point and self.point[2] == PetFrame and PetFrame.top + self.point[5] or self.top end
    if kind ~= "Texture" and kind ~= "FontString" then made[#made + 1] = f end
    return setmetatable(f, { __index = function() return function() end end })
  end
  local face = Region("Frame", PetFrame)
  face.point = { "LEFT", PetFrame, "RIGHT", 10, 2 }
  face.GetPoint = function(self) return unpack(self.point) end
  local auras, secret = {}, false
  local events, toggles, frames = {}, {}, {}
  local ns = { db = {}, L = setmetatable({}, { __index = function(_, k) return k end }) }
  local inForce = true
  ns.ModuleInForce = function(key) return key == "unitFramePet" and inForce end
  ns.AnySecret = function() return secret end
  ns.SetPointIf = function(r, point, rel, relPoint, x, y) r.point = { point, rel, relPoint, x, y } end
  ns.EventFrame = function(list, fn, unit)
    local f = { on = true }
    function f:UnregisterAllEvents() self.on = false end
    for _, e in ipairs(type(list) == "string" and { list } or list) do events[e] = function(...) if f.on then fn(f, e, ...) end end end
    frames[#frames + 1] = f
    return f
  end
  ns.OnToggle = function(fn) toggles[#toggles + 1] = fn end
  local cursor = { 0, 0 }
  local class = "HUNTER"
  local env = {
    PetFrame = PetFrame, PetFrameHappiness = face,
    CreateFrame = function(kind, _, parent) return Region(kind, parent) end,
    UnitClass = function() return "Hunter", class end, UnitExists = function() return true end,
    GetTime = function() return now end, GetCursorPosition = function() return cursor[1], cursor[2] end,
    C_Spell = { GetSpellName = function() return "Feed Pet Effect" end },
    C_UnitAuras = { GetAuraDataByIndex = function(_, i) return auras[i] end },
    GameTooltip = setmetatable({}, { __index = function() return function() end end }),
  }
  env._G = env
  Load("Units/PetIcons.lua", ns, env)
  local function Toggle(key) for _, fn in ipairs(toggles) do fn(key) end end
  events.PLAYER_LOGIN()
  check(face.point[1] == "LEFT" and face.point[2] == PetFrame and face.point[4] == 1 and face.point[5] == 2,
    "the happiness face 9 left of the game's spot (" .. tostring(face.point[4]) .. ")")
  local feed, feedMover, faceMover
  for _, f in ipairs(made) do
    if f.parent == PetFrame and f.cd then feed = f end
    if f.icon == face then faceMover = f end
  end
  for _, f in ipairs(made) do if f.icon == feed and feed then feedMover = f end end
  check(feed and feed.point[2] == PetFrame and feed.point[4] == 41 and feed.point[5] == -46 and feed.w == 24,
    "the Feed Pet icon: 24 wide, under the bars (41, -46 from the pet frame's top left)")
  check(feed and not feed.shown and feedMover and not feedMover.shown and faceMover and not faceMover.shown, "nothing fed, locked: no icon, no mover")
  -- fed: 17 seconds left of 20
  auras[1] = { spellId = 99, name = "Mark" }
  auras[2] = { spellId = 1539, name = "Feed Pet Effect", duration = 20, expirationTime = now + 17, icon = 132165, auraInstanceID = 7 }
  events.UNIT_AURA("pet")
  check(feed.shown and feed.icon.texture == 132165, "fed: the icon shown, the buff's own picture")
  check(feed.cd.cdStart == now - 3 and feed.cd.cdDur == 20, "its swipe: started 3 s ago, 20 s long")
  feed.scripts.OnUpdate(feed, 0.2)
  check(feed.text.text == "17", "its seconds: 17 (" .. tostring(feed.text.text) .. ")")
  now = now + 5.5
  feed.scripts.OnUpdate(feed, 0.2)
  check(feed.text.text == "12", "5.5 s later: 12 (" .. tostring(feed.text.text) .. ")")
  secret = true
  events.UNIT_AURA("pet")
  check(feed.shown and feed.cd.cdDur == 20, "its aura secret in a fight: kept as it was")
  secret = false
  -- the game says auras are secret (a fight, an encounter): not asked at all; asked anyway, its error caught
  local secretNow, asked = true, 0
  env.C_Secrets = { ShouldAurasBeSecret = function() return secretNow end }
  local realGet = env.C_UnitAuras.GetAuraDataByIndex
  env.C_UnitAuras.GetAuraDataByIndex = function() asked = asked + 1; error("Auras cannot be accessed when secret while tainted") end
  events.UNIT_AURA("pet")
  check(asked == 0 and feed.shown and feed.cd.cdDur == 20, "auras secret: not asked for, the icon kept")
  secretNow = false
  events.UNIT_AURA("pet")
  check(asked == 1 and feed.shown and feed.cd.cdDur == 20, "asked anyway and refused: no error, the icon kept")
  env.C_UnitAuras.GetAuraDataByIndex = realGet
  env.C_Secrets = nil
  check(events.PLAYER_REGEN_ENABLED ~= nil, "the end of a fight watched (its auras read again)")
  events.PLAYER_REGEN_ENABLED()
  check(feed.shown and feed.cd.cdDur == 20, "out of the fight: read again")
  now = now + 12
  feed.scripts.OnUpdate(feed, 0.2)
  check(not feed.shown and feed.text.text == "", "at its end: gone")
  auras[2] = { spellId = 8888, name = "Feed Pet Effect", duration = 20, expirationTime = now + 20, icon = 5 }
  events.UNIT_AURA("pet")
  check(feed.shown, "another spell of that name (the client's own): shown too")
  auras[2] = nil
  events.UNIT_AURA("pet")
  check(not feed.shown, "no feeding: no icon")
  ns.db.petFeedIcon = false
  auras[2] = { spellId = 1539, name = "Feed Pet Effect", duration = 20, expirationTime = now + 20, icon = 5 }
  Toggle("petFeedIcon")
  check(not feed.shown, "Pet feeding timer off: no icon")
  ns.db.petFeedIcon = nil
  auras[2] = nil
  -- unlocked: both movable
  ns.db.petIconsUnlocked = true
  Toggle("petIconsUnlocked")
  check(feedMover.shown and faceMover.shown, "Move the pet's icons: a mover over each")
  check(feed.shown and feed.icon.texture == "Interface\\Icons\\Ability_Hunter_BeastTraining", "the Feed Pet icon shown to be placed")
  -- drag the feed icon: grabbed 9 in, 4 down from its top left (141, 454), dropped 20 right and 20 down
  cursor = { 150, 450 }
  feedMover.scripts.OnDragStart(feedMover)
  cursor = { 170, 430 }
  feedMover.scripts.OnUpdate(feedMover, 0.016)
  feedMover.scripts.OnDragStop(feedMover)
  check(ns.db.petFeedX == 61 and ns.db.petFeedY == -66 and feed.point[4] == 61 and feed.point[5] == -66,
    "dropped: kept at 61, -66 from the pet frame (" .. tostring(ns.db.petFeedX) .. ", " .. tostring(ns.db.petFeedY) .. ")")
  ns.PetIconsApply()
  check(feed.point[4] == 61 and feed.point[5] == -66, "kept at the next pass")
  feedMover.scripts.OnMouseUp(feedMover, "RightButton")
  check(ns.db.petFeedX == nil and feed.point[4] == 41 and feed.point[5] == -46, "right-click: back to its own spot")
  -- drag the face: at 111, 10 from the pet frame's top left (its game spot is off the frame's right), 10 left
  face.GetLeft = function() return 211 end
  face.GetTop = function() return 510 end
  cursor = { 215, 505 }
  faceMover.scripts.OnDragStart(faceMover)
  cursor = { 205, 505 }
  faceMover.scripts.OnUpdate(faceMover, 0.016)
  faceMover.scripts.OnDragStop(faceMover)
  check(ns.db.petFaceX == 101 and ns.db.petFaceY == 10 and face.point[1] == "TOPLEFT" and face.point[2] == PetFrame,
    "the face dropped 10 left: kept from the pet frame's top left (" .. tostring(ns.db.petFaceX) .. ", " .. tostring(ns.db.petFaceY) .. ")")
  -- locked again
  ns.db.petIconsUnlocked = false
  Toggle("petIconsUnlocked")
  check(not feedMover.shown and not faceMover.shown and not feed.shown, "locked: no mover, no Feed Pet icon without feeding")
  check(face.point[1] == "TOPLEFT" and face.point[4] == 101, "the face where it was dropped")
  -- our pet frame off: the face back at the game's spot, nothing watched
  inForce = false
  Toggle("unitFramePet")
  check(face.point[1] == "LEFT" and face.point[4] == 10 and face.point[5] == 2, "pet frame off: the face at the game's own spot")
  local watching = false
  for _, f in ipairs(frames) do if f.on and f ~= frames[1] then watching = true end end
  check(not watching and not feed.shown, "and no pet event watched")
  -- not a hunter: nothing made
  made = {}
  local ns2 = { db = {}, L = ns.L, ModuleInForce = function() return true end, AnySecret = ns.AnySecret, SetPointIf = ns.SetPointIf,
    EventFrame = ns.EventFrame, OnToggle = function() end }
  class = "WARLOCK"
  Load("Units/PetIcons.lua", ns2, env)
  events.PLAYER_LOGIN()
  check(#made == 0, "a warlock: nothing made")
end

print("== the side panel's stat sections, dragged into an order (Character/StatPanes.lua)")
do
  local function StatSession(class, db)
    local function Region(kind)
      local r = { kind = kind, scripts = {}, alpha = 1, h = 0, w = 168, points = {} }
      function r:SetScript(k, fn) self.scripts[k] = fn end
      function r:SetHeight(h) self.h = h end
      function r:GetHeight() return self.h end
      function r:SetWidth(w) self.w = w end
      function r:GetWidth() return self.w end
      function r:SetSize(w, h) self.w, self.h = w, h end
      function r:SetAlpha(a) self.alpha = a end
      function r:ClearAllPoints() self.points = {} end
      function r:SetPoint(p, rel, rp, x, y) self.points = self.points or {} self.points[#self.points + 1] = { p, rel, rp, x, y } end
      function r:CreateTexture() return Region("Texture") end
      function r:CreateFontString() local t = Region("FontString") function t:SetText(x) self.text = x end return t end
      function r:RegisterForDrag(b) self.drag = b end
      function r:GetVerticalScroll() return rawget(self, "vscroll") or 0 end
      function r:SetVerticalScroll(v) self.vscroll = v end
      function r:GetTop() return rawget(self, "top") end
      function r:GetEffectiveScale() return 1 end
      function r:IsVisible() return true end
      return setmetatable(r, { __index = function() return function() end end })
    end
    local ns = setmetatable({ db = db, L = setmetatable({}, { __index = function(_, k) return k end }) }, anymeta)
    ns.NewFrame = function(kind) return Region(kind) end
    ns.RegisterModule = function() end
    ns.IsSecret = function() return false end
    local registered = {}
    local cursorY = 0
    local after = {}
    local env = { UnitClass = function() return "x", class end, GetCursorPosition = function() return 0, cursorY end,
      PlaySound = function() end, SOUNDKIT = {}, C_Timer = { After = function(_, fn) after[#after + 1] = fn end },
      UnitStat = function() return 0, 0 end }
    Load("Character/StatPanes.lua", ns, env)
    local frame = ns.StatList(Region("Frame"))
    return ns, frame, function(y) cursorY = y end, after
  end
  local function Keys(boxes) local t = {} for _, b in ipairs(boxes) do t[#t + 1] = b.section.key end return table.concat(t, " ") end
  local function Laid(list)
    local boxes = {}
    for _, b in ipairs(list.all) do boxes[#boxes + 1] = b end
    table.sort(boxes, function(a, b) return a.points[1][5] > b.points[1][5] end)
    return Keys(boxes)
  end
  local CLIENT = "section1 section2 section3 section7 section4 section5"
  for class, want in pairs({ HUNTER = "section1 section2 section7 section3 section4 section5",
      MAGE = "section1 section2 section4 section3 section7 section5", WARLOCK = "section1 section2 section4 section3 section7 section5",
      PRIEST = "section1 section2 section4 section3 section7 section5", WARRIOR = CLIENT, ROGUE = CLIENT, DRUID = CLIENT }) do
    local ns = StatSession(class, {})
    check(Keys(ns.StatListState().boxes) == want, class .. ": " .. Keys(ns.StatListState().boxes))
  end
  -- a hunter drags Melee between General and Attributes
  local db = {}
  local ns, frame, Cursor, after = StatSession("HUNTER", db)
  local list = ns.StatListState()
  list.scroll.h = 400
  list.scroll.scripts.OnSizeChanged()
  check(Laid(list) == "section1 section2 section7 section3 section4 section5", "laid out in that order")
  local melee
  for _, b in ipairs(list.all) do if b.section.key == "section3" then melee = b end end
  check(melee.head.drag == "LeftButton", "a section's head takes a drag")
  list.child.top = 500
  melee.head.scripts.OnDragStart(melee.head)
  check(melee.alpha < 1, "dragged: shown faded")
  local generalBox = list.boxes[1]
  Cursor(500 - (generalBox.h - 5)) -- (in General's lower half)
  list.dragger.scripts.OnUpdate(list.dragger, 0.016)
  check(Laid(list) == "section1 section3 section2 section7 section4 section5", "the preview: Melee between General and Attributes (" .. Laid(list) .. ")")
  check(db.statListOrder == nil, "not kept until dropped")
  Cursor(500 - 5) -- (over General's upper half)
  list.dragger.scripts.OnUpdate(list.dragger, 0.016)
  check(Laid(list) == "section3 section1 section2 section7 section4 section5", "moved up: the preview follows (first)")
  Cursor(500 - (generalBox.h - 5))
  list.dragger.scripts.OnUpdate(list.dragger, 0.016)
  melee.head.scripts.OnDragStop(melee.head)
  check(melee.alpha == 1 and not list.dragger.scripts.OnUpdate, "dropped: shown plain, no more upkeep")
  check(Keys(list.boxes) == "section1 section3 section2 section7 section4 section5" and Laid(list) == Keys(list.boxes), "dropped: that order (" .. Keys(list.boxes) .. ")")
  check(db.statListOrder and table.concat(db.statListOrder.HUNTER, " ") == "section1 section3 section2 section7 section4 section5",
    "kept for hunters")
  -- the click that ends a drag does not fold the section; a later one does
  local tall = melee.h
  melee.head.scripts.OnClick(melee.head)
  check(melee.h == tall, "the drag's own click: no fold")
  for _, fn in ipairs(after) do fn() end
  melee.head.scripts.OnClick(melee.head)
  check(melee.h < tall, "a later click: folded")
  melee.head.scripts.OnClick(melee.head)
  check(melee.h == tall, "and unfolded")
  -- dragged below the end: last
  local general = list.boxes[1]
  general.head.scripts.OnDragStart(general.head)
  Cursor(500 - 999)
  list.dragger.scripts.OnUpdate(list.dragger, 0.016)
  general.head.scripts.OnDragStop(general.head)
  check(Keys(list.boxes) == "section3 section2 section7 section4 section5 section1", "dragged past the end: last")
  -- the list hidden mid drag: dropped where it stood
  local defense = list.boxes[5]
  defense.head.scripts.OnDragStart(defense.head)
  Cursor(500 - 1)
  list.dragger.scripts.OnUpdate(list.dragger, 0.016)
  frame.scripts.OnHide(frame)
  check(defense.alpha == 1 and list.dragging == nil and Keys(list.boxes):sub(1, 8) == "section5", "the window shut mid drag: dropped there")
  -- dragged past the view's foot: the view runs down; past its top: up
  list.scroll.h = 100
  local spell = list.boxes[4]
  spell.head.scripts.OnDragStart(spell.head)
  Cursor(500 - 150)
  list.dragger.scripts.OnUpdate(list.dragger, 0.5)
  local down = list.scroll:GetVerticalScroll()
  check(down > 0, "past the view's foot: it runs down (" .. down .. ")")
  Cursor(500 + 10)
  list.dragger.scripts.OnUpdate(list.dragger, 0.5)
  check(list.scroll:GetVerticalScroll() < down, "past its top: up")
  spell.head.scripts.OnDragStop(spell.head)
  list.scroll.h = 400
  list.scroll:SetVerticalScroll(0)
  -- a new session: the kept order
  local ns2 = StatSession("HUNTER", db)
  check(Keys(ns2.StatListState().boxes) == table.concat(db.statListOrder.HUNTER, " "), "the next session: the hunter's order")
  local ns3 = StatSession("MAGE", db)
  check(Keys(ns3.StatListState().boxes) == "section1 section2 section4 section3 section7 section5", "a mage: still the mage's default")
  db.statListOrder.MAGE = { "section5", "nonsense", 7, "section5" }
  local ns4 = StatSession("MAGE", db)
  check(Keys(ns4.StatListState().boxes) == "section5 section1 section2 section3 section7 section4", "a broken saved order: what it names, the rest after")
end

print("== the druid's mana bar in forms, the character sheet open (Units/DruidMana.lua)")
do
  local function Thing()
    local t = { shown = true, hooks = {} }
    return setmetatable(t, { __index = function(_, k)
      if k == "CreateFontString" then return function(self)
        local fs = Thing()
        function fs:SetFormattedText(f, ...) self.text = string.format(f, ...) end
        function fs:SetText(x) self.text = x end
        return fs
      end end
      if k == "CreateTexture" or k == "CreateMaskTexture" or k == "GetStatusBarTexture" then return function() return Thing() end end
      if k == "Show" then return function(self) self.shown = true end end
      if k == "Hide" then return function(self) self.shown = false end end
      if k == "IsShown" then return function(self) return self.shown end end
      if k == "GetFrameLevel" then return function() return 3 end end
      if k == "SetValue" then return function(self, v) self.value = v end end
      if k == "SetMinMaxValues" then return function(self, a, b) self.min, self.max = a, b end end
      return function() end
    end })
  end
  local cvars = { statusTextDisplay = "BOTH", statusText = "1" }
  local hover
  local gameMana = {}
  local mana, most = 800, 1105
  local ns = { db = { druidMana = true } }
  ns.UF = { active = true, frames = { player = { power = Thing() } }, PlayerGlowRoute = function() end }
  ns.IsSecret = function() return false end
  ns.Path = function() return nil end
  local b -- (the bar: the first frame the module makes)
  ns.NewFrame = function() local f = Thing() b = b or f return f end
  ns.TexPath = function() return "x" end
  ns.SetTex = function() end
  ns.Sched = { OnHover = function(_, fn) hover = fn end }
  ns.SetShownIf = function(f, v) local changed = f.shown ~= v f.shown = v return changed end
  ns.SetAlphaIf = function() end
  ns.GetCVar = function(k) return cvars[k] end
  ns.EventFrame = function() return Thing() end
  ns.RegisterEvents = function() end
  ns.OnToggle = function() end
  ns.HookScriptOnce = function(frame, script, fn) frame.hooks[script] = fn end
  local sheet = { hooks = {} }
  local env = {
    CharacterFrame = sheet, PlayerFrame = Thing(), Enum = { PowerType = { Mana = 0 } },
    UnitClass = function() return "Druid", "DRUID" end,
    UnitPowerType = function() return 1 end,
    UnitPower = function() return mana end, UnitPowerMax = function() return most end,
    UnitPowerPercent = function() return math.floor(100 * mana / most + 0.5) end,
    BreakUpLargeNumbers = function(v) local s = tostring(v) return (#s > 3) and (s:sub(1, -4) .. "," .. s:sub(-3)) or s end,
    PlayerFrame_GetManaBar = function() return gameMana end,
  }
  env._G = env
  Load("Units/DruidMana.lua", ns, env)
  ns.DruidManaSync()
  check(ns.DruidManaShown(), "in bear form: the mana bar shown")
  local function Say()
    local out = {}
    for _, k in ipairs({ "center", "left", "right" }) do if b[k].shown then out[#out + 1] = k .. "=" .. tostring(b[k].text) end end
    return table.concat(out, " ")
  end
  check(Say() == "left=72% right=800", "sheet shut, Status Text Both: percent and value (" .. Say() .. ")")
  gameMana.showNumeric = true
  check(sheet.hooks.OnShow ~= nil and sheet.hooks.OnHide ~= nil, "the sheet's show and hide watched")
  sheet.hooks.OnShow()
  check(Say() == "center=800 / 1,105", "sheet open: current / max, as the game's own bars (" .. Say() .. ")")
  hover(true)
  check(Say() == "center=800 / 1,105", "sheet open, the mouse over it: still current / max (" .. Say() .. ")")
  hover(false)
  gameMana.showNumeric = nil
  sheet.hooks.OnHide()
  check(Say() == "left=72% right=800", "sheet shut: back to the setting (" .. Say() .. ")")
  cvars.statusText, cvars.statusTextDisplay = "0", "NONE"
  sheet.hooks.OnHide()
  check(Say() == "", "Status Text off, sheet shut: no numbers (" .. Say() .. ")")
  gameMana.showNumeric = true
  sheet.hooks.OnShow()
  check(Say() == "center=800 / 1,105", "Status Text off, sheet open: current / max (" .. Say() .. ")")
  check(b.value == 800 and b.max == 1105, "the bar's fill unchanged: 800 of 1105")
end

print("== the mail module's window in this look (Windows/ClaraMail.lua)")
do
  local done = {}
  local ns = { panels = { active = true } }
  ns.SkinWindow = function(f, opts) done[#done + 1] = "window " .. f.name .. (opts.portrait == false and " plain" or "") end
  ns.SkinRedButton = function(f) done[#done + 1] = "button " .. f.name end
  ns.SkinCloseButton = function(f) done[#done + 1] = "close " .. f.name end
  Load("Windows/ClaraMail.lua", ns, {})
  check(type(ns.ClaraMailSkin) == "function", "a skin for the mail module")
  ns.ClaraMailSkin("window", { name = "panel" })
  ns.ClaraMailSkin("button", { name = "Lola" })
  ns.ClaraMailSkin("close", { name = "x" })
  ns.ClaraMailSkin("dropdown", { name = "sort" })
  check(table.concat(done, ", ") == "window panel plain, button Lola, close x", "window frames on: dressed (" .. table.concat(done, ", ") .. ")")
  ns.panels.active = false
  done = {}
  ns.ClaraMailSkin("window", { name = "panel" })
  ns.ClaraMailSkin("button", { name = "Lola" })
  check(#done == 0, "window frames off: the game's look kept")
end

print("")
print(fails .. " failure(s)")
