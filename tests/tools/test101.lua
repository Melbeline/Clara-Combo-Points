-- The rested XP left in the experience bar's tooltip (RestedXP.lua), on every version: on the game's rest line, after
-- its name ("Rested  xp: 1,600 - 16%"), hovered on the bar (its two places) or on its rest tick; once however many
-- hovers; nothing when not rested; ClassicUI's own where ClassicUI runs (no second one)
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
ClaraComboPointsDB = { qol = setmetatable({ xptext = true }, { __index = function() return false end }) }

-- the game's tooltip lines (its cells), its experience bar: its tooltip built on hover, as the game's
local tip = GameTooltip
tip._lines = {}
function tip:NumLines() return #self._lines end
function tip:IsShown() return self._shown == true end
local function Cell(i)
  local name = "GameTooltipTextLeft" .. i
  _G[name] = _G[name] or { GetText = function(self) return self.text end, SetText = function(self, t) self.text = t end }
  return _G[name]
end
local function Line(i) return Cell(i):GetText() end
local rest, state, xpMax = 1600, { 1, "Rested", 2 }, 10100
function GetXPExhaustion() return rest end
function GetRestState() return unpack(state) end
function UnitXPMax() return xpMax end
function UnitXP() return 750 end
function BreakUpLargeNumbers(n) local s = tostring(n) return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")) end
EXHAUST_TOOLTIP1 = "%s\n%d%% of normal experience gained from monsters."
StatusTrackingBarInfo = { BarsEnum = { Experience = 4 } }
local function Bar(container)
  local bar = CreateFrame("Frame", nil, container)
  bar.ExhaustionTick = CreateFrame("Button", nil, bar)
  function bar.ExhaustionTick:ExhaustionToolTipText()
    local id, name, mult = GetRestState()
    tip:SetOwner(UIParent)
    tip._lines = { "750 / 10,100 ( 8% )", (EXHAUST_TOOLTIP1):format(name, mult * 100) }
    Cell(1):SetText(tip._lines[1]); Cell(2):SetText(tip._lines[2])
    tip:Show()
  end
  bar.ExhaustionTick:SetScript("OnEnter", function(self) self:ExhaustionToolTipText() end)
  bar:SetScript("OnEnter", function(self) self.ExhaustionTick:ExhaustionToolTipText() end)
  container.bars = { [4] = bar }
  return bar
end
MainStatusTrackingBarContainer = CreateFrame("Frame", "MainStatusTrackingBarContainer", UIParent)
SecondaryStatusTrackingBarContainer = CreateFrame("Frame", "SecondaryStatusTrackingBarContainer", UIParent)
local main, second = Bar(MainStatusTrackingBarContainer), Bar(SecondaryStatusTrackingBarContainer)

S.class = "ROGUE"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local function Hover(f) f:GetScript("OnEnter")(f) end

out("== hovered: the rested XP left on the game's rest line")
Hover(main)
check(Line(2) == "Rested  xp: 1,600 - 16%\n200% of normal experience gained from monsters.", "the bar: " .. tostring(Line(2)))
check(Line(1) == "750 / 10,100 ( 8% )", "its first line left as the game's")
Hover(main)
check(Line(2):find("^Rested  xp: 1,600 %- 16%%\n") ~= nil and select(2, Line(2):gsub("xp:", "")) == 1, "hovered again: once")
Hover(main.ExhaustionTick)
check(Line(2):find("^Rested  xp: 1,600 %- 16%%") ~= nil, "on its rest tick too")
Hover(second)
check(Line(2):find("^Rested  xp: 1,600 %- 16%%") ~= nil, "the bar's second place too")
rest = 15150
Hover(main)
check(Line(2):find("^Rested  xp: 15,150 %- 150%%") ~= nil, "a level and a half rested: 150% (" .. Line(2):sub(1, 30) .. ")")

out("== not rested, a secret value, ClassicUI's own: nothing")
rest, state = nil, { 2, "Normal", 1 }
Hover(main)
check(Line(2) == "Normal\n100% of normal experience gained from monsters.", "not rested: the game's line")
rest, state = MOCK.Secret(1600), { 1, "Rested", 2 }
local ok, e = pcall(Hover, main)
check(ok and Line(2):find("xp:", 1, true) == nil, "a secret value: nothing, no error" .. (ok and "" or (": " .. tostring(e))))
rest = 1600
ns.ClassicUIRuns = true
Hover(main)
check(Line(2):find("xp:", 1, true) == nil, "where ClassicUI runs: its own (none of ours)")
ns.ClassicUIRuns = nil

out(string.format("\n%d failure(s)", fails))
return fails
