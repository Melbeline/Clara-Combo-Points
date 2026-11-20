-- The professions rank bar in 1.15.9's skin (ProfessionBar.lua): the game's own art hidden (again after its updates),
-- Era's bar in its place (the skill bar texture, its blue, its backing, its three-piece rounded border), filled from
-- the game's own updates at once; the game's centered text and its expansion button above it, untouched
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
out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
