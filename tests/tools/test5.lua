local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

-- Blizzard menu API, as in Blizzard_Menu (proxies carry .text, Insert(desc, index))
HUD_EDIT_MODE_MENU = "Edit Mode"
local callbacks = {}
local lists = {}
Menu = { ModifyMenu = function(tag, fn)
  lists[tag] = lists[tag] or {}
  table.insert(lists[tag], fn)
  callbacks[tag] = function(...) for _, f in ipairs(lists[tag]) do f(...) end end
end }
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
-- (and another player's menus: Add Classic friend in their Add Friend submenu, AltFriends.lua)
local PLAYER = {}
for _, which in ipairs({ "TARGET", "FOCUS", "PARTY", "PLAYER", "RAID_PLAYER", "RAID", "ENEMY_PLAYER", "ARENAENEMY",
  "FRIEND", "FRIEND_OFFLINE", "CHAT_ROSTER", "GUILD", "GUILD_OFFLINE", "COMMUNITIES_MEMBER", "COMMUNITIES_WOW_MEMBER",
  "COMMUNITIES_GUILD_MEMBER", "NEIGHBORHOOD_ROSTER", "RAF_RECRUIT", "RECENT_ALLY", "RECENT_ALLY_OFFLINE",
  "PVP_SCOREBOARD", "WORLD_STATE_SCORE" }) do PLAYER["MENU_UNIT_" .. which] = true end
local others = {}
for tag in pairs(callbacks) do
  if not (PLAYER[tag] or tag == "MENU_UNIT_SELF" or tag == "MENU_UNIT_FRIEND" or tag == "MENU_UNIT_BN_FRIEND" or tag == "MENU_UNIT_PARTY"
    or tag == "MENU_UNIT_RAID_PLAYER" or tag == "MENU_FCF_TAB" or tag == "MENU_PROFESSIONS_FILTER") then others[#others + 1] = tag end
end
check(#others == 0 and callbacks.MENU_UNIT_FRIEND ~= nil, "no other menu touched (the chat name's: Copy Chat Message; the group's: its loot line; another player's: Add Classic friend; the chat tab's; the professions filter) " .. table.concat(others, ","))

local GAME = { "Lola", "Target Marker Icon", "Set Focus", "Self Highlight", "Player vs. Player", "Loot Options",
  "Pass on Loot: No", "Instance Options", "Reset all instances", "Other Options", "Edit Mode", "Voice Chat", "Leave Party" }
local root = Root(GAME)
callbacks.MENU_UNIT_SELF(nil, root, {})
out("  " .. texts(root))
local same = true
for i, t in ipairs(GAME) do if root.items[i].text ~= t then same = false end end
check(same, "the game's own entries left where they are (none moved: Leave Party still the last of them)")
check(root.items[#GAME + 1] and root.items[#GAME + 1].text == "Reload UI", "Reload UI after them, at the menu's end")
root.items[#GAME + 1].fn()
check(reloads == 1, "clicking it reloads the interface")

S.inCombat = true
local fight = Root(GAME)
callbacks.MENU_UNIT_SELF(nil, fight, {})
check(#fight.items == #GAME, "in combat: nothing added to the menu (the game blocked an addon's entries then)")
S.inCombat = false

ns:SetLanguage("frFR")
local root3 = Root({ "Lola", "Other Options", "Edit Mode" })
callbacks.MENU_UNIT_SELF(nil, root3, {})
check(root3.items[4].text == "Recharger l'interface", "label follows the addon language")

S.class = "WARRIOR"
out(string.format("\n%d failure(s)", fails))
return fails
