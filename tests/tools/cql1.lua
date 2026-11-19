-- ClassicQuestLog (standalone, from Clara's quest log module): the double pane by default; opened by the quest log key
-- (override bindings, set out of combat) and an unseen button over the quest log micro button; its rows, page, rewards,
-- All tab, watching, quest levels, abandon, one pane or two (its radio, its options box), its size grip, its place kept;
-- Share's secure pad; /cql; its options page
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end

-- The game: its quest log (Elwynn open; Westfall folded by the game), the quest API, bindings, the micro button
local LOG = {
  { title = "Elwynn Forest", isHeader = true, headerSortKey = "elwynn" },
  { title = "Wolves Across the Border", questID = 100, level = 2, difficultyLevel = 2 },
  { title = "Kobold Camp Cleanup", questID = 101, level = 4, difficultyLevel = 4 },
  { title = "Westfall", isHeader = true, headerSortKey = "westfall", isCollapsed = true },
  { title = "The Defias Brotherhood", questID = 102, level = 14, difficultyLevel = 14 },
}
local expanded = {}
local function Visible()
  local list, skip = {}, false
  for _, e in ipairs(LOG) do
    if e.isHeader then skip = e.isCollapsed; list[#list + 1] = e elseif not skip then list[#list + 1] = e end
  end
  return list
end
function ExpandQuestHeader(i)
  local e = Visible()[i]
  if e and e.isHeader then e.isCollapsed = false; expanded[#expanded + 1] = e.title end
end
local selected, watched, complete = 0, {}, { [101] = true }
local abandonSet
C_QuestLog = {
  GetNumQuestLogEntries = function()
    local n = 0
    for _, e in ipairs(LOG) do if not e.isHeader then n = n + 1 end end
    return #Visible(), n
  end,
  GetInfo = function(i)
    local e = Visible()[i]
    if not e then return nil end
    local copy = {}
    for k, v in pairs(e) do copy[k] = v end
    copy.questLogIndex = i
    return copy
  end,
  GetSelectedQuest = function() return selected end,
  SetSelectedQuest = function(id) selected = id end,
  IsComplete = function(id) return complete[id] == true end,
  IsFailed = function() return false end,
  GetQuestWatchType = function(id) return watched[id] end,
  AddQuestWatch = function(id) watched[id] = 0 end,
  RemoveQuestWatch = function(id) watched[id] = nil end,
  IsPushableQuest = function(id) return id ~= 102 end,
  GetMaxNumQuestsCanAccept = function() return 20 end,
  GetQuestTagInfo = function() return nil end,
  SetAbandonQuest = function() abandonSet = selected end,
  GetAbandonQuestName = function()
    for _, e in ipairs(LOG) do if e.questID == selected then return e.title end end
  end,
  GetAbandonQuestItems = function() return {} end,
  IsUnitOnQuest = function(unit, id) return unit == "party1" and id == 100 end,
  GetRequiredMoney = function() return 0 end,
}
local TEXT = { [100] = { "Wolves have been seen across the border.", "Kill 8 Prowlers." },
  [101] = { "Kobolds infest the camp.", "Kill 10 Kobold Vermin." }, [102] = { "Find the Defias.", "Report to Gryan." } }
local function IndexQuest(index) local e = Visible()[index] return e and e.questID end
function GetQuestLogQuestText(index) local t = TEXT[IndexQuest(index)] or {} return t[1], t[2] end
function GetNumQuestLeaderBoards(index) return IndexQuest(index) and 1 or 0 end
function GetQuestLogLeaderBoard(i, index)
  local id = IndexQuest(index)
  if id == 101 then return "Kobold Vermin slain: 10/10", "monster", true end
  return "Prowler slain: 3/8", "monster", false
end
function GetQuestLogTimeLeft() return nil end
function GetNumQuestLogChoices(id) return id == 100 and 2 or 0 end
function GetNumQuestLogRewards(id) return id == 100 and 1 or 0 end
function GetQuestLogRewardMoney(id) return id == 100 and 125 or 0 end
function GetQuestLogRewardXP(id) return id == 100 and 450 or 0 end
function GetQuestLogChoiceInfo(i) return ({ "Worn Leather Gloves", "Worn Mail Gloves" })[i], 132952, 1, 1, true, 2000 + i end
function GetQuestLogRewardInfo(i) return "Minor Healing Potion", 134829, 3, 1, true, 118 end
function GetQuestLink(id) return "|Hquest:" .. id .. "|h[quest]|h" end
function SecondsToTime(s) return s .. " sec" end
function BreakUpLargeNumbers(n) return tostring(n) end
function IsModifiedClick() return false end
function IsModifierKeyDown() return M.shift == true end
function GetNumSubgroupMembers() return S.group == "party" and 1 or 0 end
local cvars = { showQuestLevel = "0" }
function GetCVarBool(name) return cvars[name] == "1" end
function issecurevariable() return true end
UIErrorsFrame = { messages = {} }
function UIErrorsFrame:AddMessage(text) table.insert(self.messages, text) end
ERR_NOT_IN_COMBAT = "You can't do that while in combat"
StaticPopupDialogs.ABANDON_QUEST = { text = "Abandon \"%s\"?", button1 = "Yes", button2 = "No" }
StaticPopupDialogs.ABANDON_QUEST_WITH_ITEMS = { text = "Abandon \"%s\"? %s", button1 = "Yes", button2 = "No" }
-- the override bindings set (key -> button name), and how many times
local overrides, overrideSets = {}, 0
function SetOverrideBindingClick(owner, priority, key, name)
  assert(not S.inCombat, "override binding in combat")
  overrides[key] = name
  overrideSets = overrideSets + 1
end
function ClearOverrideBindings() assert(not S.inCombat, "override binding in combat") overrides = {} end
S.bindings = { TOGGLEQUESTLOG = "L" }
-- the micro button (bottom right), the minimap's zone text (the map's own button), the map
QuestLogMicroButton = CreateFrame("Button", "QuestLogMicroButton", UIParent)
QuestLogMicroButton:SetSize(24, 32)
QuestLogMicroButton:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 900, 4)
QuestLogMicroButton.tooltipText = "Quest Log (L)"
local microClicks = 0
QuestLogMicroButton:SetScript("OnClick", function() microClicks = microClicks + 1 end)
MinimapCluster = CreateFrame("Frame", "MinimapCluster", UIParent)
MinimapCluster.ZoneTextButton = CreateFrame("Button", nil, MinimapCluster)
WorldMapFrame = CreateFrame("Frame", "WorldMapFrame", UIParent); WorldMapFrame:Hide()
QuestMapFrame = CreateFrame("Frame", "QuestMapFrame", WorldMapFrame)
EditModeManagerFrame = CreateFrame("Frame", "EditModeManagerFrame", UIParent); EditModeManagerFrame:Hide()

S.class = "ROGUE"; S.locale = "enUS"
local ns = {}
M.LoadAddonAs(ADDON_DIR, "ClassicQuestLog.toc", "ClassicQuestLog", ns)
M.Fire("ADDON_LOADED", "ClassicQuestLog"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local function Run() while M.timers and #M.timers > 0 do M.RunTimer() end end
local Q = ns
local function F() return _G.ClassicQuestLogFrame end
local function Plain(t) return ((t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function Rows() return F().rows end
local function RowTexts()
  local list = {}
  for _, row in ipairs(Rows()) do
    if row:IsShown() and row.text then list[#list + 1] = Plain(row.text._text) end
  end
  return list
end

out("== on by default; the quest log key bound to it, out of combat")
check(Q.Toggle ~= nil and not Q.off, "it runs (no Clara)")
check(overrides.L == "ClassicQuestLogToggle", "the quest log key (L) clicks ours")
local sets = overrideSets
M.Fire("UPDATE_BINDINGS")
check(overrideSets == sets, "the bindings' own change heard: set again only if the keys changed")
S.bindings.TOGGLEQUESTLOG = "J"
S.inCombat = true
M.Fire("UPDATE_BINDINGS")
check(overrides.L == "ClassicQuestLogToggle" and overrides.J == nil, "rebound in combat: waits")
S.inCombat = false
M.Fire("PLAYER_REGEN_ENABLED")
check(overrides.J == "ClassicQuestLogToggle" and overrides.L == nil, "after the fight: the new key")
check(M.settingsCategories[1] and M.settingsCategories[1].name == "ClassicQuestLog", "its page in the game's options")

out("== the key opens it: rows, the game's folded header opened, the first quest's page")
check(F() == nil, "nothing built before it is opened")
_G.ClassicQuestLogToggle:Click()
Run()
check(F() and F():IsShown(), "opened by the key")
check(F():GetFrameStrata() == "HIGH" and F():GetWidth() == 680 and F():GetHeight() == 440 and F().dual
  and F().dualToggle:GetChecked() and F().showMap:IsShown(), "the double pane by default (680x440, Show Map)")
F().dualToggle:Click()
check(ClassicQuestLogDB.dual == false and F():GetWidth() == 384 and F():GetHeight() == 512, "its radio: the 1.x window, 384x512, kept")
local found = false
for _, name in ipairs(UISpecialFrames) do if name == "ClassicQuestLogFrame" then found = true end end
check(found, "Escape closes it (UISpecialFrames)")
check(expanded[1] == "Westfall", "the header the game folded: opened (folded in our list instead)")
local texts = RowTexts()
check(#texts == 5 and texts[1] == "Elwynn Forest" and texts[2] == "  Wolves Across the Border"
  and texts[4] == "Westfall" and texts[5] == "  The Defias Brotherhood",
  "the rows: headers and quests (" .. table.concat(texts, " | ") .. ")")
check(Rows()[3].tag._text == "(Complete)", "a finished quest's tag: (Complete)")
check(selected == 100 and Rows()[2].highlight:GetAlpha() == 1, "the first quest picked, its bar lit")
check(Plain(F().count._text) == "Quests: 3/20", "the count: " .. Plain(F().count._text))
local page = {}
local strings, used, buttons, rewardsUsed = Q.QL.DetailPieces()
for i = 1, used do page[#page + 1] = strings[i]._text end
local pageText = table.concat(page, " / ")
check(pageText:find("Wolves Across the Border", 1, true) and pageText:find("Kill 8 Prowlers.", 1, true)
  and pageText:find("Prowler slain: 3/8", 1, true) and pageText:find("Rewards", 1, true), "its page: title, objectives, rewards")
check(rewardsUsed == 3 and buttons[1].name._text == "Worn Leather Gloves" and buttons[3].count._text == 3,
  "two choices and an item: three reward buttons (" .. rewardsUsed .. ")")

out("== a header folded in our list, the All tab, shift watches, the quest levels")
Rows()[1]:Click()
texts = RowTexts()
check(#texts == 3 and texts[1] == "Elwynn Forest" and texts[2] == "Westfall", "Elwynn folded: its quests gone")
check(LOG[1].isCollapsed ~= true, "the game's own log left as it is")
F().allTab.button:Click()
check(#RowTexts() == 2, "All: every header folded")
F().allTab.button:Click()
check(#RowTexts() == 5, "All again: every header open")
M.shift = true
Rows()[3]:Click()
M.shift = false
check(watched[101] == 0 and selected == 101 and Rows()[3].check:IsShown(), "shift-click: watched, picked, its check shown")
cvars.showQuestLevel = "1"
M.Fire("CVAR_UPDATE", "showQuestLevel")
Run()
check(Plain(Rows()[2].text._text) == "  [2] Wolves Across the Border", "the game's quest levels on: [2] before the title")

out("== abandon, the double pane, its place")
F().abandon:Click()
check(abandonSet == 101 and M.popup and M.popup.which == "ABANDON_QUEST" and M.popup.text:find("Kobold Camp Cleanup", 1, true),
  "Abandon: the game's own prompt for the picked quest")
M.popup = nil
F().dualToggle:Click()
check(ClassicQuestLogDB.dual == true and F():GetWidth() == 680 and F().showMap:IsShown(), "its radio: the double pane, Show Map")
Q.optionsPage:GetScript("OnShow")(Q.optionsPage)
check(Q.optionsDual:GetChecked() == true, "its options box follows")
Q.optionsDual:Click()
check(F():GetWidth() == 384 and ClassicQuestLogDB.dual == false and not F().dualToggle:GetChecked(), "its options box: one pane again")
F():ClearAllPoints()
F():SetPoint("TOPLEFT", UIParent, "TOPLEFT", 300, -200)
F().drag:GetScript("OnDragStart")()
F().drag:GetScript("OnDragStop")()
local pos = ClassicQuestLogDB.pos
check(pos and pos[1] == 300 and pos[2] == -200, "moved: its place kept (" .. tostring(pos and pos[1]) .. ", " .. tostring(pos and pos[2]) .. ")")

out("== made bigger or smaller by the grip on its bottom right corner (the whole window scaled), kept")
local grip = F().grip
local function Near(a, b) return math.abs(a - b) < 0.6 end
local function Ui(frame) local l, b, w, h = M.Rect(frame) local s = frame:GetScale() return l * s, (b + h) * s - UIParent:GetHeight() end
local function Centre(r) local l, b, w, h = M.Rect(r) return l + w / 2, b + h / 2 end
local fl, fb, fw, fh = M.Rect(F())
local gx, gy = Centre(grip)
check(grip and grip:IsShown() and Near(gx - fl, 350) and Near(fb + fh - gy, 465), "the grip on the art's corner (" .. (gx - fl) .. ", " .. (fb + fh - gy) .. ")")
grip:GetScript("OnEnter")(grip)
check(GameTooltip:IsOwned(grip) and GameTooltip._lines[1] == ns.L.QL_GRIP, "its tooltip: drag, right-click")
grip:GetScript("OnLeave")(grip)
local ui = UIParent:GetEffectiveScale()
local function DragTo(x, y) M.cursorX, M.cursorY = x * ui, (y + UIParent:GetHeight()) * ui grip:GetScript("OnUpdate")(grip, 0.02) end
grip:GetScript("OnMouseDown")(grip, "LeftButton")
check(grip:GetScript("OnUpdate") ~= nil, "pressed: it follows the mouse")
DragTo(300 + 350 * 1.5, -200 - 465 * 1.5)
check(Near(F():GetScale(), 1.5), "dragged: 1.5 times bigger (" .. F():GetScale() .. ")")
grip:GetScript("OnMouseUp")(grip, "LeftButton")
local x, y = Ui(F())
check(ClassicQuestLogDB.scale == 1.5 and Near(x, 300) and Near(y, -200), "let go: its size kept, its top left where it was (" .. x .. ", " .. y .. ")")
check(grip:GetScript("OnUpdate") == nil, "let go: no longer followed")
gx, gy = Centre(grip)
fl, fb, fw, fh = M.Rect(F())
check(Near(gx - fl, 350) and Near(fb + fh - gy, 465), "the grip still on its corner")
grip:GetScript("OnMouseDown")(grip, "LeftButton")
DragTo(300 + 350 * 0.3, -200 - 465 * 0.3)
grip:GetScript("OnMouseUp")(grip, "LeftButton")
check(ClassicQuestLogDB.scale == 0.6, "never smaller than 0.6 (" .. tostring(ClassicQuestLogDB.scale) .. ")")
grip:GetScript("OnMouseDown")(grip, "LeftButton")
DragTo(300 + 350 * 5, -200 - 465 * 5)
grip:GetScript("OnMouseUp")(grip, "LeftButton")
local big = ClassicQuestLogDB.scale
check(big <= 2 and 465 * big <= UIParent:GetHeight() + 1, "never bigger than the screen (" .. tostring(big) .. ")")
grip:GetScript("OnClick")(grip, "RightButton")
x, y = Ui(F())
check(ClassicQuestLogDB.scale == nil and F():GetScale() == 1 and Near(x, 300) and Near(y, -200), "right-click: its first size, in its place")
F().dualToggle:Click()
gx, gy = Centre(grip)
fl, fb, fw, fh = M.Rect(F())
check(Near(gx - fl, 680) and Near(fb + fh - gy, 439), "the double pane: on its corner too")
F().dualToggle:Click()

out("== Share: a secure pad over it, armed out of combat, away in combat")
S.group = "party"
M.Fire("GROUP_ROSTER_UPDATE")
Run()
local share = F().share
check(share:IsEnabled(), "in a group, a shareable quest: Share lit")
check(Plain(Rows()[2].text._text) == "  [2] [1] Wolves Across the Border", "the party on a quest: its count before the title")
Rows()[2]:GetScript("OnEnter")(Rows()[2])
local tip = table.concat(GameTooltip._lines or {}, " | ")
check(GameTooltip:IsOwned(Rows()[2]) and tip:find("party1", 1, true) ~= nil, "its tooltip names them (" .. tip .. ")")
Rows()[2]:GetScript("OnLeave")(Rows()[2])
-- (whole names: "First Surname", whatever the game's name settings hide)
UnitNameUnmodified = function(u) if u == "party1" then return "Elle", "Durand" end end
Run()
Rows()[2]:GetScript("OnEnter")(Rows()[2])
tip = table.concat(GameTooltip._lines or {}, " | ")
check(tip:find("Elle Durand", 1, true) ~= nil, "its tooltip: their whole names (" .. tip .. ")")
Rows()[2]:GetScript("OnLeave")(Rows()[2])
UnitNameUnmodified = nil
Run()
M.Tick()
local pad = share.pad
check(pad and pad._secure and pad:IsShown() and pad:GetFrameStrata() == "DIALOG", "the secure pad over it")
check((pad:GetAttribute("macrotext") or ""):find("/click [nomod] CQLS1", 1, true) ~= nil, "its macro: the map's own Share, pressed by the player")
M.Fire("PLAYER_REGEN_DISABLED")
S.inCombat = true
check(not pad:IsShown(), "a fight starts: the pad goes")
share:Click()
check(UIErrorsFrame.messages[#UIErrorsFrame.messages] == ERR_NOT_IN_COMBAT, "our click: not in combat")
M.Tick()
check(#M.blocked == 0, "nothing protected touched in combat (" .. table.concat(M.blocked, ", ") .. ")")
S.inCombat = false
M.Fire("PLAYER_REGEN_ENABLED")
M.Tick()
check(pad:IsShown(), "after the fight: back")

out("== a quest giver's window closes it; the micro button's pad opens it")
M.Fire("GOSSIP_SHOW")
check(not F():IsShown(), "a quest giver's window: closed")
M.Tick()
check(not pad:IsShown(), "its pads put away with it")
local micro = Q.microPad
check(micro and not micro._secure and micro:IsShown(), "a plain pad over the micro button")
local l, b, w, h = M.Rect(micro)
check(l == 900 and b == 4 and w == 24 and h == 32, "placed by measure over it")
micro:GetScript("OnEnter")(micro)
check(GameTooltip:IsOwned(micro) and QuestLogMicroButton._locked, "its tooltip, the button's glow")
micro:GetScript("OnLeave")(micro)
micro:Click()
Run()
check(F():IsShown() and microClicks == 0, "its click: our log (the game's map panel not opened)")
micro:Click()
check(not F():IsShown(), "and again: closed")
EditModeManagerFrame:Show()
M.Tick()
check(not micro:IsShown(), "Edit Mode: the pad away (the micro row is moved there)")
EditModeManagerFrame:Hide()
M.Tick()
check(micro:IsShown(), "back after Edit Mode")
S.inCombat = true
micro:Click()
check(F():IsShown(), "in combat: it opens too (our own window)")
F():Hide()
S.inCombat = false
check(#M.blocked == 0, "nothing blocked")

out("== /cql, its first size and place")
F():Hide()
SlashCmdList.CLASSICQUESTLOG("")
check(F():IsShown(), "/cql opens it")
SlashCmdList.CLASSICQUESTLOG("")
check(not F():IsShown(), "and shuts it")
ClassicQuestLogDB.scale, ClassicQuestLogDB.pos = 1.4, { 500, -300 }
Q.optionsReset:Click()
check(ClassicQuestLogDB.scale == nil and ClassicQuestLogDB.pos == nil and F():GetScale() == 1, "its options button: first size and place")
SlashCmdList.CLASSICQUESTLOG("options")
check(M.openedCategory ~= nil, "/cql options: its page")

out(string.format("\n%d failure(s)", fails))
return fails
