-- The chat search's module (Modules/ChatSearch): the words found marked in the lines the window shows, in the style
-- picked on its page; the words found in a line's text by their bytes (colors, links' codes, icons left out; capitals,
-- accents and punctuation aside); each style's marks (A colored text; B, C, E, F behind the words where the game's own
-- text selection puts its own; D, E the current match's line; F lit a moment); colored where the game cannot tell;
-- drawn again as the window draws its lines (its own callback); taken off when the search is emptied; its page
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
C_Timer.NewTimer = C_Timer.NewTimer or function(d, fn) C_Timer.After(d, fn) return { Cancel = function() end } end
GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
GetCurrentRegionName = GetCurrentRegionName or function() return "EU" end
-- (every module off but this one)
ClaraComboPointsDB = { qol = setmetatable({}, { __index = function(_, k) return k == "chatsearch" end }) }

local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints")
local C = ns.ChatSearch
check(C and C.Spans and C.Marks and ns:QolRuns("chatsearch"), "a module of Clara's, on by default")

out("== the words in a line's text, by their bytes")
local function Words(text, query)
  local t = {}
  for _, sp in ipairs(C.Spans(text, ns:SearchKey(query))) do t[#t + 1] = text:sub(sp[1], sp[2]) end
  return table.concat(t, "|")
end
check(Words("|cffffff00Grand Mason says:|r come join me, Charlotte.", "charlotte") == "Charlotte", "past a color: Charlotte")
check(Words("|Hplayer:Charlotte Elle|h[Charlotte Elle]|h whispers: hi", "charlotte") == "Charlotte", "in a link: its text, not its code")
check(Words("Léa et LEA et lea", "lea") == "Léa|LEA|lea", "accents and capitals aside, each one")
check(Words("our little chat, Charlotte.", "chat charlotte") == "chat, Charlotte", "several words, punctuation aside")
check(Words("|TInterface\\Icons\\x:0|t Charlotte", "charlotte") == "Charlotte", "an icon left out")
check(Words("nothing here", "charlotte") == "", "none")

-- A chat window as the game draws it: 4 lines shown, the newest at the bottom; each line's text and where its
-- characters are (as the game's FontString tells them)
local window = { messages = {}, offset = 0, callbacks = {}, dirty = 0 }
window.FontStringContainer = CreateFrame("Frame", nil, UIParent)
local made = {} -- (the textures made on it, as the game would list its regions)
do
  local container = window.FontStringContainer
  local create = container.CreateTexture
  function container:CreateTexture(...)
    local t = create(self, ...)
    made[#made + 1] = t
    return t
  end
end
window.visibleLines = {}
for k = 1, 4 do
  local fs = window.FontStringContainer:CreateFontString(nil, "BACKGROUND", "ChatFontNormal")
  fs.CalculateScreenAreaFromCharacterSpan = function(_, a, b) return { { left = a * 5, bottom = 0, width = (b - a + 1) * 5, height = 12 } } end
  window.visibleLines[k] = fs
end
function window:GetNumMessages() return #self.messages end
function window:GetMessageInfo(i) return self.messages[i] end
function window:GetScrollOffset() return self.offset end
function window:GetNumVisibleLines() return 4 end
function window:AddOnDisplayRefreshedCallback(fn) table.insert(self.callbacks, fn) end
function window:Draw()
  local n = #self.messages
  for k, line in ipairs(self.visibleLines) do
    local msg = self.messages[n - (k + self.offset) + 1]
    if msg then line.messageInfo = { message = msg }; line:SetText(msg); line:Show() else line.messageInfo = nil; line:Hide() end
  end
  for _, fn in ipairs(self.callbacks) do fn(self) end
end
function window:SetScrollOffset(o) self.offset = o; self:Draw() end
function window:ScrollToBottom() self:SetScrollOffset(0) end
function window:MarkDisplayDirty() self.dirty = self.dirty + 1; self:Draw() end
window.messages = {
  "[04:06:12] [Charlotte Elle] whispers: tu viens ?",
  "[04:07:16] Reputation with Ironforge increased by 100.",
  "[04:07:45] Grand Mason Marblesten says: let's finish our little chat, Charlotte.",
  "[04:08:39] [3. General] [Yuri Khan]: looking for a rogue",
}
window:Draw()

local function Marks()
  local list = {}
  for _, tex in ipairs(made) do if tex:IsShown() then list[#list + 1] = tex end end
  return list
end
-- The line shown for a message (by its time)
local function Line(stamp)
  for _, line in ipairs(window.visibleLines) do
    local text = line:IsShown() and line:GetText()
    if text and text:find(stamp, 1, true) then return text end
  end
  return ""
end
local function Colors()
  local t = {}
  for _, tex in ipairs(Marks()) do
    local c = tex._color
    t[#t + 1] = c and ("%.2f"):format(c[4]) or "?"
  end
  table.sort(t)
  return table.concat(t, " ")
end

out("== E (by default): a faint background behind each, stronger on the current match, the bar in its line's margin")
check(ns:ChatSearchStyle() == "E" and ns.sv.chatSearch == nil, "E by default, nothing kept")
C.Typed(window, "charlotte")
local s = C.Search(window)
check(s.at == 1 and s.matches[1] == 3, "the newest match reached (the Grand Mason's line)")
check(#window.callbacks == 1, "the window's own drawing followed (its callback, once)")
local marks = Marks()
check(#marks == 3, "3 marks: 2 words, 1 bar (" .. #marks .. ")")
check(Colors() == "0.16 0.36 1.00", "a faint one, a stronger one, the bar: " .. Colors())
window:Draw()
check(#Marks() == 3, "drawn again as the window draws its lines: still 3, none left over")

out("== B: a gold background, orange on the current match")
ns:SetChatSearchStyle("B")
check(ns.sv.chatSearch.style == "B", "kept")
check(Colors() == "0.22 0.50", "two backgrounds: " .. Colors())

out("== C: a thin underline, thicker on the current match")
ns:SetChatSearchStyle("C")
local heights = {}
for _, tex in ipairs(Marks()) do heights[#heights + 1] = tex._h end
table.sort(heights)
check(#heights == 2 and heights[1] == 1 and heights[2] == 2, "1 and 2 pixels")

out("== D: the current match's line, a band and a bar; the words themselves unmarked")
ns:SetChatSearchStyle("D")
check(#Marks() == 2, "a band and a bar (" .. #Marks() .. ")")

out("== F: the current match's line lit a moment as it is reached, a faint background behind its word")
ns:SetChatSearchStyle("F")
C.Step(window, 1)
check(C.Search(window).at == 2, "the next match reached (the whisper)")
check(#Marks() == 2, "its word's background and the lit line (" .. #Marks() .. ")")

out("== A: the words colored, the current one white, the line's color taken up again after them")
ns:SetChatSearchStyle("A")
check(#Marks() == 0, "no texture")
local whisper, mason = Line("04:06:12"), Line("04:07:45")
check(whisper:find("|cffffffffCharlotte|r", 1, true) ~= nil, "the current one white: " .. whisper)
check(mason:find("|cfffff2c8Charlotte|r", 1, true) ~= nil, "the other one light: " .. mason)
window.messages[3] = "[04:07:45] |cffff8000Grand Mason says: chat, Charlotte, again|r"
window:Draw()
check(Line("04:07:45"):find("|cfffff2c8Charlotte|r|cffff8000, again", 1, true) ~= nil, "inside a color: that color back after it")
window.messages[3] = "[04:07:45] Grand Mason Marblesten says: let's finish our little chat, Charlotte."

out("== none: nothing marked")
ns:SetChatSearchStyle("none")
check(#Marks() == 0 and not Line("04:06:12"):find("|cff", 1, true), "no mark, the text as it is")

out("== where the game cannot tell where the words are: colored")
ns:SetChatSearchStyle("E")
for _, line in ipairs(window.visibleLines) do line.CalculateScreenAreaFromCharacterSpan = nil end
window:Draw()
check(Line("04:06:12"):find("|cffffffffCharlotte|r", 1, true) ~= nil, "the current one colored instead")
check(#Marks() == 1, "the bar in its line's margin all the same")

out("== the search emptied: the marks taken off, the lines drawn again as they were")
local dirty = window.dirty
C.Typed(window, "")
check(#Marks() == 0 and window.dirty > dirty and not Line("04:07:45"):find("|cff", 1, true), "nothing left")
ns:SetChatSearchStyle("E")
check(ns.sv.chatSearch == nil, "the default picked again: nothing kept")

out("== its page: its place, the style picked (one at a time)")
local page = ns.ChatSearchPage
page:Show()
page:GetScript("OnShow")(page)
local P = ns.ChatSearchParts
check(P.dock and P.styleE and P.styleA and P.stylenone, "its place's box and the styles' boxes")
check(P.dock:GetChecked() and P.styleE:GetChecked() and not P.styleB:GetChecked(), "beside the tabs, E ticked")
P.styleB:SetChecked(true); P.styleB:GetScript("OnClick")(P.styleB)
check(ns:ChatSearchStyle() == "B" and P.styleB:GetChecked() and not P.styleE:GetChecked(), "B picked: B ticked, E no longer")
P.styleB:SetChecked(false); P.styleB:GetScript("OnClick")(P.styleB)
check(ns:ChatSearchStyle() == "B" and P.styleB:GetChecked(), "the one ticked clicked again: stays")
P.dock:SetChecked(false); P.dock:GetScript("OnClick")(P.dock)
check(ns.sv.chatSearchDock == false, "its place: in the tabs' menu")
P.dock:SetChecked(true); P.dock:GetScript("OnClick")(P.dock)
check(ns.sv.chatSearchDock == nil, "back beside the tabs")
check(ns.qolSwitches.chatsearch and ns.qolSwitches.chatsearch[1].label == "SP_CHATSEARCH_DOCK", "its place's box on its card too")
out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
