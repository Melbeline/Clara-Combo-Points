-- ClassicFriendsList with the game's new social window (Forever's default friends window): its own list left alone (a
-- line of ours in it made the game refuse its friend search); the characters in a panel of ours along its right side
-- while its friends page shows, in the 1.x list's look (online first, "Name, Level 42 Mage", the zone; grey, last
-- seen), our tooltip and menu layer on each row; the title counts them; a change redraws it; the wheel scrolls it
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

SocialUIFrame = CreateFrame("Frame", "SocialUIFrame", UIParent)
SocialUIFrame:Hide()
local page = CreateFrame("Frame", nil, SocialUIFrame)
SocialUIFrame.FriendsList = page
local box = CreateFrame("Frame", nil, page)
page.ScrollBox = box
local touched = 0
function box:SetDataProvider() touched = touched + 1 end
function box:RegisterCallback() touched = touched + 1 end
FriendsFrame = CreateFrame("Frame", "FriendsFrame", UIParent)
FriendsFrame:Hide()
C_AddOns = C_AddOns or {}
C_AddOns.IsAddOnLoaded = function() return false end
local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.LoadAddonAs(ADDON_DIR, "ClassicFriendsList.toc", "ClassicFriendsList", ns)
M.Fire("ADDON_LOADED", "ClassicFriendsList")
local A = ns.CFL
ClassicFriendsListDB.friends = { ["elle woods"] = { name = "Elle Woods" }, ["rose thorn"] = { name = "Rose Thorn", seen = 1000 } }
M.Fire("PLAYER_LOGIN")
local panel = A.panel
check(panel ~= nil and panel._parent == SocialUIFrame, "a panel of ours in the social window")
check(touched == 0 and box.SetDataProvider ~= nil, "the game's list untouched (not hooked, no callback)")
check(not panel:IsShown(), "hidden while the window is shut")

out("== the friends page shows: the characters beside it")
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "I|42|MAGE|Stranglethorn Vale", "WHISPER", "Elle Woods")
SocialUIFrame:Show()
page:Hide(); page:Show()
check(panel:IsShown(), "shown with the friends page")
check(panel.title._text == "Characters (1/2)", "its title: " .. tostring(panel.title._text))
local p = panel._points and panel._points[1]
check(p and p[1] == "TOPLEFT" and p[2] == SocialUIFrame and p[3] == "TOPRIGHT", "along the window's right side")
local first = panel._kids and nil
local rows = {}
for _, f in ipairs(M.frames) do if f._parent == panel and f._kind == "Button" and f.name then rows[#rows + 1] = f end end
check(#rows == 2, "two rows (" .. #rows .. ")")
check(rows[1].name._text == "Elle Woods, Level 42 Mage" or rows[1].name._text == "Elle Woods, Level 42 MAGE",
  "Elle online first: " .. tostring(rows[1].name._text))
check(rows[1].info._text == "Stranglethorn Vale", "her zone")
check(rows[2].name._text == "Rose Thorn" and rows[2].info._text:find("Last seen", 1, true) ~= nil, "Rose grey, last seen")
check(rows[1].classicFriend and rows[1].classicFriend.alt.name == "Elle Woods", "the tooltip and menu layer")

out("== a character added: redrawn")
A.Add("Lune Belle")
check(panel.title._text == "Characters (1/3)", "three now")

out("== the page hides (another tab): the panel too")
page:Hide()
check(not panel:IsShown(), "hidden")
check(touched == 0, "the game's list still untouched")
out(string.format("\n%d failure(s)", fails))
return fails
