-- Profession cooldowns (ProfCooldowns.lua) in the Professions micro button's tooltip: the Salt Shaker, Mooncloth and
-- every transmute (Classic's, and WoW Forever's own found by name in the professions window), the time left or Ready
-- (green). Read at login (spells known, the Salt Shaker in the bags) and from the professions window (the recipe's own
-- cooldown: sure, a 0 there clears a time; a spell's 0 does not). Kept in the gold tracker's record of the character
-- (t), touched for the sync; the gold tracker's own update keeps it; a record's bad entries dropped. Without Shift: this
-- character's, a hint when others have some; Shift: every character (this one, this WoW account's, then the other
-- accounts' with the account's name); transmutes sharing a time on one line. The box off: nothing.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false,
  leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false,
  classicui = false, tullarange = false, tooltipanchor = false } }
local now = 1800000000
time = function() return now end
M.now = 1000
GetNormalizedRealmName = function() return "Forever" end
RAID_CLASS_COLORS = RAID_CLASS_COLORS or {}
RAID_CLASS_COLORS.ROGUE = { r = 1, g = 0.96, b = 0.41 }
RAID_CLASS_COLORS.PRIEST = { r = 1, g = 1, b = 1 }
RAID_CLASS_COLORS.MAGE = { r = 0.25, g = 0.78, b = 0.92 }
-- this WoW account (ICKSTU) with an alt that knows Mooncloth; WANJ's Frank, brought by the sync, an alchemist
ClaraMoneyDB = { me = "acc1", accounts = { acc1 = { n = "ICKSTU", at = 1 }, acc2 = { n = "WANJ", at = 1 } },
  chars = {
    ["Lia-Forever"] = { n = "Lia", s = "Love", r = "Forever", c = "PRIEST", l = 40, m = 5, a = "acc1", at = 100,
      t = { s18560 = { e = now + 3 * 86400 + 3600 }, bad = { e = 1 }, s1 = "x" } },
    ["Frank-Forever"] = { n = "Frank", r = "Forever", c = "MAGE", l = 20, m = 5, a = "acc2", at = 100,
      t = { s17187 = { e = 0, g = 1 } } },
  } }

local names = { [18560] = "Mooncloth", [17187] = "Transmute: Arcanite", [11479] = "Transmute: Iron to Gold",
  [99999] = "Transmute: Legionite", [2000] = "Heavy Linen Bandage" }
local spellCd = {} -- [id] = { start, duration }
C_Spell.GetSpellName = function(id) return names[id] end
C_Spell.GetSpellCooldown = function(id) local c = spellCd[id] or { 0, 0 } return { startTime = c[1], duration = c[2] } end
S.knownSpells = { [17187] = true }
local saltCount, saltCd = 1, { 0, 0 }
C_Item.GetItemCount = function(id) if id == 15846 then return saltCount end return 0 end
C_Item.GetItemNameByID = function(id) if id == 15846 then return "Salt Shaker" end end
C_Container = C_Container or {}
C_Container.GetItemCooldown = function(id) if id == 15846 then return saltCd[1], saltCd[2], 1 end return 0, 0, 1 end
local recipes, recipeCd = {}, {}
C_TradeSkillUI = C_TradeSkillUI or {}
C_TradeSkillUI.GetAllRecipeIDs = function() return recipes end
C_TradeSkillUI.GetRecipeInfo = function(id) return { name = names[id], learned = true } end
C_TradeSkillUI.GetRecipeCooldown = function(id) return recipeCd[id] end
local entered
ProfessionMicroButton = { HookScript = function(self, what, fn) if what == "OnEnter" then entered = fn end end,
  EvaluateTooltipVisibility = function(self) GameTooltip:SetOwner(self); GameTooltip:AddLine("Professions (K)") end }

