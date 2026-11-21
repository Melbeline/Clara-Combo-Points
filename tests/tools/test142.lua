-- The mail's subject as in the base game (MailSubject.lua). WoW Forever's SendMailFrame_Update (copied below, its
-- subject part) names the mail only while C.O.D. can be used, and C.O.D. is off there. Clara, after each of its
-- updates: the first item's name (its count past one) while the subject is empty or still that name, following the
-- first item, gone with the last; a subject typed or a reply's kept; the setting off: the game's way. C.O.D. on: the
-- game names it, Clara has nothing to do, no window. The game fixed (it names the mail itself, C.O.D. off): a window
-- once, never again; a subject typed equal to an item's name is not taken for the fix.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

-- the game's mail (Blizzard_MailFrame, 1.60.1.70959)
local mail = {}
local cod, fixedGame = false, false
function HasSendMailItem(i) return mail[i] ~= nil end
function GetSendMailItem(i) local m = mail[i]; if m then return m[1], 100 + i, "tex", m[2], 1 end end
C_Mail = C_Mail or {}
C_Mail.IsCODEnabled = function() return cod end
ATTACHMENTS_MAX_SEND = 12
SendMailFrame = CreateFrame("Frame", "SendMailFrame", UIParent)
SendMailSubjectEditBox = CreateFrame("EditBox", "SendMailSubjectEditBox", SendMailFrame)
local box = SendMailSubjectEditBox
local updates = 0
function SendMailFrame_Update()
  updates = updates + 1
  local itemCount, itemTitle = 0, nil
  for i = 1, ATTACHMENTS_MAX_SEND do
    if HasSendMailItem(i) then
      itemCount = itemCount + 1
      local itemName, _, _, stackCount = GetSendMailItem(i)
      if not itemTitle and itemName then
        if stackCount <= 1 then itemTitle = itemName else itemTitle = itemName .. " (" .. stackCount .. ")" end
      end
    end
  end
  -- (Forever's test: C.O.D.; fixedGame: Blizzard's fix, the subject no longer tied to it)
  if itemCount > 0 and (C_Mail.IsCODEnabled() or fixedGame) then
    if box:GetText() == "" or box:GetText() == SendMailFrame.previousItem then
      itemTitle = itemTitle or ""
      box:SetText(itemTitle)
      SendMailFrame.previousItem = itemTitle
    end
  else
    if box:GetText() == SendMailFrame.previousItem then box:SetText("") end
    SendMailFrame.previousItem = ""
  end
end
local function Put(i, name, count) mail[i] = { name, count or 1 }; SendMailFrame_Update() end
local function Take(i) mail[i] = nil; SendMailFrame_Update() end
local function Empty() for i in pairs(mail) do mail[i] = nil end; SendMailFrame_Update() end
local function Subject() return box:GetText() end
local function Close() M.Fire("MAIL_CLOSED"); box:SetText(""); Empty() end -- (MailMixin:OnHide clears it)

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
GetBuildInfo = function() return "1.60.1", "71000", "Nov 25 2026", 16001 end -- (after loading: the build seen, kept)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("MAIL_SHOW")
box:SetText("")

out("== C.O.D. off (WoW Forever): the first item names the mail")
check(ns:MailSubject(), "on by default")
Put(1, "Linen Cloth")
check(Subject() == "Linen Cloth", "one item: its name (" .. Subject() .. ")")
Put(2, "Wool Cloth", 20)
check(Subject() == "Linen Cloth", "a second item: still the first's")
Take(1)
check(Subject() == "Wool Cloth (20)", "the first taken off: the next one's, with its count (" .. Subject() .. ")")
Put(1, "Silk Cloth", 1)
check(Subject() == "Silk Cloth", "another put first: its name, no (1)")
Empty()
check(Subject() == "", "all taken off: the subject goes")

out("== a subject typed, a reply's: kept")
box:SetText("For you")
Put(1, "Linen Cloth")
check(Subject() == "For you", "typed before: kept")
Empty()
check(Subject() == "For you", "the items taken off: still kept")
box:SetText("")
Put(1, "Linen Cloth")
box:SetText("Linen Cloth for you") -- (typed over it)
Put(2, "Wool Cloth")
Take(1)
check(Subject() == "Linen Cloth for you", "typed over Clara's: kept")
Empty(); box:SetText("RE: Hello")
Put(1, "Linen Cloth")
check(Subject() == "RE: Hello", "a reply's subject: kept")
Empty(); box:SetText("")

out("== an item not known yet, a secret name")
Put(1, nil)
check(Subject() == "", "no name yet: empty (as the game)")
mail[1] = { "Copper Ore", 5 }; SendMailFrame_Update()
check(Subject() == "Copper Ore (5)", "its name come: named")
Empty()
mail[1] = { M.Secret("Hidden"), 1 }
local ok = pcall(SendMailFrame_Update)
check(ok and Subject() == "", "a secret name: no error, left empty")
Empty()

out("== the mail closed, opened again")
Put(1, "Linen Cloth")
Close()
M.Fire("MAIL_SHOW")
Put(1, "Wool Cloth")
check(Subject() == "Wool Cloth", "a new mail: named again")
Empty()

out("== the setting off: the game's way; on again")
ns:SetMailSubject(false)
Put(1, "Linen Cloth")
check(Subject() == "", "off: left empty (WoW Forever's)")
ns:SetMailSubject(true)
Put(2, "Wool Cloth")
check(Subject() == "Linen Cloth", "on again: named at the next update")
Empty()

out("== C.O.D. on: the game names it itself, no window")
cod = true
Put(1, "Linen Cloth")
check(Subject() == "Linen Cloth" and SendMailFrame.previousItem == "Linen Cloth", "the game's name")
Take(1); Put(1, "Wool Cloth", 3)
check(Subject() == "Wool Cloth (3)", "follows")
Empty()
check(Subject() == "", "cleared")
check(M.popup == nil and not ns.sv.mailSubjectFixed, "no window (C.O.D. on is not the fix)")
cod = false

out("== a subject typed equal to an item's name, C.O.D. off: not the fix")
box:SetText("Linen Cloth")
Put(1, "Linen Cloth")
check(M.popup == nil and not ns.sv.mailSubjectFixed, "no window")
Empty(); box:SetText("")

out("== Blizzard's fix: the game names it itself, C.O.D. off: a window, once")
fixedGame = true
Put(1, "Linen Cloth")
check(Subject() == "Linen Cloth", "named (by the game)")
check(M.popup and M.popup.which == ns.MailSubjectFixedPopup, "the window")
check(M.popup and M.popup.text:find("Blizzard has fixed", 1, true), "its text (" .. tostring(M.popup and M.popup.text) .. ")")
check(ns.sv.mailSubjectFixed == "71000", "kept for the account (the build seen)")
if M.popup then M.PopupClick(1) end
Take(1); Put(2, "Wool Cloth", 2)
check(Subject() == "Wool Cloth (2)", "follows (the game, Clara with nothing to do)")
Empty()
check(Subject() == "", "cleared")
Put(1, "Silk Cloth")
check(M.popup == nil, "never again")
Empty()
out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
