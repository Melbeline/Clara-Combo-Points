-- The classic quest log turned off on its card (sv.qol.questlog = false): nothing of it runs from the reload (no window,
-- no key bound, no pad over the micro button: the game's own quest log); its card still shows its box's state; turned
-- back on, from the next reload
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
do local f = io.open(ADDON_DIR .. "/Modules/QuestLog/QuestLogWindow.lua", "rb")
  if not f then out("  ok   not in this version (Clara's own quest log: the sans version only (avec: ClassicUI's))"); out("0 failure(s)"); return 0 end
  f:close() end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
ClaraComboPointsDB = { qol = { nodesight = false, classicui = false, doesitdie = false, whatstraining = false,
  enhancedraidframes = false, names = false, lfgforever = false, buyemall = false, leatrix = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, mail = false, tullarange = false, tooltipanchor = false,
  money = false, prices = false, sniper = false, whocooldown = false, idtip = false, soloraidframe = false,
  enemycasts = false, fishing = false, unitscan = false, reverseengineering = false, xptext = false, questlog = false } }
local overrideSets = 0
function SetOverrideBindingClick() overrideSets = overrideSets + 1 end
function ClearOverrideBindings() end
S.bindings = { TOGGLEQUESTLOG = "L" }
QuestLogMicroButton = CreateFrame("Button", "QuestLogMicroButton", UIParent)
QuestLogMicroButton:SetSize(24, 32)
QuestLogMicroButton:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 900, 4)

S.class = "ROGUE"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.Fire("UPDATE_BINDINGS")

out("== turned off: nothing of it runs")
check(ns:QolState("questlog") == "off" and not ns:QolRuns("questlog"), "off this session")
check(ns.QuestLogPrivate == nil and ns.qolSwitches ~= nil and _G.ClaraQuestLogToggle == nil and _G.ClaraQuestLogFrame == nil, "no window, no toggle")
check(overrideSets == 0, "the quest log key left to the game")
M.Tick()
local over = 0
for _, f in ipairs(M.frames) do
  if f ~= QuestLogMicroButton and f:IsShown() then
    local l, b = M.Rect(f)
    if l == 900 and b == 4 then over = over + 1 end
  end
end
check(over == 0 and #M.frames > 10, "no pad over the micro button: its own click (the game's quest log)")
check(ns.ToggleQuestLog == nil, "nothing to open")
local sw = ns.qolSwitches.questlog
check(sw and #sw == 1, "its card's box still known (shown with the module on)")

out("== turned back on: from the next reload")
ns:SetQolEnabled("questlog", true)
check(ns:QolEnabled("questlog") and ns:QolStatusText({ key = "questlog", name = "Quest log" }) == ns.L.QOL_ON_NEXT,
  "on from the next reload (" .. tostring(ns:QolStatusText({ key = "questlog", name = "Quest log" })) .. ")")
check(ns.sv.qol == nil or ns.sv.qol.questlog == nil, "its switch saved as on")

out(string.format("\n%d failure(s)", fails))
return fails
