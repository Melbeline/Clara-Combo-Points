-- Clara Combo Points - the mail's subject as in the base game (1.15.9 as every other): the first item put in a mail
-- names it ("Linen Cloth", "Linen Cloth (20)") while its subject is empty or still the name an item gave it; the name
-- follows the first item (another put first, the first taken off); the items all taken off, it goes. A subject typed,
-- or a reply's, is kept. WoW Forever's mail does it only while C.O.D. can be used (SendMailFrame_Update: the subject
-- inside its C.O.D. test), and C.O.D. is off there: its subject stays empty. Done right after each of the game's
-- updates of the mail, by the game's own rule, its code untouched (its record of the name it gave, only read).
-- Clara steps in only while the game fails: after the game's update, the subject it should have named still empty.
-- Should the game be seen naming a mail itself while C.O.D. is off (Blizzard's fix), a window says so, once, and Clara
-- stands aside (the subject is never empty nor Clara's any more when it looks); should the game leave it empty again
-- one day, Clara names it again, by itself, as long as the game fails to (and a later fix is told again).
-- A mail with no item and money sent (Send Money, not C.O.D.) is named after the money: "15 gold", "15 gold, 13 silver",
-- following the amount as it is typed (the game's own check of the mail at each change of it), gone when the money is.
-- On by default; its box on Clara's page. (Unticked when the fix was told, before Clara stood aside by itself: ticked
-- again once, the player having asked for it to come back on its own.)

local ADDON, ns = ...
local L = ns.L

local given -- the subject Clara gave the mail (an item's name), as the box holds it

function ns:MailSubject()
  local sv = self.sv
  if sv and not sv.mailSubjectAuto then -- (once: the box unticked on the fix's advice, ticked again)
    sv.mailSubjectAuto = true
    if sv.mailSubject == false and sv.mailSubjectFixed then sv.mailSubject = nil end
  end
  return not sv or sv.mailSubject ~= false
end
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

-- The money the mail sends (none for a C.O.D.: asked for, not sent)
local function Money()
  if not (SendMailMoney and MoneyInputFrame_GetCopper) then return 0 end
  local send = SendMailSendMoneyButton
  if send and send.GetChecked and not send:GetChecked() then return 0 end
  local ok, copper = pcall(MoneyInputFrame_GetCopper, SendMailMoney)
  if not ok or Secret(copper) then return 0 end
  return math.max(0, math.floor(tonumber(copper) or 0))
end

-- The money as a mail's name: "15 gold", "15 gold, 13 silver", "2 silver, 50 copper"; none for none
local function MoneyTitle(copper)
  if not copper or copper <= 0 then return nil end
  local parts = {}
  local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  if gold > 0 then parts[#parts + 1] = L.MAIL_GOLD:format(gold) end
  if silver > 0 then parts[#parts + 1] = L.MAIL_SILVER:format(silver) end
  if rest > 0 then parts[#parts + 1] = L.MAIL_COPPER:format(rest) end
  return table.concat(parts, ", ")
end
ns.MailMoneyTitle = MoneyTitle -- (for the tests)

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

-- The game seen failing again (the subject it should have named left empty): Clara names it, and a later fix is told
local function Failing()
  local sv = ns.sv
  if sv and sv.mailSubjectFixed then sv.mailSubjectFixed = nil end
end

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
  -- the game failing: an item's name to give, the subject left empty
  if any and title and subject == "" then Failing() end
  if not ns:MailSubject() then return end
  -- no item: the money sent, if any, names it
  if not any then title = MoneyTitle(Money()) end
  if any or title then
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
  -- (the game's check of the mail: at each change of the money, of the subject and of the name)
  if SendMailFrame_CanSend then hooksecurefunc("SendMailFrame_CanSend", Update) end
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
