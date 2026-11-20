-- Exact names in the Who window (Who.lua): a box left of the group finder's Who search line, the line made narrower
-- from its left for it (its search button and filter where they were); ticked, a name typed alone is put in quotes as
-- it is typed ("Charlotte"), the cursor before the closing quote; a search with a space, a digit or a filter left
-- alone; unticked: the quotes taken off again; kept for the account; its tooltip
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

C_FriendList = {
  GetNumWhoResults = function() return 0, 0 end,
  GetWhoInfo = function() return nil end,
  SendWho = function() end,
}
-- the game's Who tab (WhoList.xml): its search line at 56,-40, 255 wide, its search button after it
LFGWhoListFrame = CreateFrame("Frame", "LFGWhoListFrame", UIParent)
local edit = CreateFrame("EditBox", "WhoFrameEditBox", LFGWhoListFrame, "SearchBoxTemplate")
edit:SetSize(255, 20)
edit:SetPoint("TOPLEFT", LFGWhoListFrame, "TOPLEFT", 56, -40)
edit:SetFrameStrata("HIGH")
LFGWhoListFrame.EditBox = edit
local search = CreateFrame("Button", nil, LFGWhoListFrame)
search:SetPoint("LEFT", edit, "RIGHT", -6, -1)
LFGWhoListFrame.WhoSearch = search
local box = { SetDataProvider = function() end, GetParent = function() return LFGWhoListFrame end }
LFGWhoListFrame.ScrollBox = box

S.class = "ROGUE"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
M.Fire("ADDON_LOADED", "Blizzard_GroupFinder_VanillaStyle")

local exact = ns.WhoExactBox()
check(exact ~= nil and exact._parent == LFGWhoListFrame, "a box on the Who tab")
local p, rel, rp, x, y = edit:GetPoint(1)
check(p == "TOPLEFT" and rel == LFGWhoListFrame and x == 86 and y == -40 and edit:GetWidth() == 225,
  "the search line 30 further right and 30 narrower (" .. tostring(x) .. ", " .. tostring(edit:GetWidth()) .. ")")
check(x + edit:GetWidth() == 56 + 255, "its right end (and the search button after it) where it was")
local cp, crel, crp, cx = exact:GetPoint(1)
check(cp == "RIGHT" and crel == edit and crp == "LEFT" and cx == -8 and exact:GetWidth() == 22,
  "the box left of the line, where it began (22)")
check(not exact:GetChecked() and not ns:WhoExact(), "unticked by default")

local function Type(text)
  edit:SetText(text)
  edit:GetScript("OnTextChanged")(edit, true)
  return edit:GetText()
end
check(Type("charlotte") == "charlotte", "unticked: typed as it is")

exact:SetChecked(true); exact:GetScript("OnClick")(exact)
check(ns.sv.whoExact == true and ns:WhoExact(), "ticked: kept for the account")
check(edit:GetText() == '"charlotte"', "ticked: the name already typed put in quotes")
check(Type("c") == '"c"' and edit._cursor == 2, "a first letter typed: in quotes, the cursor before the closing one")
check(Type('"ch"') == '"ch"', "typing on inside the quotes: left as it is")
check(Type('""') == "", "its letters taken out: empty again (the line's Search shown)")
check(Type("Léa") == '"Léa"', "accents: in quotes too")
check(Type("charlotte moon") == "charlotte moon", "two words: left alone")
check(Type("z-elwynn") == "z-elwynn" and Type("60") == "60", "a filter or a level: left alone")
Type("silver")
exact:SetChecked(false); exact:GetScript("OnClick")(exact)
check(ns.sv.whoExact == nil and edit:GetText() == "silver", "unticked: the quotes taken off, nothing kept")
check(Type("moon") == "moon", "unticked: typed as it is again")

exact:SetChecked(false); ns.sv.whoExact = true
exact:GetScript("OnShow")(exact)
check(exact:GetChecked(), "shown again: ticked as kept")

exact:GetScript("OnEnter")(exact)
local tip = GameTooltip._lines or {}
check(GameTooltip._shown and tip[1] == "Exact names" and tostring(tip[2]):find('"Charlotte"', 1, true),
  "its tooltip: Exact names, what it does")

M.Fire("ADDON_LOADED", "Blizzard_GroupFinder_VanillaStyle")
local p2, _, _, x2 = edit:GetPoint(1)
check(x2 == 86 and edit:GetWidth() == 225 and ns.WhoExactBox() == exact, "made once: the line not moved twice")
out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
