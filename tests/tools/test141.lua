-- The professions rank bars in 1.15.9's skin (ProfessionBar.lua): the game's own art hidden (again after its updates),
-- Era's bar in its place (the skill bar texture, its blue, its backing, its three-piece rounded border), filled from
-- the game's own updates at once; the game's centered text and its expansion button above it, untouched; the
-- Professions tab's five bars too, each over the span the game fills there (its own start and width)
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

-- the game's rank bar (ProfessionsRankBarTemplate): its art, its text frame, its button, its Update
ProfessionsFrame = CreateFrame("Frame", "ProfessionsFrame", UIParent)
local page = CreateFrame("Frame", nil, ProfessionsFrame)
ProfessionsFrame.CraftingPage = page
local rankBar = CreateFrame("Frame", nil, page)
rankBar:SetSize(453, 18)
rankBar:SetPoint("TOPLEFT", page, "TOPLEFT", 280, -40)
page.RankBar = rankBar
for _, key in ipairs({ "Background", "Fill", "Flare", "Border" }) do rankBar[key] = rankBar:CreateTexture(nil, "ARTWORK") end
rankBar.Rank = CreateFrame("Frame", nil, rankBar)
rankBar.Rank.Text = rankBar.Rank:CreateFontString(nil, "ARTWORK", "GameFontNormal")
rankBar.ExpansionDropdownButton = CreateFrame("Button", nil, rankBar)
function rankBar:Update(info)
  self.Rank.Text:SetText(("%s %d/%d"):format(info.professionName, info.skillLevel, info.maxSkillLevel))
  self.Flare:Show() -- (the game shows its flare again)
end

-- the Professions tab (ProfessionsFrame.BookPage): its cards' bars, with the tab's own settings
local function BookBar(card, width, maskOffset)
  local b = CreateFrame("Frame", nil, card)
  b.overrideFillAnchorLeft, b.overrideMaskRightOffset = 2, maskOffset
  b:SetSize(width, 18)
  for _, key in ipairs({ "Background", "Fill", "Flare", "Border" }) do b[key] = b:CreateTexture(nil, "ARTWORK") end
  b.Fill:SetSize(441, 18)
  b.Rank = CreateFrame("Frame", nil, b)
  b.Rank.Text = b.Rank:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  b.Update = rankBar.Update
  card.StatusBar = b
  return b
end
local book = CreateFrame("Frame", nil, ProfessionsFrame)
ProfessionsFrame.BookPage = book
book.ProfessionsContentFrame = CreateFrame("Frame", nil, book)
local cards = {}
for _, key in ipairs({ "PrimaryProfession1", "PrimaryProfession2", "SecondaryProfession1", "SecondaryProfession2", "SecondaryProfession3" }) do
  cards[key] = CreateFrame("Frame", nil, book.ProfessionsContentFrame)
  book.ProfessionsContentFrame[key] = cards[key]
end
local primary = BookBar(cards.PrimaryProfession1, 441, -7)
BookBar(cards.PrimaryProfession2, 441, -7)
local cooking = BookBar(cards.SecondaryProfession1, 190, -5)
BookBar(cards.SecondaryProfession2, 190, -5)
BookBar(cards.SecondaryProfession3, 190, -5)
rankBar.Fill:SetSize(441, 18)

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
M.Fire("ADDON_LOADED", "Blizzard_Professions")
ProfessionsFrame:Show(); page:Show(); rankBar:Show()

local bar = rankBar.claraClassicBar
check(bar ~= nil, "Era's bar on the game's rank bar")
if not bar then out(fails .. " FAILED") return end
check(not rankBar.Background:IsShown() and not rankBar.Fill:IsShown() and not rankBar.Flare:IsShown() and not rankBar.Border:IsShown(),
  "the game's background, fill, flare and frame hidden")
rankBar:Update({ professionName = "Tailoring", skillLevel = 230, maxSkillLevel = 300 })
check(math.abs(bar:GetValue() - 230 / 300) < 1e-6, "filled as the game's update says: 230/300 at once")
check(not rankBar.Flare:IsShown(), "the flare the game shows again: hidden again")
check(rankBar.Rank.Text:GetText() == "Tailoring 230/300", "the game's text, as it writes it")
local fill = bar:GetStatusBarTexture()
local file = bar._bartex
check(tostring(file):find("UI%-Character%-Skills%-Bar"), "the skill bar texture (" .. tostring(file) .. ")")
local r, g, b, a = unpack(bar._barcolor or {})
check(r == 0 and g == 0 and b == 1 and math.abs(a - 0.5) < 1e-6, "Era's blue at half")
check(tostring(bar.left:GetTexture()):find("BarBorder") and tostring(bar.mid:GetTexture()):find("BarBorder") and tostring(bar.right:GetTexture()):find("BarBorder"),
  "its rounded border in three pieces")
check(bar:GetFrameLevel() < rankBar.Rank:GetFrameLevel() and bar:GetFrameLevel() < rankBar.ExpansionDropdownButton:GetFrameLevel(),
  "under the game's text and its expansion button")
check(math.abs(bar:GetHeight() - 15) < 0.01, "Era's height (15)")
rankBar:Update({ professionName = "Enchanting", skillLevel = 75, maxSkillLevel = 75 })
check(bar:GetValue() == 1, "full: 75/75")
rankBar:Update({ professionName = "Fishing", skillLevel = 1, maxSkillLevel = 0 })
check(bar:GetValue() == 0, "no cap: empty, no error")
ns.DressProfessionBar(rankBar)
check(rankBar.claraClassicBar == bar, "dressed once")
local x1, x2 = ns.ProfessionBarSpan(rankBar)
local function Near(a, b) return math.abs(a - b) < 0.01 end
check(Near(x1, 6) and Near(x2, 445), "the recipes' page: over the game's fill (5 + 441): " .. x1 .. "-" .. x2)

out("== the Professions tab's bars")
local n = 0
for _, card in pairs(cards) do if card.StatusBar.claraClassicBar then n = n + 1 end end
check(n == 5, "its five bars dressed (two primary, Cooking, Fishing, First Aid)")
x1, x2 = ns.ProfessionBarSpan(primary)
check(Near(x1, 3) and Near(x2, 436), "a primary profession's: from 2, cut 7 short of its 441: " .. x1 .. "-" .. x2)
x1, x2 = ns.ProfessionBarSpan(cooking)
check(Near(x1, 3) and Near(x2, 187), "Cooking's: from 2, cut 5 short of its 190: " .. x1 .. "-" .. x2)
primary:Update({ professionName = "Tailoring", skillLevel = 231, maxSkillLevel = 300 })
cooking:Update({ professionName = "Cooking", skillLevel = 62, maxSkillLevel = 75 })
check(math.abs(primary.claraClassicBar:GetValue() - 231 / 300) < 1e-6 and math.abs(cooking.claraClassicBar:GetValue() - 62 / 75) < 1e-6,
  "filled by the game's updates: Tailoring 231/300, Cooking 62/75")
check(not primary.Fill:IsShown() and not primary.Flare:IsShown() and not cooking.Border:IsShown() and not cooking.Background:IsShown(),
  "the game's art hidden there too")
check(primary.Rank.Text:GetText() == "Tailoring 231/300" and cooking.Rank.Text:GetText() == "Cooking 62/75", "their texts the game's")
out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
