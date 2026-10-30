-- auras in combat through the game's aura containers: secret event arguments, Frenzied
-- Regeneration counted from the cast, aura buttons following the icon look
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function near(a, b) return math.abs(a - b) < 0.01 end
local function auraButtons(slot)
  local t = {}
  for _, f in ipairs(M.frames) do
    if f._auraButton and f._points and f._points[1] and f._points[1][2] == slot then t[#t + 1] = f end
  end
  return t
end
local function auraShown(slot) for _, b in ipairs(auraButtons(slot)) do if b:IsVisible() then return b end end end

local ns = {}
S.class = "DRUID"; S.locale = "enUS"; S.powerType = 1; S.rage = 60
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.now = 100

out("== secret event arguments")
local ok, err = pcall(ns.UNIT_AURA, ns, M.Secret("player"), M.Secret({}))
check(ok, "UNIT_AURA with a secret unit (combat): no error " .. tostring(err))

out("== Frenzied Regeneration in combat")
local power = ns.powerBar
local clip
for _, f in ipairs(M.frames) do if f._parent == power and f._clips then clip = f end end
M.Fire("PLAYER_REGEN_DISABLED"); S.inCombat = true; S.secretAuras = true
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-9", 22842)
M.Frame(0.016)
check(clip:IsShown(), "cast in combat (its aura hidden): the rage it will take is marked")
M.Frame(1); M.Frame(1)
check(clip:IsShown(), "still marked two seconds later")
M.now = M.now + 9
M.Frame(1); M.Frame(1)
check(not clip:IsShown(), "ten seconds later: no more")
S.inCombat = false; S.secretAuras = false; M.Fire("PLAYER_REGEN_ENABLED"); M.Frame(0.016)

out("== the game's aura buttons follow the icon look")
S.powerType = 3; M.Fire("UPDATE_SHAPESHIFT_FORM"); M.Frame(0.016)
ns.db.rows.above[1] = { 774, 8921 }
ns:LayoutIcons(); M.Frame(0.016)
local slots = {}
for _, f in ipairs(M.frames) do if f.cd and f.spell ~= nil and f:GetParent() and f:GetParent().spells == ns.db.rows.above[1] then slots[#slots + 1] = f end end
local b = auraButtons(slots[1])[1]
check(b._icon._tc and near(b._icon._tc[3], slots[1].icon._tc[3]), "art cropped like the icon (" .. tostring(b._icon._tc and b._icon._tc[3]) .. ")")
ns.db.icons.shape = "SQUARE"; ns.db.icons.size = 40; ns.db.icons.reverse = true; ns.db.icons.timers = false
ns:LayoutIcons(); M.Frame(0.016)
local fs = b._cd:GetCountdownFontString()
check(near(b._icon._tc[3], .08) and b._cd._reverse == true and b._cd._hideNumbers == true and select(2, fs:GetFont()) == 19 and select(2, b._count:GetFont()) == 16,
  "square 40, reversed swipe, no numbers: the game's buttons too")
ns.db.icons.shape = "FILL"; ns.db.icons.size = 25; ns.db.icons.reverse = false; ns.db.icons.timers = true
ns:LayoutIcons(); M.Frame(0.016)

out("== missing auras hidden")
ns.db.icons.missing = false
S.inCombat = true; S.secretAuras = true; M.Fire("PLAYER_REGEN_DISABLED")
S.auras = { player = { { name = "Rejuvenation", icon = 136081, duration = 12, expirationTime = M.now + 12, spellId = 774 } } }
M.Fire("UNIT_AURA", "player"); M.Frame(0.016)
check(not slots[1]:IsShown() and auraShown(slots[1]), "the icon (unread) is hidden, the game's button still shows the aura")
check(not auraShown(slots[2]), "no Moonfire: nothing shown")
S.inCombat = false; S.secretAuras = false; M.Fire("PLAYER_REGEN_ENABLED"); M.Frame(0.016)
ns.db.icons.missing = true

out("== a row emptied: its aura buttons stop")
ns.db.rows.above[1] = {}
ns:LayoutIcons(); M.Frame(0.016)
local enabled = 0
for _, c in ipairs(M.containers) do for _, rec in pairs(c._slots) do if rec.enabled then enabled = enabled + 1 end end end
check(enabled == 0 and not auraShown(slots[1]), "no aura button left watching")

out(string.format("\n%d failure(s)", fails))
return fails
