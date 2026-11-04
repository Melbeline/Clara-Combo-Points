-- The wheel turns a book's pages (WheelPages.lua): its text scrolls first, then the page turns; the first and
-- last pages stop it (no wrap)
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false,
  wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false, mail = false, classicui = false, tullarange = false,
  names = false, tooltipanchor = false, idtip = false, soloraidframe = false, enemycasts = false, reverseengineering = false } }
-- the game's book window: 3 pages; its text area scrolls 40 at most
local page, pages = 1, 3
ItemTextFrame = CreateFrame("Frame", "ItemTextFrame", UIParent)
ItemTextScrollFrame = CreateFrame("ScrollFrame", "ItemTextScrollFrame", ItemTextFrame)
ItemTextPrevPageButton = CreateFrame("Button", "ItemTextPrevPageButton", ItemTextFrame)
ItemTextNextPageButton = CreateFrame("Button", "ItemTextNextPageButton", ItemTextFrame)
local function Buttons() ItemTextPrevPageButton:SetShown(page > 1); ItemTextNextPageButton:SetShown(page < pages); ItemTextScrollFrame:SetVerticalScroll(0) end
Buttons()
function ItemTextFrame_NextPageOnClick() page = page + 1; Buttons() end
function ItemTextFrame_PrevPageOnClick() page = page - 1; Buttons() end
ItemTextScrollFrame:SetScript("OnMouseWheel", function(self, delta)
  local v = math.max(0, math.min(40, self:GetVerticalScroll() - delta * 20))
  self:SetVerticalScroll(v)
end)

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")

local frameWheel = ItemTextFrame:GetScript("OnMouseWheel")
local textWheel = ItemTextScrollFrame:GetScript("OnMouseWheel")
check(frameWheel ~= nil and textWheel ~= nil, "the window and its text take the wheel")
frameWheel(ItemTextFrame, 1)
check(page == 1, "page 1, wheel up: stays on the first page (no wrap)")
textWheel(ItemTextScrollFrame, -1)
check(page == 1 and ItemTextScrollFrame:GetVerticalScroll() == 20, "over a long text: it scrolls first")
textWheel(ItemTextScrollFrame, -1)
check(page == 1 and ItemTextScrollFrame:GetVerticalScroll() == 40, "still text to scroll: scrolls")
textWheel(ItemTextScrollFrame, -1)
check(page == 2, "at the end of the text: the next page")
frameWheel(ItemTextFrame, -1)
check(page == 3, "over the frame: the next page at once")
frameWheel(ItemTextFrame, -1)
check(page == 3, "last page, wheel down: stays (no wrap)")
frameWheel(ItemTextFrame, 1)
check(page == 2, "wheel up: the previous page")
textWheel(ItemTextScrollFrame, 1)
check(page == 1, "over the text at its top, wheel up: the previous page")

out(fails .. " failure(s)")
