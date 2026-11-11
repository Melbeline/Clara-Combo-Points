-- The target's level beside the skull (WoW Forever build 70840 on): the game's battle pet check shows the level text
-- again after its level check hid it; Clara hides it again for a skull or a corpse, leaves it for a real level.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local unitState = { level = 12, corpse = false, pet = false }
function UnitEffectiveLevel() return unitState.level end
function UnitIsCorpse() return unitState.corpse end
function UnitIsWildBattlePet() return unitState.pet end
function UnitIsBattlePetCompanion() return false end
local function MakeTarget(name)
  local frame = CreateFrame("Button", name, UIParent)
  frame.unit, frame.showLevel = name == "TargetFrame" and "target" or "focus", true
  frame.TargetFrameContent = { TargetFrameContentMain = {} }
  local text = frame:CreateFontString(nil, "ARTWORK")
  frame.TargetFrameContent.TargetFrameContentMain.LevelText = text
  -- the game's order (TargetFrame.lua Update): its level check, then the battle pet check of the Camelot build
  function frame:CheckLevel()
    if UnitIsCorpse(self.unit) or UnitEffectiveLevel(self.unit) <= 0 then text:Hide() else text:Show() end
  end
  function frame:CheckBattlePet() text:SetShown(not UnitIsWildBattlePet(self.unit)) end
  function frame:Update() self:CheckLevel(); self:CheckBattlePet() end
  return frame, text
end
local target, targetText = MakeTarget("TargetFrame")
local focus, focusText = MakeTarget("FocusFrame")
S.class = "ROGUE"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
target:Update()
check(targetText:IsShown(), "a level 12 target: its level shown")
unitState.level = -1; target:Update()
check(not targetText:IsShown(), "a skull target: no level beside the skull")
unitState.level = 30; unitState.corpse = true; target:Update()
check(not targetText:IsShown(), "a corpse: no level")
unitState.corpse = false; target:Update()
check(targetText:IsShown(), "a level again: shown")
unitState.level = -1; focus:Update()
check(not focusText:IsShown(), "the focus frame too")
unitState.level = -1; unitState.pet = true; target:Update()
check(not targetText:IsShown(), "a wild battle pet: the game's own choice left")
target.showLevel = false; unitState.pet = false; target:CheckBattlePet()
check(targetText:IsShown(), "a frame that shows no level check: left to the game")
out(string.format("\n%d failure(s)", fails))
return fails
