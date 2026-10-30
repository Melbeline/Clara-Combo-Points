-- 1.5: spell cooldowns and charges on the icons, button frame, spellbook drops, /ccp /cp
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function near(a, b) return math.abs(a - b) < 0.01 end
local function rect(r) M.ResetLayout(); return M.Rect(r) end
local function label(f) return (f._textFS and f._textFS._text) or (f.text and f.text._text) end
local function findButton(text)
  for _, f in ipairs(M.frames) do if f._kind == "Button" and f:IsVisible() and label(f) == text then return f end end
end
local function lit(f) return f:IsShown() and not f.icon._desat and f._alpha == 1 end

local ns = {}
S.class = "WARRIOR"; S.locale = "enUS"; S.rage = 50
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.Fire("PLAYER_REGEN_DISABLED"); S.inCombat = true
M.now = 100

out("== commands")
check(SLASH_CLARACOMBOPOINTS1 == "/clara" and SLASH_CLARACOMBOPOINTS2 == "/cl" and SLASH_CLARACOMBOPOINTS3 == "/ccp" and SLASH_CLARACOMBOPOINTS4 == "/cp",
  "/clara, /cl, /ccp and /cp all open the addon")

local slots = {}
for _, f in ipairs(M.frames) do if f.spell and f.cd then slots[f.name] = f end end
local sunder, hamstring, bloodrage = slots["Sunder Armor"], slots["Hamstring"], slots["Bloodrage"]
M.Frame(0.016)

out("== spell cooldowns")
check(not lit(bloodrage) and not lit(hamstring), "nothing up, nothing on cooldown: grayed out")
S.cooldowns = { Hamstring = { 100, 1.5, true } }
M.Fire("SPELL_UPDATE_COOLDOWN"); M.Frame(0.016)
check(not hamstring.cd._cd and not lit(hamstring), "global cooldown only: no swipe, still grayed out")
S.cooldowns = { Bloodrage = { 95, 60 } }
M.Fire("SPELL_UPDATE_COOLDOWN"); M.Frame(0.016)
check(lit(bloodrage) and bloodrage.cd._cd and bloodrage.cd._cd[1] == 95 and bloodrage.cd._cd[2] == 60 and not bloodrage.cd._reverse,
  "Bloodrage on cooldown: lit, cooldown swipe from 60 s, like an action button")
check(ClaraComboPointsDB.cooldownSpells.Bloodrage == true, "spells with a cooldown are remembered")
S.cooldowns = nil
M.Fire("SPELL_UPDATE_COOLDOWN"); M.Frame(0.016)
check(lit(bloodrage) and not bloodrage.cd._cd, "cooldown over: Bloodrage ready, lit, no swipe")
check(not lit(hamstring), "Hamstring (no cooldown of its own) stays grayed out while its debuff is missing")
S.auras = { player = { { name = "Bloodrage", icon = 132277, applications = 0, duration = 10, expirationTime = 108 } } }
S.cooldowns = { Bloodrage = { 98, 60 } }
M.Fire("UNIT_AURA", "player"); M.Frame(0.016)
check(bloodrage.cd._cd[1] == 98 and bloodrage.cd._cd[2] == 10, "buff up: its time left shows first (10 s), then the cooldown")
S.auras = nil
M.Fire("UNIT_AURA", "player"); M.Frame(0.016)
check(bloodrage.cd._cd[1] == 98 and bloodrage.cd._cd[2] == 60, "buff gone: the cooldown shows")
S.secretCooldowns = true
local ok, err = pcall(function() M.Fire("SPELL_UPDATE_COOLDOWN"); M.Frame(0.016) end)
check(ok and lit(bloodrage) and bloodrage.cd._cd and bloodrage.cd._cd[2] == 60, "secret cooldown values: swipe set from the game's duration object, no error " .. tostring(err))
S.secretCooldowns = false; S.cooldowns = nil

out("== stacks and charges")
S.charges = { Hamstring = { 2, 3 } }
M.Fire("SPELL_UPDATE_CHARGES"); M.Frame(0.016)
check(hamstring.count._text == 2, "spell with charges: 2 left shown bottom right")
S.target = { hostile = true }
S.auras = { target = { { name = "Sunder Armor", icon = 132363, applications = 4, duration = 30, expirationTime = 120, harmful = true } } }
S.charges = { ["Sunder Armor"] = { 1, 2 } }
M.Fire("UNIT_AURA", "target"); M.Frame(0.016)
check(sunder.count._text == 4, "aura stacks win over charges (4 Sunder Armor)")
S.charges = nil; S.auras = nil
M.Fire("UNIT_AURA", "target"); M.Frame(0.016)

out("== the button frame")
local frames = 0
for _, t in ipairs(sunder.frame) do if t._file == "ATLAS:UI-HUD-ActionBar-IconFrame" and t._layer == "OVERLAY" then frames = frames + 1 end end
check(frames == 8, "action button frame around the icon")
check(sunder.over._level > sunder.cd._level, "frame and count drawn above the swipe")
local colored = false
for _, r in ipairs(M.regions) do if r._parent == sunder and r._color then colored = true end end
check(not colored, "no combo point colors around the icons any more")
ns.db.icons.shape = "SQUARE"; ns.db.icons.size = 40; ns:LayoutIcons()
local _, _, w, h = rect(sunder)
local _, _, cw, ch = rect(sunder.frame[1])
local _, _, mw = rect(sunder.frame[2])
check(near(w, 40) and near(h, 40) and near(cw, 40 * .22) and near(mw, 40 - 2 * 40 * .22), "square 40 px: corners and edges of the frame in place")
local fs = sunder.cd:GetCountdownFontString()
check(select(2, fs:GetFont()) == 19 and select(3, fs:GetFont()) == "OUTLINE", "countdown numbers sized for the icon, outlined")
ns.db.icons.shape = "FILL"; ns.db.icons.size = 25; ns:LayoutIcons()

