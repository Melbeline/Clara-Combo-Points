-- The mail window's header in frFR: Sort by, its list, Add/remove categories, the title clear of Export / Import
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false } }
MailFrame = CreateFrame("Frame", "MailFrame", UIParent)
MailFrame:SetSize(338, 424)
MailFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -300)
SendMailFrame = CreateFrame("Frame", "SendMailFrame", MailFrame)
SendMailFrame:SetAllPoints(MailFrame)
SendMailNameEditBox = CreateFrame("EditBox", "SendMailNameEditBox", SendMailFrame)
SendMailNameEditBox:SetSize(109, 25)
SendMailNameEditBox:SetPoint("TOPLEFT", SendMailFrame, "TOPLEFT", 90, -30)
function SendMail() end
function UnitLevel() return 10 end
local ns = {}
S.class = "ROGUE"; S.locale = "frFR"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.Fire("MAIL_SHOW")
local panel = ns.Mail.panel
ns.Mail.toggle:Click()
local L = ns.L
local function Find(text) for _, f in ipairs(M.frames) do if f._parent == panel and f._kind == "Button" and f.GetText and f:GetText() == text then return f end end end
local sortButton
for _, f in ipairs(M.frames) do if f._parent == panel and f.text and f._kind == "Button" and not f.entry then sortButton = f end end
local label, manageB, exportB, importB = panel.sortLabel, Find(L.MAIL_MANAGE), Find(L.MAIL_EXPORT), Find(L.MAIL_IMPORT)
local title = panel.TitleContainer and panel.TitleContainer.TitleText
local titleRight = title and (title:GetLeft() + title:GetStringWidth()) or 0
check(label:GetText() == L.MAIL_SORT_BY and manageB and exportB and importB, "frFR labels")
check(sortButton:GetLeft() >= label:GetLeft() + label:GetStringWidth() and sortButton:GetWidth() >= 80, "the list right of Sort by, frFR")
check(manageB:GetLeft() >= sortButton:GetRight() and manageB:GetRight() <= panel:GetRight() - 10,
  ("Add/remove categories inside (%d..%d of %d)"):format(manageB:GetLeft() - panel:GetLeft(), manageB:GetRight() - panel:GetLeft(), panel:GetWidth()))
check(exportB:GetRight() <= importB:GetLeft() + 1 and titleRight <= exportB:GetLeft(),
  ("the title (to %d) clear of Export (from %d)"):format(titleRight - panel:GetLeft(), exportB:GetLeft() - panel:GetLeft()))
out("")
out(fails .. " failure(s)")
