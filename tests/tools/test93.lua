-- The game's Add Friend window in the 1.x look (AltFriends.lua): the 1.15 page drawn over it (title, the Battle.net and
-- faction icons, OR), the game's box moved to the top line and its two buttons to the 1.15 spots, restyled; a bottom line
-- that adds a character to Clara's list at once. The game's code left alone: its own Enter and Add Friend send the top
-- line (both lines typed: the bottom one added after it), its "?" page keeps the game's border
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

M.showKids = true -- (as the game: a child's OnShow runs as its parent shows)
ADD_FRIEND = "Add Friend"; SEND_REQUEST = "Send Request"; OR_CAPS = "OR"; CHARACTER_FRIEND = "Character"
ERR_FRIEND_ADDED_S = "%s added to friends."
FriendsFrame = CreateFrame("Frame", "FriendsFrame", UIParent)
FriendsFrame:Hide()
M.TEMPLATES.AutoCompleteEditBoxTemplate = function() end
AUTOCOMPLETE_LIST = { MAIL = { include = 1, exclude = 2 }, ADDFRIEND = { include = 3, exclude = 4 } }
C_AutoComplete = { GetAutoCompleteResults = function() return {} end }
function AutoCompleteEditBox_SetAutoCompleteSource(box, fn, include, exclude) box.autoCompleteSource = fn; box.autoCompleteInclude = include end
function AutoCompleteEditBox_OnEnterPressed() return false end
function AutoCompleteEditBox_OnTextChanged() return false end
function AutoCompleteEditBox_OnTabPressed() return false end
function AutoCompleteEditBox_OnEscapePressed() return false end

-- The game's window, as its XML and Lua make it (the parts Clara touches)
local popups = {}
function StaticPopupSpecial_Show(f) popups[#popups + 1] = "show"; f:Show() end
function StaticPopupSpecial_Hide(f) popups[#popups + 1] = "hide"; f:Hide() end
local frame = CreateFrame("Frame", "AddFriendFrame", UIParent)
frame:Hide()
frame.Border = CreateFrame("Frame", nil, frame)
frame.CloseButton = CreateFrame("Button", nil, frame)
local info = CreateFrame("Frame", "AddFriendInfoFrame", frame)
info:Hide()
local entry = CreateFrame("Frame", "AddFriendEntryFrame", frame)
entry:Hide()
local infoButton = CreateFrame("Button", "AddFriendEntryFrameInfoButton", entry)
entry.TitleContainer = CreateFrame("Frame", nil, entry)
entry.OptionsContainer = CreateFrame("Frame", nil, entry)
local holder = CreateFrame("Frame", nil, entry.OptionsContainer)
entry.OptionsContainer.LeftTextContainer = holder
holder.Title = holder:CreateFontString(nil, "BACKGROUND", "GameFontNormalLarge")
holder.Description = holder:CreateFontString(nil, "BACKGROUND", "GameFontHighlight")
local container = CreateFrame("Frame", nil, entry)
entry.EditBoxContainer = container
container.ErrorMessage = container:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
container.RequestInfoText = container:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
local box = CreateFrame("EditBox", "AddFriendNameEditBox", container)
box.Left = box:CreateTexture(nil, "BACKGROUND")
box.Right = box:CreateTexture(nil, "BACKGROUND")
AddFriendNameEditBoxMiddle = box:CreateTexture(nil, "BACKGROUND")
AddFriendNameEditBoxFill = box:CreateFontString(nil, "BORDER", "GameFontDisableSmall")
local accept = CreateFrame("Button", "AddFriendEntryFrameAcceptButton", container)
local cancel = CreateFrame("Button", "AddFriendEntryFrameCancelButton", container)
accept:SetText(SEND_REQUEST)
local sent = {}
function AddFriendFrame_Accept()
  sent[#sent + 1] = box:GetText()
  StaticPopupSpecial_Hide(frame)
end
accept:SetScript("OnClick", AddFriendFrame_Accept) -- (the XML's function="AddFriendFrame_Accept": the function itself)
cancel:SetScript("OnClick", function() StaticPopupSpecial_Hide(frame) end)
function AddFriendEntryFrame_Init(clearText)
  accept:SetText(SEND_REQUEST)
  if clearText then box:SetText("") end
end
box:SetScript("OnTextChanged", function(self)
  AddFriendEntryFrame_Init()
  accept:SetEnabled(self:GetText() ~= "")
end)
box:SetScript("OnEnterPressed", function() if accept:IsEnabled() then AddFriendFrame_Accept() end end)
box:SetScript("OnTabPressed", function() end)
local bnetUp = true
local function ShowEntry()
  if bnetUp then
    holder.Title:SetText("BattleTag"); holder.Title:SetAlpha(1)
    holder.Description:SetText("Enter a BattleTag"); holder.Description:SetTextColor(1, 1, 1)
  else
    holder.Title:SetAlpha(0.35)
    holder.Description:SetText("Battle.net Unavailable"); holder.Description:SetTextColor(1, 0, 0)
  end
  info:Hide()
  entry:Show()
end
local function ShowInfo() info:Show(); entry:Hide() end
function AddFriendFrame_Show()
  AddFriendEntryFrame_Init(true)
  StaticPopupSpecial_Show(frame)
  ShowEntry()
end

local ns = {}
S.class = "PRIEST"; S.locale = "enUS"; S.faction = "Horde"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
local A = ns.AltFriends
local page, charBox, charAccept = A.addPage, A.charBox, A.charAccept
local function Point(r) return r._points and r._points[1] or {} end
local function Listed(name) return (ns.sv.altFriends or {})[name:lower()] ~= nil end
local function Said(pat) local n = 0 for _, l in ipairs(M.chat) do if l:find(pat, 1, true) then n = n + 1 end end return n end
local function Type(e, text) M.Type(e, text) end
local function Press(e, script) local fn = e:GetScript(script) if fn then fn(e) end end
local function Texts(f)
  local t = {}
  for _, r in ipairs(M.regions) do if r._parent == f and r._kind == "FontString" and r._text then t[#t + 1] = r._text end end
  return table.concat(t, " | ")
end

out("== made at login, over the game's window")
check(page and charBox and charAccept and page._parent == entry, "the 1.15 page, a child of the game's entry page")
check(page._backdrop and page._backdrop.edgeFile == "Interface\\DialogFrame\\UI-DialogBox-Border", "the 1.x dialog border")
check(page._w == 384 and page._h == 264, "the 1.15 size, a line taller")
local texts = Texts(page)
check(texts:find("Add Friend", 1, true) and texts:find("OR", 1, true) and texts:find("Character", 1, true), "its title, OR, Character (" .. texts .. ")")
check(not entry.TitleContainer:IsShown() and not entry.OptionsContainer:IsShown() and not container.RequestInfoText:IsShown(),
  "the game's title, its two columns and its request text: hidden")
local p = Point(box)
check(p[1] == "TOP" and p[2] == page and p[5] == -130, "the game's box: the top line")
p = Point(charBox)
check(p[1] == "TOP" and p[2] == page and p[5] == -162, "Clara's box: the line under it")
check(charBox.autoCompleteSource and charBox.autoCompleteInclude == 1, "Clara's box: the mail's suggestions (the account's characters)")
p = Point(accept)
check(p[1] == "BOTTOMLEFT" and p[4] == 45 and p[5] == 30 and accept._w == 118, "the game's Add Friend button: the 1.15 spot")
p = Point(cancel)
check(p[1] == "BOTTOMRIGHT" and p[4] == -50 and cancel._w == 118, "Cancel: the 1.15 spot")
check(accept._normalTex == "Interface\\Buttons\\UI-Panel-Button-Up" and cancel._normalTex == accept._normalTex
  and charAccept._normalTex == accept._normalTex, "the three buttons: the 1.x red button")
check(box.Left:GetTexture() == "Interface\\Common\\Common-Input-Border", "the game's box: the 1.x border")
check(Point(infoButton)[1] == "LEFT", "the game's ? by the title")

out("== opened by the game's Add Friend")
AddFriendFrame_Show()
check(frame:IsShown() and page:IsVisible(), "the 1.15 page shows")
check(not frame.Border:IsShown() and not frame.CloseButton:IsShown(), "the game's border and cross off")
check(accept:GetText() == "Add Friend", "the game's button says Add Friend (the 1.15 word)")
check(Texts(page):find("BattleTag | Enter a BattleTag", 1, true) ~= nil or Texts(page):find("Enter a BattleTag", 1, true) ~= nil,
  "the left column: the game's own words")
local horde = false
for _, r in ipairs(M.regions) do if r._parent == page and r._file == "Interface\\FriendsFrame\\PlusManz-Horde" then horde = true end end
check(horde, "the faction's icon (Horde)")
check(not accept:IsShown() and charAccept:IsShown() and not charAccept:IsEnabled(), "nothing typed: the button off")

out("== the bottom line: a character added at once")
Type(charBox, "Melbeline Moon")
check(charAccept:IsShown() and charAccept:IsEnabled(), "typed: the button on")
Press(charBox, "OnEnterPressed")
check(Listed("Melbeline Moon"), "in Clara's list")
check(Said("Melbeline Moon added to friends.") == 1, "said as the game says it")
check(not frame:IsShown() and popups[#popups] == "hide", "the window shut (the game's way)")
check(#sent == 0, "nothing sent to the game")

out("== opened again: empty; both lines, the game's button")
AddFriendFrame_Show()
check(charBox:GetText() == "", "the bottom line empty again")
Type(box, "Someone#1234")
check(accept:IsShown() and accept:IsEnabled() and not charAccept:IsShown(), "the top line typed: the game's own button")
check(accept:GetText() == "Add Friend", "still Add Friend after the game's Init")
Type(charBox, "Clara Sun")
accept:Click()
check(sent[1] == "Someone#1234", "the game sent the top line")
check(Listed("Clara Sun") and Said("Clara Sun added to friends.") == 1, "the bottom line added after it, once")

out("== both lines, Enter in the top line")
AddFriendFrame_Show()
Type(box, "Other#5678"); Type(charBox, "Rae Moon")
Press(box, "OnEnterPressed")
check(sent[2] == "Other#5678", "the game sent the top line")
check(Listed("Rae Moon") and Said("Rae Moon added to friends.") == 1, "the bottom line added, once")

out("== the bottom line's Enter with the top typed: added, the window kept for the top")
AddFriendFrame_Show()
Type(box, "Third#1"); Type(charBox, "Lune Belle")
Press(charBox, "OnEnterPressed")
check(Listed("Lune Belle") and frame:IsShown() and #sent == 2, "added, the window open, nothing sent")
Type(charBox, "Lune Belle")
Press(charBox, "OnEnterPressed")
check(Said("Lune Belle added to friends.") == 1 and Said("is already") + Said("already") >= 1, "twice: already in the list")
Press(cancel, "OnClick")

out("== Tab between the two lines")
AddFriendFrame_Show()
Press(box, "OnTabPressed")
check(charBox:HasFocus(), "top → bottom")
Press(charBox, "OnTabPressed")
check(box:HasFocus(), "bottom → top")

out("== the game's ? page: its own border back; then the entry page again")
ShowInfo()
check(frame.Border:IsShown() and frame.CloseButton:IsShown(), "the game's border and cross back")
ShowEntry()
check(not frame.Border:IsShown(), "the 1.15 page again")
Press(cancel, "OnClick")

out("== Battle.net down: the left column greyed and red, as the game's")
bnetUp = false
AddFriendFrame_Show()
local headAlpha, red
for _, r in ipairs(M.regions) do
  if r._parent == page and r._kind == "FontString" then
    if r._text == "BattleTag" then headAlpha = r:GetAlpha() end
    if r._text == "Battle.net Unavailable" then red = r._tc and r._tc[1] == 1 and r._tc[2] == 0 end
  end
end
check(headAlpha == 0.35 and red, "greyed title, the red line")
out(string.format("\n%d failure(s)", fails))
return fails