out("== preview")
M.Fire("PLAYER_REGEN_ENABLED"); S.inCombat = false
SlashCmdList.CLARACOMBOPOINTS("")
M.Frame(0.016)
check(lit(hamstring) and hamstring.cd._cd ~= nil, "options open: icons lit with a sample cooldown")
ClaraComboPointsOptions:Hide(); M.Frame(0.016)

out("== spellbook drag and drop")
SlashCmdList.CLARACOMBOPOINTS("")
for _, f in ipairs(M.frames) do if f.page == 3 then f:Click() end end
local hint
for _, r in ipairs(M.regions) do if r._kind == "FontString" and type(r._text) == "string" and r._text:find("^drag a spell from the spellbook") then hint = r end end
check(hint ~= nil and hint:IsVisible(), "hint starts with: drag a spell from the spellbook onto a row")
local lines = {}
for _, f in ipairs(M.frames) do if f._kind == "Button" and f._w == 680 and f:IsVisible() then lines[#lines + 1] = f end end
local top1 = lines[3]
local icons = {}
for _, f in ipairs(M.frames) do if f._parent == top1 and f._kind == "Button" then icons[#icons + 1] = f end end
M.cursorSpell = 6774 -- Slice and Dice, picked up in the spellbook
M.CursorOn(icons[2])
top1._scripts.OnReceiveDrag(top1)
local row = ns.db.rows.above[1]
check(row[2] == 6774 and #row == 6 and M.cursorSpell == nil, "dropped on the second icon: added there, cursor emptied")
local status
for _, r in ipairs(M.regions) do if r._kind == "FontString" and type(r._text) == "string" and r._text:find("added") then status = r end end
check(status and status._text == "Slice and Dice added (Top 1).", "message: " .. tostring(status and status._text))
M.cursorSpell = 1943 -- Rupture
M.CursorOn(lines[4], 300)
lines[4]:Click()
check(ns.db.rows.below[1][1] == 1943 and M.cursorSpell == nil, "click on a row with a spell on the cursor: added (Bottom 1)")
check(findButton("Add > Bottom 1") ~= nil, "that row is selected")
M.cursorSpell = 6774
M.CursorOn(icons[1])
icons[1]._scripts.OnReceiveDrag(icons[1])
check(#ns.db.rows.above[1] == 6 and M.cursorSpell == 6774, "same spell twice refused, spell stays on the cursor")
M.cursorSpell = nil
local before = #ns.db.rows.above[1]
icons[1]:Click("LeftButton")
check(#ns.db.rows.above[1] == before, "plain left-click on an icon does nothing")
icons[1]:Click("RightButton")
check(#ns.db.rows.above[1] == before - 1, "right-click still removes")

out("== labels fit the icons page")
-- the page sits right of the list of pages (168 wide); in it, two columns: left from 20,
-- right from 380, 320 wide each
local NAV_W, RIGHT_COL, COL_END = 168, 380, 700
local druidTab
for _, f in ipairs(M.frames) do if f.class == "DRUID" then druidTab = f end end
if druidTab then druidTab:Click() end -- the druid tab: its bear option has the longest label
local bearShown = false
for _, f in ipairs(M.frames) do
  if f._kind == "CheckButton" and f:IsVisible() and f.Text and f.Text._text == "Bear Form: icons stay above the combo points" then bearShown = true end
end
check(druidTab and bearShown, "druid tab: its bear option shown on the icons page")
for _, lang in ipairs({ "enUS", "frFR", "deDE" }) do
  ns:SetLanguage(lang)
  ClaraComboPointsOptions:Refresh()
  local pageLeft = rect(ClaraComboPointsOptions) + NAV_W
  local worst, what, n = -1e9, "", 0
  for _, f in ipairs(M.frames) do
    if f._kind == "CheckButton" and f:IsVisible() and f.Text and f.Text._text then
      local l, _, w = rect(f)
      if l < pageLeft + COL_END then -- (not the class spells panel beside the window)
        n = n + 1
        local right = l + w + 1 + f.Text:GetStringWidth()
        -- left column: clear of the right one; right column: within the page's margin
        local limit = l < pageLeft + RIGHT_COL - 10 and pageLeft + RIGHT_COL - 6 or pageLeft + COL_END
        local over = right - limit
        if over > worst then worst, what = over, f.Text._text end
      end
    end
  end
  check(n == 5 and worst <= 0, lang .. ": checkbox labels stay in their column (" .. n .. " checks, worst: " .. what .. ")")
  local h = 0
  for _, r in ipairs(M.regions) do
    if r._kind == "FontString" and r:IsVisible() and type(r._text) == "string" and r._text:find("·") and r._parent:IsVisible() then
      local w = r:GetStringWidth(); if w > h then h = w end
    end
  end
  check(h <= 680, lang .. ": hints fit the window width (" .. math.floor(h) .. ")")
  -- the footer: the commands at left, the window's opacity now at the bottom right
  local cmds, opLabel
  for _, r in ipairs(M.regions) do
    if r._kind == "FontString" and r:IsVisible() and type(r._text) == "string" then
      if r._text:find("^/cl lock") then cmds = r elseif r._text == ns.L.WINDOW_OPACITY then opLabel = r end
    end
  end
  local cl = cmds and rect(cmds)
  local ol = opLabel and rect(opLabel)
  check(cl and ol and cl + cmds:GetStringWidth() + 8 <= ol, lang .. ": footer commands end before the window opacity label")
end
ClaraComboPointsOptions:Hide()

out(string.format("\n%d failure(s)", fails))
return fails
