local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

-- Blizzard menu API, as in Blizzard_Menu (proxies carry .text, Insert(desc, index))
HUD_EDIT_MODE_MENU = "Edit Mode"
local callbacks = {}
Menu = { ModifyMenu = function(tag, fn) callbacks[tag] = fn end }
MenuUtil = {
  GetElementText = function(d) return d.text end,
  CreateButton = function(text, fn) return { text = text, fn = fn } end,
}
local reloads = 0
C_UI = { Reload = function() reloads = reloads + 1 end }
local function Root(texts)
  local items = {}
  for i, t in ipairs(texts) do items[i] = { text = t } end
  local root = { items = items }
  function root:EnumerateElementDescriptions()
    local i = 0
    return function() i = i + 1; if items[i] then return i, items[i] end end
  end
  function root:Insert(d, index) table.insert(items, index or #items + 1, d); return d end
  function root:CreateButton(text, fn) return self:Insert(MenuUtil.CreateButton(text, fn)) end
  return root
end
local function texts(root) local t = {} for i, d in ipairs(root.items) do t[i] = d.text end return table.concat(t, " | ") end

S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
check(callbacks.MENU_UNIT_SELF ~= nil, "hooked the player's own portrait menu (MENU_UNIT_SELF) only")
-- (and the menu of a name in the chat: Copy Chat Message, ChatCopy.lua)
local n = 0 for tag in pairs(callbacks) do if tag ~= "MENU_UNIT_FRIEND" and tag ~= "MENU_UNIT_BN_FRIEND" then n = n + 1 end end
check(n == 1 and callbacks.MENU_UNIT_FRIEND ~= nil, "no other menu touched (but the chat name's, for Copy Chat Message)")

local root = Root({ "Lola", "Target Marker Icon", "Set Focus", "Self Highlight", "Player vs. Player", "Loot Options",
  "Pass on Loot: No", "Instance Options", "Reset all instances", "Other Options", "Edit Mode", "Voice Chat" })
callbacks.MENU_UNIT_SELF(nil, root, {})
out("  " .. texts(root))
check(root.items[11].text == "Reload UI" and root.items[10].text == "Other Options" and root.items[12].text == "Edit Mode",
  "Reload UI between the Other Options title and Edit Mode")
root.items[11].fn()
check(reloads == 1, "clicking it reloads the interface")

local root2 = Root({ "Lola", "Set Focus" })
callbacks.MENU_UNIT_SELF(nil, root2, {})
check(root2.items[3] and root2.items[3].text == "Reload UI", "no Edit Mode entry: added at the end")

ns:SetLanguage("frFR")
local root3 = Root({ "Lola", "Other Options", "Edit Mode" })
callbacks.MENU_UNIT_SELF(nil, root3, {})
check(root3.items[3].text == "Recharger l'interface", "label follows the addon language")
HUD_EDIT_MODE_MENU = "Mode Édition"
local root4 = Root({ "Lola", "Autres options", "Mode Édition", "Discussion vocale" })
callbacks.MENU_UNIT_SELF(nil, root4, {})
check(root4.items[3].text == "Recharger l'interface" and root4.items[4].text == "Mode Édition", "found Edit Mode on a French client by Blizzard's own string")

S.class = "WARRIOR"
out(string.format("\n%d failure(s)", fails))
return fails
