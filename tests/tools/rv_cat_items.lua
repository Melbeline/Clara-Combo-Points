-- rv: consumables in the class spells panel whose data the game loads later
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
S.bags = { [13446] = 3 }
S.uncachedItems = { [13446] = true } -- a fresh client: the potion's name not loaded yet
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.Frame(0.1)
SlashCmdList.CLARACOMBOPOINTS("")
for _, f in ipairs(M.frames) do if f._kind == "Button" and f.page == 3 and f.name and f.desc then f:Click() end end
local function head(text)
  for _, r in ipairs(M.regions) do
    if r._kind == "FontString" and r._text == text and r._parent:IsVisible() then return r._parent end
  end
end
local function shown(text)
  for _, r in ipairs(M.regions) do
    if r._kind == "FontString" and r._text == text and r._parent:IsVisible() then return r end
  end
end
head("Consumables: potions"):Click()
check(shown("item:13446") ~= nil, "not loaded: shown as item:13446")
S.uncachedItems = nil
M.Fire("GET_ITEM_INFO_RECEIVED", 13446, true)
check(shown("Major Healing Potion") ~= nil, "loaded (GET_ITEM_INFO_RECEIVED): its name in the list")
check(shown("item:13446") == nil, "no item:ID left")
-- search by its name
local search = ClaraComboPointsSpells.search
out(fails .. " failure(s)")
