-- XP bar text (Modules/XPText): the game's experience bar's own text always shown (the game's xpBarText setting, put on
-- once), the level's percent after it, the hunter's pet's experience to its right (text only), each in a color of its
-- own; written again after each of the game's updates and as the pet's experience changes; the pet's off by its box;
-- the colors picked with the game's color picker (Cancel puts them back); a trial account's banked text left alone
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
-- (every other module off: only this one runs)
ClaraComboPointsDB = { qol = { lfgforever = false, buyemall = false, leatrix = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, mail = false, tullarange = false, tooltipanchor = false,
  money = false, prices = false, sniper = false, whocooldown = false, idtip = false, soloraidframe = false,
  enemycasts = false, fishing = false, unitscan = false, reverseengineering = false } }

-- The game: its CVar, the player's and the pet's experience, its two bar places with an experience bar each
local cvars = { xpBarText = "0" }
local cvarSets = 0
function GetCVarBool(name) return cvars[name] == "1" end
function SetCVar(name, value) cvarSets = cvarSets + 1 cvars[name] = tostring(value) end
local xp, xpMax = 18970, 19400
local petXP, petMax = 1897, 1940
function UnitXP() return xp end
function UnitXPMax() return xpMax end
function GetPetExperience() return petXP, petMax end
XP_STATUS_BAR_TEXT = "XP: %s/%s"
StatusTrackingBarInfo = { BarsEnum = { None = -1, Reputation = 1, Experience = 4 } }
local capped = false
local function Bar(container)
  local bar = CreateFrame("Frame", nil, container)
  bar.OverlayFrame = CreateFrame("Frame", nil, bar)
  bar.OverlayFrame.Text = bar.OverlayFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  bar.OverlayFrame.Text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE") -- (the game's own)
  function bar:IsCapped() return capped end
  function bar:UpdateCurrentText() self.OverlayFrame.Text:SetText(XP_STATUS_BAR_TEXT:format(UnitXP("player"), UnitXPMax("player"))) end
  container.bars = { [4] = bar }
  return bar
end
MainStatusTrackingBarContainer = CreateFrame("Frame", "MainStatusTrackingBarContainer", UIParent)
SecondaryStatusTrackingBarContainer = CreateFrame("Frame", "SecondaryStatusTrackingBarContainer", UIParent)
local main, second = Bar(MainStatusTrackingBarContainer), Bar(SecondaryStatusTrackingBarContainer)

S.class = "HUNTER"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local function Text(bar) return bar.OverlayFrame.Text._text or "" end
local function Plain(t) return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

out("== shown always, by default")
check(ns:QolRuns("xptext"), "on by default")
check(cvars.xpBarText == "1" and ns.sv.xpText.alwaysSet == true, "the game's own setting put on (shown always)")
check(Plain(Text(main)) == "XP: 18970/19400 (98%)   Pet XP: 1897/1940 (98%)", "the player's text, its percent, the pet's to its right (" .. Plain(Text(main)) .. ")")
check(Text(main):find("^|cffffffffXP:") ~= nil and Text(main):find("|cff8cff8cPet XP:", 1, true) ~= nil, "white, the pet's a light green (" .. Text(main) .. ")")
check(Plain(Text(second)) == Plain(Text(main)), "the second bar place's experience bar too")

out("== the player's choice kept: the setting put on once only")
cvars.xpBarText = "0"
local sets = cvarSets
M.Fire("PLAYER_LOGIN")
check(cvarSets == sets and cvars.xpBarText == "0", "turned off by the player: left off")
cvars.xpBarText = "1"

out("== written again after the game's own update, and as the pet's experience changes")
xp = 19100
main:UpdateCurrentText()
check(Plain(Text(main)):find("^XP: 19100/19400 %(98%%%)") ~= nil, "after the game's update: ours again (" .. Plain(Text(main)) .. ")")
petXP = 1930
M.Fire("UNIT_PET_EXPERIENCE", "pet")
check(Plain(Text(main)):find("Pet XP: 1930/1940 (99%)", 1, true) ~= nil, "the pet's experience changed: drawn again")
petXP, petMax = 0, 0
M.Fire("UNIT_PET", "player")
check(Plain(Text(main)) == "XP: 19100/19400 (98%)", "no pet (or one without experience): the player's text alone")
petXP, petMax = 1930, 1940

out("== its card's boxes")
local sw = ns.qolSwitches.xptext
check(sw and #sw == 2 and sw[1].label == "XPT_SW_ALWAYS" and sw[2].label == "XPT_SW_PET", "two boxes: always shown, the pet's")
sw[2].set(false)
check(Plain(Text(main)) == "XP: 19100/19400 (98%)", "the pet's off")
sw[2].set(true)
sw[1].set(false)
check(cvars.xpBarText == "0", "always shown off: the game's own setting")
sw[1].set(true)

out("== the colors, with the game's color picker; Cancel puts them back; the default colors")
ns.XPTextPage:Show()
local sws = ns.XPTextSwatches
check(sws.player and sws.pet and sws.reset and sws.size, "its page: a size slider, two color swatches and a default button")
check(ns.sv.xpText.size == nil and select(2, main.OverlayFrame.Text:GetFont()) == 12, "its slider set up at the game's size, nothing saved")
sws.size.Slider:SetValue(18)
local path, size, flags = main.OverlayFrame.Text:GetFont()
check(ns.sv.xpText.size == 18 and size == 18 and path == "Fonts\\FRIZQT__.TTF" and flags == "OUTLINE", "bigger: 18, the game's font and outline kept (" .. tostring(size) .. ")")
check(select(2, second.OverlayFrame.Text:GetFont()) == 18, "on both bar places")
main:UpdateCurrentText()
check(select(2, main.OverlayFrame.Text:GetFont()) == 18, "kept after the game's own update")
sws.player:Click()
check(ColorPickerFrame:IsShown(), "the game's color picker opened")
M.PickColor(1, 0.5, 0, 1)
check(Text(main):find("^|cffff8000XP:") ~= nil, "the character's color changed at once (" .. Text(main):sub(1, 12) .. ")")
M.PickerCancel()
check(Text(main):find("^|cffffffffXP:") ~= nil, "Cancel: white again")
sws.pet:Click()
M.PickColor(1, 1, 0, 1)
M.PickerOkay()
check(Text(main):find("|cffffff00Pet XP:", 1, true) ~= nil and ns.sv.xpText.pet[1] == 1, "the pet's yellow, kept")
sws.reset:Click()
check(Text(main):find("|cff8cff8cPet XP:", 1, true) ~= nil and ns.sv.xpText.pet == nil, "the default colors back")
check(ns.sv.xpText.size == nil and select(2, main.OverlayFrame.Text:GetFont()) == 12, "and the game's size")

out("== a trial account's banked experience: the game's text left as it is")
capped = true
main:UpdateCurrentText()
check(Text(main) == "XP: 19100/19400", "the game's own text")
capped = false

out(string.format("\n%d failure(s)", fails))
return fails
