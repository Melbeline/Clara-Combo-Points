-- ClassicQuestLog beside Clara Combo Points: while Clara's own quest log runs (its key's button there by login), this
-- one stays off (a chat line says so; no key bound, no pad over the micro button, /cql says so, its options page too)
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local sets = 0
function SetOverrideBindingClick() sets = sets + 1 end
function ClearOverrideBindings() end
S.bindings = { TOGGLEQUESTLOG = "L" }
QuestLogMicroButton = CreateFrame("Button", "QuestLogMicroButton", UIParent)
QuestLogMicroButton:SetSize(24, 32)
QuestLogMicroButton:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 900, 4)
local said = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) said[#said + 1] = text end }
local printed = {}
local oldPrint = print
print = function(...) printed[#printed + 1] = table.concat({ ... }, " ") end
-- Clara's quest log module running: its key's button
CreateFrame("Button", "ClaraQuestLogToggle", UIParent)

S.class = "ROGUE"; S.locale = "enUS"
local ns = {}
M.LoadAddonAs(ADDON_DIR, "ClassicQuestLog.toc", "ClassicQuestLog", ns)
M.Fire("ADDON_LOADED", "ClassicQuestLog"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.Fire("UPDATE_BINDINGS")
M.Tick()

out("== Clara's own quest log on: this one off")
check(ns.off == true, "off")
check(said[1] == ns.L.CLARA, "a line in the chat says so")
check(_G.ClassicQuestLogToggle == nil and sets == 0, "the quest log key left to Clara's")
check(ns.microPad == nil, "no pad over the micro button")
SlashCmdList.CLASSICQUESTLOG("")
check(_G.ClassicQuestLogFrame == nil and printed[#printed] == ns.L.CLARA, "/cql: says so, opens nothing")
ns.optionsPage:GetScript("OnShow")(ns.optionsPage)
check(ns.optionsDual:GetChecked() == true, "its options page: the double pane on by default")
print = oldPrint

out(string.format("\n%d failure(s)", fails))
return fails
