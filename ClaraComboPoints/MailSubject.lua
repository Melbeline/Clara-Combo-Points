-- Clara Combo Points - the mail's subject as in the base game (1.15.9 as every other): the first item put in a mail
-- names it ("Linen Cloth", "Linen Cloth (20)") while its subject is empty or still the name an item gave it; the name
-- follows the first item (another put first, the first taken off); the items all taken off, it goes. A subject typed,
-- or a reply's, is kept. WoW Forever's mail does it only while C.O.D. can be used (SendMailFrame_Update: the subject
-- inside its C.O.D. test), and C.O.D. is off there: its subject stays empty. Done right after each of the game's
-- updates of the mail, by the game's own rule, its code untouched (its record of the name it gave, only read).
-- Should the game be seen naming a mail itself while C.O.D. is off (Blizzard's fix), a window says so, once; Clara's
-- naming then has nothing left to do (the subject is never empty nor Clara's any more when it looks).
-- On by default; its box on Clara's page.

local ADDON, ns = ...
local L = ns.L

local given -- the subject Clara gave the mail (an item's name), as the box holds it

function ns:MailSubject() return not self.sv or self.sv.mailSubject ~= false end
function ns:SetMailSubject(on)
  if not self.sv then return end
  if on then self.sv.mailSubject = nil else self.sv.mailSubject = false end
  given = nil
end

local function Secret(v) return issecretvalue and issecretvalue(v) end

-- Whether the mail holds items, and the name the game gives it: its first item's, with its count past one
local function Items()
  local any, title = false, nil
  for i = 1, ATTACHMENTS_MAX_SEND or 12 do
    if HasSendMailItem(i) then
      any = true
      if not title then
        local name, _, _, count = GetSendMailItem(i)
        if not Secret(name) and type(name) == "string" and name ~= "" then
          count = not Secret(count) and tonumber(count) or 1
          title = count <= 1 and name or (name .. " (" .. count .. ")")
        end
      end
    end
  end
  return any, title
end

local function CodOn() return (C_Mail and C_Mail.IsCODEnabled and C_Mail.IsCODEnabled()) and true or false end
local function Build() return GetBuildInfo and tostring((select(2, GetBuildInfo()))) or "?" end

-- Blizzard's fix seen: said once (the account's)
local POPUP = "CLARA_MAIL_SUBJECT_FIXED"
local function Fixed()
  local sv = ns.sv
  if not sv or sv.mailSubjectFixed then return end
  sv.mailSubjectFixed = Build()
  if not (StaticPopupDialogs and StaticPopup_Show) then return end
  StaticPopupDialogs[POPUP] = StaticPopupDialogs[POPUP] or {
    text = L.MAIL_SUBJECT_FIXED, button1 = OKAY or "OK", timeout = 0, whileDead = true, hideOnEscape = true,
  }
  StaticPopup_Show(POPUP)
end
ns.MailSubjectFixedPopup = POPUP

local function Update()
  local box = SendMailSubjectEditBox
  if not (box and HasSendMailItem and GetSendMailItem) then return end
  local subject = box:GetText()
  if Secret(subject) or type(subject) ~= "string" then return end
  local any, title = Items()
  -- the game named it itself (its own record of the name it gave), C.O.D. off: fixed
  if any and title and subject == title and not CodOn() and SendMailFrame and SendMailFrame.previousItem == subject then
    Fixed()
  end
  if not ns:MailSubject() then return end
  if any then
    if subject == "" or (given and subject == given) then
      if subject ~= (title or "") then box:SetText(title or "") end
      given = box:GetText()
    end
  else
    if given and given ~= "" and subject == given then box:SetText("") end
    given = nil
  end
end
ns.MailSubjectUpdate = Update

local hooked = false
local function Hook()
  if hooked or not (SendMailFrame_Update and SendMailSubjectEditBox) then return end
  hooked = true
  hooksecurefunc("SendMailFrame_Update", Update)
end

if EventUtil and EventUtil.ContinueOnAddOnLoaded then
  EventUtil.ContinueOnAddOnLoaded("Blizzard_MailFrame", Hook)
end
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("MAIL_SHOW")
events:RegisterEvent("MAIL_CLOSED")
events:SetScript("OnEvent", function(_, event)
  if event == "MAIL_CLOSED" then given = nil else Hook() end
end)
