-- Clara's page in the game's options (SettingsPage.lua) laid out in any width: the whole page in a scroll frame (taller
-- than the game's panel: it scrolls, nothing under the panel's bottom); each box's words wrapped in the page's width,
-- the next box under them; the fishing box hidden (its module off): no gap left; the boxes' order kept.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false, tullarange = false, names = false,
  tooltipanchor = false, fishing = false } }
local ns = {}
S.class = "ROGUE"; S.locale = "frFR"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
SettingsPanel:SetSize(640, 560)
M.ShowSettingsPage(ns.settingsCategory)
local page = ns.settingsCategory.frame
local body = page.body
check(body ~= nil and _G.ClaraComboPointsSettingsScroll ~= nil, "the page in a scroll frame")
local scroll = _G.ClaraComboPointsSettingsScroll
M.ResetLayout()
local _, _, sw, sh = M.AbsRect(scroll)
local _, _, bw, bh = M.AbsRect(body)
check(bh > sh, ("taller than the panel (%d over %d): it scrolls"):format(bh, sh))
check(math.abs(bw - sw) <= 1, "as wide as the panel's room")

out("== the boxes, one under the other, their words in the width")
local order = { "quietLogin", "whoNames", "noBlink", "threatBox", "disenchant", "interactIcons", "levelShots", "bossShots",
  "muteConduct", "chatFocus", "mailSubject", "questShareBubble", "sitKey", "legacyTree" }
local prev, inside, below = nil, true, true
for _, field in ipairs(order) do
  local box = page[field]
  if box then
    local text = box.Text or box.text
    local bl, bb, bw2, bh2 = M.AbsRect(box)
    local tl, tb, tw, th = M.AbsRect(text)
    local left = M.AbsRect(body)
    if tl + tw > left + bw + 1 then inside = false; out("    past the right: " .. field) end
    if prev then
      local pl, pb, pw, ph = M.AbsRect(prev)
      local ptext = prev.Text or prev.text
      local _, ptb = M.AbsRect(ptext)
      if bb + bh2 > ptb + 1 then below = false; out("    over the words of the one before: " .. field) end
    end
    prev = box
  end
end
check(inside, "no words past the page's right edge")
check(below, "each box under the words of the one before")
local long = page.chatFocus
local lt = long.Text or long.text
check(lt:GetStringHeight() > 12, "a long one on several lines (" .. math.floor(lt:GetStringHeight()) .. ")")

out("== the fishing box hidden: no gap")
check(not page.fishingMode:IsShown(), "the module off: its box hidden")
local _, _, _, _, y1 = page.disenchant:GetPoint(1)
local _, _, _, _, y2 = page.interactIcons:GetPoint(1)
local _, db = M.AbsRect(page.disenchant)
check(y1 - y2 <= 40, ("the next box right under the disenchant one (%d)"):format(y1 - y2))
out("")
out(fails .. " failure(s)")
