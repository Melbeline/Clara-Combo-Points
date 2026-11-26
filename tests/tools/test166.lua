-- The guild rank in a player's tooltip (Modules/TooltipTarget): after its guild's name on the guild's line,
-- "<Guild> (Rank)"; once; not for a creature, nor when the game keeps the guild or rank secret; its switch off: nothing.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70959", "Nov 17 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false,
  leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false,
  classicui = false, tullarange = false, tooltipanchor = false } }
local guild = { mouseover = { "Les Lunes", "Officière" } }
local players = { mouseover = true }
GetGuildInfo = function(u) local g = guild[u] if g then return g[1], g[2], 1 end end
UnitIsPlayer = function(u) return players[u] == true end
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
local Rank = ns.TooltipGuildRank
if not Rank then out("(no guild rank in this version)"); out(""); out("0 failure(s)"); return end
local function FS(t) local o = { t = t } function o:GetText() return self.t end function o:SetText(x) self.t = x end return o end
local function Tip(lines)
  local t = { n = #lines }
  function t:GetName() return "GRTip" end
  function t:NumLines() return self.n end
  function t:Show() self.shown = true end
  for i, l in ipairs(lines) do _G["GRTipTextLeft" .. i] = FS(l) end
  for i = #lines + 1, 8 do _G["GRTipTextLeft" .. i] = nil end
  return t
end
out("== a player in a guild: its rank after the guild")
local tip = Tip({ "Lia Moon", "<Les Lunes>", "Level 40 Night Elf Hunter (Player)" })
Rank(tip, "mouseover")
check(GRTipTextLeft2:GetText() == "<Les Lunes> |cffb3b3b3(Officière)|r", "the guild's line: " .. GRTipTextLeft2:GetText())
check(GRTipTextLeft1:GetText() == "Lia Moon" and GRTipTextLeft3:GetText():find("^Level"), "the other lines left alone")
Rank(tip, "mouseover")
check(GRTipTextLeft2:GetText() == "<Les Lunes> |cffb3b3b3(Officière)|r", "drawn again: not twice")
out("== the guild's name in color, without brackets: found too")
tip = Tip({ "Lia Moon", "|cff40ff40Les Lunes|r", "Level 40" })
Rank(tip, "mouseover")
check(GRTipTextLeft2:GetText():find("(Officière)", 1, true) ~= nil, GRTipTextLeft2:GetText())
out("== a creature, a secret, the switch off: nothing")
players.mouseover = false
tip = Tip({ "Boar", "<Les Lunes>" })
Rank(tip, "mouseover")
check(GRTipTextLeft2:GetText() == "<Les Lunes>", "a creature: left alone")
players.mouseover = true
guild.mouseover = { "Les Lunes", M.Secret("Officière") }
tip = Tip({ "Lia Moon", "<Les Lunes>" })
Rank(tip, "mouseover")
check(GRTipTextLeft2:GetText() == "<Les Lunes>", "a secret rank: left alone")
guild.mouseover = { "Les Lunes", "Officière" }
local sw
for _, x in ipairs(ns.qolSwitches.tooltiptarget or {}) do if x.label == "TTG_SW_GUILDRANK" then sw = x end end
check(sw and sw.get() and ns.L.TTG_SW_GUILDRANK, "its switch on its card, on by default")
sw.set(false)
tip = Tip({ "Lia Moon", "<Les Lunes>" })
Rank(tip, "mouseover")
check(GRTipTextLeft2:GetText() == "<Les Lunes>", "off: nothing")
sw.set(true)
out("")
out(fails .. " failure(s)")
