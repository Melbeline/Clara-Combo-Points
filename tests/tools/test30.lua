-- 1.60: spells taken from the spellbook open the rows (locked) with a grace; icon size per class
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

-- the game's spellbook pickup (Blizzard_PlayerSpells calls C_SpellBook.PickupSpellBookItem)
S.book = { 6774, 1943 }
C_SpellBook = C_SpellBook or {}
C_SpellBook.PickupSpellBookItem = function(slot) C_Spell.PickupSpell(S.book[slot]) end
S.knownSpells = { [6774] = true, [1943] = true }
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.Frame(0.1)
local db = ns.db
ns:SetIconsLocked(true)
check(db.iconsLocked and not ns:EditingIcons(), "icons locked: the rows closed")

out("== a spell picked up in the spellbook")
C_SpellBook.PickupSpellBookItem(1)
check(ns.chatDrop ~= nil and ns:EditingIcons(), "Slice and Dice held: the rows open, though locked")
local row
for _, f in ipairs(M.frames) do if f._parent == ns.iconLayer and f.side == "below" and f.k == 1 then row = f end end
check(row and row:IsShown() and row.hit:IsShown(), "the first row below shows, to drop it on")
row.hit._scripts.OnReceiveDrag(row.hit)
check(#db.rows.below[1] == 1 and db.rows.below[1][1] == 6774, "dropped there: on the row")
check(ns:EditingIcons(), "still open a moment, to move it")
while M.timers and #M.timers > 0 do M.RunTimer() end
check(not ns:EditingIcons() and ns.chatDrop == nil, "the grace over: closed again")

out("== let go elsewhere")
C_SpellBook.PickupSpellBookItem(2)
check(ns:EditingIcons(), "Rupture held: open")
ClearCursor()
check(not ns:EditingIcons(), "let go on an action bar (cursor empty): closed at once")
check(#db.rows.below[1] == 1, "nothing added")

out("== any spell taken on the cursor, the options closed")
check(ClaraComboPointsOptions == nil or not ClaraComboPointsOptions:IsShown(), "the options closed, the bar locked")
C_Spell.PickupSpell(1943) -- (an action bar, or a spellbook the addon does not know)
check(ns.chatDrop ~= nil and ns:EditingIcons() and row:IsShown(), "Rupture on the cursor: the rows open")
row.hit._scripts.OnReceiveDrag(row.hit)
local has = false
for _, e in ipairs(db.rows.below[1]) do if e == 1943 then has = true end end
check(has and ns:EditingIcons(), "dropped: added, the rows open 5 s more")
while M.timers and #M.timers > 0 do M.RunTimer() end
check(not ns:EditingIcons(), "then closed")

out("== one lock for the bar and the icons")
SlashCmdList.CLARACOMBOPOINTS("")
local opts = ClaraComboPointsOptions
opts.lockButton:Click()
check(db.locked == false and db.iconsLocked == false and ns:EditingIcons() and ns.hud._mouse,
  "Position > Unlock: the bar moves and its icon rows open")
local tabs0 = {}
for _, f in ipairs(M.frames) do if f.class and f.isTopTab then tabs0[f.class] = f end end
tabs0.PRIEST:Click()
check(ns.db == ns.sv.profiles.PRIEST and ns.db.locked == false and ns.db.iconsLocked == false, "another tab: still unlocked")
opts.lockButton:Click()
check(ns.sv.profiles.PRIEST.locked and ns.sv.profiles.ROGUE.locked and ns.sv.profiles.ROGUE.iconsLocked, "Lock: every bar and icons locked")
opts.lockButton:Click()
SlashCmdList.CLARACOMBOPOINTS("")
check(ns.db == ns.sv.profiles.ROGUE and ns.db.locked == false and ns.db.iconsLocked == false and ns.sv.profiles.PRIEST.locked,
  "closed while unlocked: the rogue's bar stays unlocked, the priest's locked")
ns:SetIconsLocked(true) -- the portrait menu's box, ticked
check(db.locked and db.iconsLocked and not ns:EditingIcons(), "the portrait menu's box: locks the bar too")
ns:SetIconsLocked(false)
check(db.locked == false and ns.hud._mouse, "unticked: the bar moves too")
ns:SetLocked(true)

out("== icon size per class")
local sv = ns.sv
SlashCmdList.CLARACOMBOPOINTS("")
local tabs, navs = {}, {}
for _, f in ipairs(M.frames) do if f.class and f.isTopTab then tabs[f.class] = f end end
for _, f in ipairs(M.frames) do if f._kind == "Button" and f.page and f.name and f.desc then navs[f.page] = f end end
navs[3]:Click()
local function sizeSlider()
  for _, f in ipairs(M.frames) do
    if f._kind == "Slider" and f:IsVisible() and f._min == 12 and f._max == 64 then return f end
  end
end
tabs.PRIEST:Click()
check(sv.profiles.PRIEST.icons.size == 55 and sizeSlider():GetValue() == 55, "Priest tab: 55 by default")
sizeSlider():SetValue(40)
local s = sizeSlider()
s.box:SetText("36"); s.box._scripts.OnEnterPressed(s.box)
tabs.HUNTER:Click()
check(sv.profiles.PRIEST.icons.size == 36 and sv.profiles.HUNTER.icons.size == 55 and sizeSlider():GetValue() == 55,
  "36 on the Priest tab, the Hunter tab still 55")
sizeSlider():SetValue(48)
tabs.PRIEST:Click()
check(sv.profiles.PRIEST.icons.size == 36 and sv.profiles.HUNTER.icons.size == 48 and sizeSlider():GetValue() == 36, "and the other way")
-- a number being typed, then another tab (with a modifier key the game keeps the focus)
local box = sizeSlider().box
box:SetFocus(); box:SetText("20")
tabs.HUNTER:Click()
check(not box:HasFocus() and box:GetText() == "48" and sv.profiles.PRIEST.icons.size == 36 and sv.profiles.HUNTER.icons.size == 48,
  "a number being typed on the Priest tab is dropped when the Hunter tab shows")
-- the wheel over a slider scrolls the page; with Shift, it changes the slider
local sl = sizeSlider()
local page = sl:GetParent()
while page and not page.GetVerticalScroll do page = page:GetParent() end
local scrolled = 0
page:SetScript("OnMouseWheel", function(_, d) scrolled = scrolled + d end)
sl._scripts.OnMouseWheel(sl, -1)
check(scrolled == -1 and sv.profiles.HUNTER.icons.size == 48, "the wheel over the size slider scrolls the page, the size stays")
M.shift = true
sl._scripts.OnMouseWheel(sl, -1)
M.shift = nil
check(scrolled == -1 and sv.profiles.HUNTER.icons.size == 47, "with Shift: the size one less")
SlashCmdList.CLARACOMBOPOINTS("")
check(ns.db == sv.profiles.ROGUE and ns.db.icons.size == 55, "closed: the rogue's own size on the bar")

out(fails .. " failure(s)")
