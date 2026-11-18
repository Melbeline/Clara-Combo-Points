-- A spell just learned, taken from its chat line (LearnedSpells.lua): a click on its name puts it on the cursor, out
-- of a fight only (the game forbids taking a spell in one: the pickup itself is reported blocked); a secret system
-- line passed over
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
function UnitNameUnmodified(u) if u == "player" then return "Lola", "Moon" end end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false,
  leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false,
  mail = false, classicui = false, tullarange = false, names = false, tooltipanchor = false, idtip = false, soloraidframe = false,
  enemycasts = false, reverseengineering = false } }
ERR_LEARN_ABILITY_S = "You have learned a new ability: %s."
ERR_LEARN_SPELL_S = "You have learned a new spell: %s."
local held, pickups = nil, 0
C_Spell = C_Spell or {}
C_Spell.PickupSpell = function(id)
  pickups = pickups + 1
  if InCombatLockdown() then M.Fire("ADDON_ACTION_BLOCKED", "ClaraComboPoints", "UNKNOWN()") return end
  held = id
end
function GetCursorInfo() if held then return "spell", 1, nil, held end end
function ClearCursor() held = nil end
function SetItemRef() end
S.class = "ROGUE"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false)
local blocked = 0
local watch = CreateFrame("Frame")
watch:RegisterEvent("ADDON_ACTION_BLOCKED")
watch:SetScript("OnEvent", function() blocked = blocked + 1 end)

M.Fire("CHAT_MSG_SYSTEM", "You have learned a new ability: |cff71d5ff|Hspell:1784:0|h[Stealth]|h|r.")
out("== in a fight: not taken")
S.inCombat = true
SetItemRef("spell:1784:0", "[Stealth]", "LeftButton")
check(pickups == 0 and held == nil and blocked == 0, "nothing taken, nothing blocked (" .. pickups .. " pickups, " .. blocked .. " blocked)")
out("== out of it: taken")
S.inCombat = false
SetItemRef("spell:1784:0", "[Stealth]", "LeftButton")
check(held == 1784, "on the cursor")
ClearCursor()
out("== a secret system line: passed over")
local ok = pcall(M.Fire, "CHAT_MSG_SYSTEM", MOCK.Secret("You have learned a new ability: |Hspell:2098:0|h[Eviscerate]|h."))
check(ok, "no error")
out(string.format("\n%d failure(s)", fails))
return fails
