-- The professions rank bars in 1.15.9's skin (ProfessionBar.lua) on the game's own rank bar template, the recipes' page's and the Professions tab's
-- (ProfessionsRankBarTemplate): Era's bar on it, the game's art hidden, filled; no error
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
local frame = rawget(env, "ProfessionsFrame")
local rankBar = frame and frame.CraftingPage and frame.CraftingPage.RankBar
if not rankBar then
  local ok, made = pcall(env.CreateFrame, "Frame", nil, env.UIParent, "ProfessionsRankBarTemplate")
  rankBar = ok and made or nil
  print("scenario: the game's window not made here: a rank bar from its template " .. tostring(rankBar ~= nil))
end
check(rankBar ~= nil and rankBar.Update ~= nil, "a rank bar of the game's, with its Update")
if rankBar and rankBar.Update then
  local ok, e = pcall(ns.DressProfessionBar, rankBar)
  check(ok and rankBar.claraClassicBar ~= nil, "Era's bar on it " .. tostring(e or ""))
  ok, e = pcall(rankBar.Update, rankBar, { professionName = "Tailoring", skillLevel = 230, maxSkillLevel = 300, skillModifier = 0, profession = 1 })
  print("scenario: the game's Update " .. tostring(ok) .. " " .. tostring(e or ""))
  ok, e = pcall(ns.ProfessionBarFill, rankBar, { skillLevel = 230, maxSkillLevel = 300 })
  local bar = rankBar.claraClassicBar
  check(ok and bar ~= nil, "filled: no error (the harness's bars keep no value: test141 checks it) " .. tostring(e or ""))
  check(rankBar.Fill and not rankBar.Fill:IsShown() and rankBar.Border and not rankBar.Border:IsShown(), "the game's fill and frame hidden")
end
-- a Professions tab's bar: the template with the tab's own settings (fill from 2, 190 wide, cut 5 short)
local okBook, book = pcall(env.CreateFrame, "Frame", nil, env.UIParent, "ProfessionsRankBarTemplate")
if okBook and book then
  book.overrideFillAnchorLeft, book.overrideMaskRightOffset = 2, -5
  book:SetWidth(190)
  local ok, e = pcall(ns.DressProfessionBar, book)
  check(ok and book.claraClassicBar ~= nil, "a Professions tab's bar (its own start and width) dressed " .. tostring(e or ""))
end
print("scenario: profbar failures " .. fails)
