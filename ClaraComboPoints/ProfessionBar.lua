-- Clara Combo Points - the professions window's rank bar ("Tailoring 230/300") in 1.15.9's skin: the bar of Classic
-- Era's trade skill window (its blue fill on the skill bar texture, its dark blue backing, its rounded silver border),
-- in place of WoW Forever's (its background, animated fill, flare and frame are hidden). The text stays the game's,
-- centered; the expansion button on its right stays. The fill follows the game's own updates of the bar (its rank
-- read there), at once, as 1.15.9 has it (no sliding).

local ADDON, ns = ...

local BAR = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar"
local BORDER = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder"
local HEIGHT = 15
-- Where the game draws its fill (its template: 5 from the left, 3 down, 18 high, 441 wide): the classic bar on its
-- middle line
local LEFT, TOP, FILL_W, FILL_H = 5, -3, 441, 18

local function Piece(bar, l, r)
  local t = bar:CreateTexture(nil, "OVERLAY")
  t:SetTexture(BORDER)
  t:SetTexCoord(l, r, 0.193548, 0.774193) -- (the game's own cut of it: ProfessionsStatusBarArtTemplate)
  return t
end

-- The classic bar on one of the game's rank bars
local function Dress(rankBar)
  if rankBar.claraClassicBar then return rankBar.claraClassicBar end
  local bar = CreateFrame("StatusBar", nil, rankBar)
  bar:SetHeight(HEIGHT)
  bar:SetPoint("LEFT", rankBar, "TOPLEFT", LEFT + 1, TOP - FILL_H / 2)
  bar:SetPoint("RIGHT", rankBar, "TOPLEFT", LEFT + FILL_W - 1, TOP - FILL_H / 2)
  bar:SetStatusBarTexture(BAR)
  bar:SetStatusBarColor(0, 0, 1, 0.5) -- (Era's: the fill blue at half)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  local back = bar:CreateTexture(nil, "BACKGROUND")
  back:SetAllPoints(bar)
  back:SetColorTexture(1, 1, 1, 0.2)
  back:SetVertexColor(0, 0, 0.75, 0.5) -- (its backing: faint white, tinted blue)
  local h = math.floor(HEIGHT * 18 / 14 + 0.5)
  local left, right = Piece(bar, 0.007843, 0.043137), Piece(bar, 0.043137, 0.007843)
  left:SetSize(9, h)
  left:SetPoint("LEFT", bar, "LEFT", -2, 0)
  right:SetSize(9, h)
  right:SetPoint("RIGHT", bar, "RIGHT", 3, 0)
  local mid = Piece(bar, 0.113726, 0.1490196)
  mid:SetPoint("TOPLEFT", left, "TOPRIGHT")
  mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
  bar.back, bar.left, bar.mid, bar.right = back, left, mid, right
  -- (under the game's text and its expansion button)
  local level = rankBar:GetFrameLevel()
  bar:SetFrameLevel(level + 1)
  for _, child in ipairs({ rankBar.Rank, rankBar.ExpansionDropdownButton }) do
    if child and child.GetFrameLevel and child:GetFrameLevel() <= level + 1 then child:SetFrameLevel(level + 2) end
  end
  rankBar.claraClassicBar = bar
  return bar
end

-- The game's own art of the bar hidden (again after each of its updates: it shows its flare again)
local function HideArt(rankBar)
  for _, key in ipairs({ "Background", "Fill", "Flare", "Border" }) do
    local t = rankBar[key]
    if t and t.Hide then t:Hide() end
  end
end

local function Fill(rankBar, info)
  local bar = rankBar.claraClassicBar
  if not bar then return end
  HideArt(rankBar)
  if type(info) ~= "table" then return end
  local level, most = tonumber(info.skillLevel), tonumber(info.maxSkillLevel)
  if issecretvalue and (issecretvalue(level) or issecretvalue(most)) then return end
  bar:SetValue((level and most and most > 0) and math.min(level / most, 1) or 0)
end
ns.ProfessionBarFill = Fill

function ns.DressProfessionBar(rankBar)
  if not (rankBar and rankBar.Update) or rankBar.claraClassicBar then return end
  Dress(rankBar)
  HideArt(rankBar)
  hooksecurefunc(rankBar, "Update", Fill)
end

local function Setup()
  local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
  if page and page.RankBar then ns.DressProfessionBar(page.RankBar) end
end

if EventUtil and EventUtil.ContinueOnAddOnLoaded then
  EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", Setup)
end
