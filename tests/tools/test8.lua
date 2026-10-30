-- 1.4 review fixes
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function near(a, b) return math.abs(a - b) < 0.01 end
local function rect(r) M.ResetLayout(); return M.Rect(r) end

local ns = {}
S.class = "WARRIOR"; S.locale = "enUS"; S.rage = 0
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local power = ns.powerBar
local clip
for _, f in ipairs(M.frames) do if f._parent == power and f._clips then clip = f end end
local tex
for _, r in ipairs(M.regions) do if r._parent and r._parent._parent == clip then tex = r end end

out("== preview fills the rage bar so its colours show")
SlashCmdList.CLARACOMBOPOINTS("")
check(ns.preview and M.reveal(power._value) == 100, "preview: rage bar full (real rage 0)")
local pl, _, pw = rect(power)
local cl, _, cw = rect(tex)
check(clip:IsShown() and near(cl + cw, pl + pw) and cw > 40, "preview: rage-cost sample visible at the end of the bar")
ClaraComboPointsOptions:Hide()
check(not ns.preview and M.reveal(power._value) == 0, "preview over: real rage again")

out("== mover label above the icons")
ns:SetLocked(false)
local label
for _, r in ipairs(M.regions) do if r._kind == "FontString" and type(r._text) == "string" and r._text:find("^Clara Combo Points %- drag to move") then label = r end end
local row1
for _, f in ipairs(M.frames) do if f._parent == ns.iconLayer and f._kind ~= "AuraContainer" and f:IsShown() then row1 = f end end
local _, lb = rect(label)
local _, rb, _, rh = rect(row1)
check(lb >= rb + rh, "unlocked: label above the warrior's icon row, not over it")
ns.db.rows.above[1] = {}
ns:LayoutIcons()
local _, lb2 = rect(label)
local top
for _, f in ipairs(M.frames) do
  if f._parent == ns.iconLayer and f._kind ~= "AuraContainer" and f:IsShown() and f.side == "above" then
    local _, b, _, h = rect(f)
    if not top or b + h > top then top = b + h end
  end
end
check(top and near(lb2, top + 4), "no icons: the empty rows open (one lock), the label just above them")
ns:SetLocked(true)
ns:ResetIcons()

out("== a spell tracked by name learns its icon")
ns.db.rows.below[2] = { "Enrage" }
ns:LayoutIcons()
local slot
for _, f in ipairs(M.frames) do if f.name == "Enrage" then slot = f end end
check(slot.spellIcon == "Interface\\Icons\\INV_Misc_QuestionMark", "unknown at first: question mark")
S.target = { hostile = true }
S.auras = { player = { { name = "Enrage", icon = 136224, applications = 0, duration = 12, expirationTime = 12 } } }
M.Fire("UNIT_AURA", "player"); M.Frame(0.016)
check(slot.icon._file == 136224, "aura up: its icon")
S.auras = nil
M.Fire("UNIT_AURA", "player"); M.Frame(0.016)
check(slot.icon._file == 136224 and slot.icon._desat, "aura gone: grayed, with the learned icon")
check(ClaraComboPointsDB.seenIcons.Enrage == 136224, "learned icon saved for the next sessions")
ns:LayoutIcons()
check(slot.spellIcon == 136224, "still known after a relayout")

out("== secret stack text only handed to SetText")
S.auras = { target = { { name = "Sunder Armor", icon = 132363, applications = 2, duration = 30, expirationTime = 30, harmful = true } } }
S.secretFields = true
local ok, err = pcall(function() M.Fire("UNIT_AURA", "target"); M.Frame(0.016) end)
check(ok, "no error " .. tostring(err))
S.secretFields = false; S.auras = nil

out("== a shift that does not change the bar does not re-read the icons")
local nd = {}
M.eventFrames = {}
S.class = "DRUID"; S.powerType = 3; S.energy = 80
ClaraComboPointsDB = nil
M.LoadAddon(ADDON_DIR, nd)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local row = {}
for i = 1, 20 do row[i] = 6774 end
nd.db.rows.above[1] = row
nd:LayoutIcons(); M.Frame(0.016)
M.auraLookups = 0
M.Fire("UPDATE_SHAPESHIFT_FORM"); M.Frame(0.016)
check(M.auraLookups == 0, "same form again: no aura lookups (" .. M.auraLookups .. ")")
S.powerType = 1; S.rage = 30
M.auraLookups = 0
M.Fire("UPDATE_SHAPESHIFT_FORM"); M.Fire("UNIT_DISPLAYPOWER", "player")
check(M.auraLookups <= 1, "bear: icons not read in the event itself (only Frenzied Regeneration: " .. M.auraLookups .. ")")
local before = M.auraLookups
M.Frame(0.016)
check(M.auraLookups - before == 3 * 20, "one icon pass on the next frame (" .. (M.auraLookups - before) .. " lookups for 20 missing icons)")
check(M.reveal(nd.powerBar._value) == 30, "bear: rage shown")

out("== bear form: icon rows come down onto the rage bar without combo points")
nd.db.rows.above[1] = { 6774 }
nd:LayoutIcons()
local drow
for _, f in ipairs(M.frames) do if f._parent == nd.iconLayer and f._kind ~= "AuraContainer" and f:IsShown() then drow = f end end
local function rowBottom() local _, b = rect(drow); return b end
local _, pb2, _, ph2 = rect(nd.powerBar)
local _, cb2, _, ch2 = rect(nd.comboRow)
S.target = { cp = 0, hostile = true }
M.Fire("PLAYER_TARGET_CHANGED"); M.Frame(0.016)
check(near(rowBottom(), pb2 + ph2 + 4), "bear, no combo points: icons right on the rage bar")
S.target.cp = 2; M.Fire("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
check(near(rowBottom(), cb2 + ch2 + 4), "bear, 2 combo points: icons back above the combo points")
S.target.cp = 0; M.Fire("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
nd:SetBearIconsFixed(true)
check(near(rowBottom(), cb2 + ch2 + 4), "option: icons stay above the combo points")
nd:SetBearIconsFixed(false)
check(near(rowBottom(), pb2 + ph2 + 4), "option off: on the bar again")
S.secret = true; M.Fire("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS"); M.Frame(0.2)
check(near(rowBottom(), cb2 + ch2 + 4), "unreadable (secret) count: icons kept above the combo points")
S.secret = false; M.Fire("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS"); M.Frame(0.2)
S.powerType = 3; M.Fire("UNIT_DISPLAYPOWER", "player")
check(near(rowBottom(), cb2 + ch2 + 4), "cat form: icons above the combo points (empty cells show)")

out(string.format("\n%d failure(s)", fails))
return fails