local function Tip()
  local t = { lines = {} }
  function t:SetOwner(o) self.owner = o; self.lines = {} end
  function t:IsOwned(o) return self.owner == o end
  function t:IsShown() return true end
  function t:ClearLines() self.lines = {} end
  function t:AddLine(l, r, g, b) self.lines[#self.lines + 1] = { l = l, c = { r, g, b } } end
  function t:AddDoubleLine(l, rt, lr, lg, lb, rr, rg, rb) self.lines[#self.lines + 1] = { l = l, r = rt, rc = { rr, rg, rb } } end
  function t:Show() self.shows = (self.shows or 0) + 1 end
  return t
end
GameTooltip = Tip()

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"; S.name = "Elle"
local oldName = UnitName
function UnitName(u) if u == "player" then return "Elle" end return oldName(u) end
function UnitClass(u) return "Rogue", "ROGUE" end
M.LoadAddon(ADDON_DIR, ns)
local P = ns.ProfCD
if not (P and ns.Money) then out("(no profession cooldowns or gold tracker in this version)"); out(""); out("0 failure(s)"); return end
local touched = {}
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false)
local G = ns.Money
G.Touched = function(kind, key) touched[#touched + 1] = kind .. ":" .. key end
spellCd[17187] = { M.now - 100, 86400 } -- (Arcanite cast 100 s ago: a day)
local function Timers() for _ = 1, 60 do if not (M.timers and #M.timers > 0) then break end M.RunTimer() end end
Timers()

out("== at login: the spells known and the Salt Shaker read, kept in the gold tracker's record")
local me = G.db.chars["Elle-Forever"]
check(me and me.t and me.t.s17187 and math.abs(me.t.s17187.e - (now + 86300)) <= 1 and me.t.s17187.g == 1,
  "Arcanite: a day less 100 s, a transmute: " .. tostring(me and me.t and me.t.s17187 and me.t.s17187.e - now))
check(me.t.i15846 and me.t.i15846.e == 0, "the Salt Shaker in the bags: ready")
check(me.t.s18560 == nil, "Mooncloth not known here: not listed")
check(G.CleanChar(ClaraMoneyDB.chars["Lia-Forever"]).t.bad == nil and G.CleanChar(ClaraMoneyDB.chars["Lia-Forever"]).t.s18560 ~= nil,
  "a record's bad entries dropped, the good kept")

out("== the professions window: the recipes' own cooldowns, a transmute of WoW Forever found by its name")
recipes = { 17187, 99999, 2000 }
recipeCd[17187] = 86300; recipeCd[99999] = 86300
G.Touched = function(kind, key) touched[#touched + 1] = kind .. ":" .. key end -- (the sync's, once started)
M.Fire("TRADE_SKILL_LIST_UPDATE"); Timers()
check(touched[#touched] == "g:Elle-Forever", "a change: touched for the sync: " .. tostring(touched[#touched]))
check(me.t.s99999 and me.t.s99999.g == 1 and math.abs(me.t.s99999.e - (now + 86300)) <= 1, "Legionite: found, a transmute")
check(me.t.s2000 == nil, "a recipe without a cooldown of ours: not listed")

out("== the tooltip, Shift not held: this character's, the hint")
local tip = Tip()
tip:SetOwner(ProfessionMicroButton)
P.AddTo(tip)
local function Find(t, text) for i, l in ipairs(t.lines) do if l.l and tostring(l.l):find(text, 1, true) then return l, i end end end
check(Find(tip, ns.L.PCD_TITLE) ~= nil, "its title")
local salt = Find(tip, "Salt Shaker")
check(salt and salt.r == ns.L.PCD_READY and salt.rc[2] == 1 and salt.rc[1] < 1, "Salt Shaker: Ready, green")
local tr = Find(tip, ns.L.PCD_TRANSMUTES)
check(tr and tr.r == "23h 58m", "Arcanite and Legionite sharing a time: one line, " .. tostring(tr and tr.r))
check(Find(tip, ns.L.PCD_SHIFT_HINT) ~= nil and Find(tip, "Frank") == nil, "the hint; no other character")
out("== Shift held: every character, the other account named")
M.shift = true
tip = Tip(); tip:SetOwner(ProfessionMicroButton)
P.AddTo(tip)
local _, iMe = Find(tip, "Elle")
local lia, iLia = Find(tip, "Lia Love")
local frank, iFrank = Find(tip, "Frank")
check(iMe and iLia and iFrank and iMe < iLia and iLia < iFrank, "this one, this account's, then the others'")
check(lia and lia.r == "" and frank and frank.r == "WANJ", "the other account's name beside its character")
local moon = Find(tip, "Mooncloth")
check(moon and moon.r == "3d 1h", "Lia's Mooncloth: " .. tostring(moon and moon.r))
local frankArc = tip.lines[iFrank + 1]
check(frankArc and frankArc.l:find("Transmute: Arcanite", 1, true) and frankArc.r == ns.L.PCD_READY, "Frank's one transmute: its own name, Ready")
M.shift = false
out("== Shift pressed while it shows: drawn again")
GameTooltip = Tip()
entered(ProfessionMicroButton) -- (the game's OnEnter already drew its line)
check(GameTooltip.lines[1] == nil or Find(GameTooltip, ns.L.PCD_TITLE), "the hovered button's tooltip gets the lines")
GameTooltip:SetOwner(ProfessionMicroButton); GameTooltip:AddLine("Professions (K)")
M.shift = true
M.Fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
check(Find(GameTooltip, "Professions (K)") and Find(GameTooltip, "Frank"), "drawn again with every character")
M.shift = false

out("== a spell's 0 does not undo a known time; the recipe's 0 does")
spellCd[17187] = { 0, 0 }
P.Scan()
check(me.t.s17187.e > now, "a spell read 0: the time kept")
recipeCd[17187] = nil; recipeCd[99999] = nil
P.ScanRecipes()
check(me.t.s17187.e == 0 and me.t.s99999.e == 0, "the window's recipes: ready")
out("== the Salt Shaker read in the bags, its cooldown begun before the computer was started")
saltCd = { M.now - (3 * 86400 - 11880), 3 * 86400 } -- (begun 2d 20h42m ago: 3h18m left; its start below 0)
P.Scan()
check(math.abs(me.t.i15846.e - (now + 11880)) <= 1, "a start below 0: 3h18m left, not Ready: " .. P.Format(me.t.i15846.e - now))
saltCd = { M.now + 4294967.296 - (3 * 86400 - 11880), 3 * 86400 } -- (the game's clock wrapped: a start past now)
P.Scan()
check(math.abs(me.t.i15846.e - (now + 11880)) <= 1, "a start past now (wrapped): the same: " .. P.Format(me.t.i15846.e - now))
saltCd = { 0, 0 }
P.Scan()
check(me.t.i15846.e == 0, "its cooldown over: Ready")
out("== the gold tracker's own update keeps them")
M.Fire("PLAYER_MONEY")
check(G.db.chars["Elle-Forever"].t and G.db.chars["Elle-Forever"].t.i15846 ~= nil, "kept through the gold's record")
out("== the times written")
check(P.Format(90061) == "1d 1h" and P.Format(3700) == "1h 01m" and P.Format(30) == "1 min" and P.Format(0) == ns.L.PCD_READY, "1d 1h, 1h 01m, 1 min, Ready")
out("== the box off: nothing")
ns:SetProfCooldowns(false)
tip = Tip(); P.AddTo(tip)
check(#tip.lines == 0 and not ns:ProfCooldowns(), "nothing added")
ns:SetProfCooldowns(true)
check(ns:ProfCooldownsReport():find("profession cooldowns:", 1, true) ~= nil, ns:ProfCooldownsReport())
out("")
out(fails .. " failure(s)")
