-- ClassicFriendsList: Add Classic friend in the game's Add Friend submenu of another player's menu (the target's
-- portrait, a group's frame, a name in the chat): its whole name put in the list; greyed when already in it; never
-- for oneself; hooked at login only when Clara is not loaded (Clara has its own: never two)
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
Constants = Constants or {}
Constants.CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " " }
local units = { target = { "Charlotte", "Elle" }, party1 = { "Charlotte", "Moon" }, player = { "Lola", "Brume" } }
function UnitNameUnmodified(u) local x = units[u] if x then return x[1], x[2] end end
function UnitName(u) local x = units[u] if x then return x[1] end end
ChatFrameUtil = ChatFrameUtil or {}
ChatFrameUtil.AddMessageEventFilter = function() end
FriendsFrame = CreateFrame("Frame", "FriendsFrame", UIParent)
FriendsFrame:Hide()

-- (ClassicFriendsList keeps the game's issecretvalue as it loads: one whose answer the test can change)
local secret = function() return false end
issecretvalue = function(v) return secret(v) end

local function Load(claraLoaded)
  M.menuModifiers = {}
  local ns = {}
  S.class = "PRIEST"; S.locale = "enUS"
  C_AddOns = C_AddOns or {}
  C_AddOns.IsAddOnLoaded = function(name) return claraLoaded and name == "ClaraComboPoints" end
  ClassicFriendsListDB = nil
  M.LoadAddonAs(ADDON_DIR, "ClassicFriendsList.toc", "ClassicFriendsList", ns)
  M.Fire("ADDON_LOADED", "ClassicFriendsList")
  M.Fire("PLAYER_LOGIN")
  return ns.CFL
end

local function Menu(nested)
  local root = MenuUtil.CreateFrame()
  root:CreateTitle("Charlotte")
  local holder = root
  if nested then holder = root:CreateButton("Player") end
  local sub = holder:CreateButton("Add Friend")
  sub:CreateButton("Add Battle.net Friend")
  root:CreateButton("Whisper")
  return root, sub
end
local function Open(tag, contextData, nested)
  local root, sub = Menu(nested)
  for _, fn in ipairs(M.menuModifiers[tag] or {}) do fn(UIParent, root, contextData) end
  return root, sub
end
local function Entry(sub)
  for _, d in sub:EnumerateElementDescriptions() do if d.text == "Add Classic friend" then return d end end
end

out("== Clara loaded: ClassicFriendsList off, no entry of its own")
Load(true)
local _, sub = Open("MENU_UNIT_TARGET", { unit = "target" })
check(Entry(sub) == nil and next(M.menuModifiers) == nil, "nothing hooked (Clara adds its own)")

out("== alone")
local A = Load(false)
check(M.menuModifiers.MENU_UNIT_TARGET and M.menuModifiers.MENU_UNIT_PARTY and M.menuModifiers.MENU_UNIT_RAID_PLAYER
  and M.menuModifiers.MENU_UNIT_CHAT_ROSTER, "hooked: the target's, a party member's, a raid member's, the chat's menus")
check(#M.menuModifiers.MENU_UNIT_TARGET == 1, "once")
local root
root, sub = Open("MENU_UNIT_TARGET", { unit = "target" })
local entry = Entry(sub)
check(entry ~= nil and sub.elements[#sub.elements] == entry, "Add Classic friend at the end of the Add Friend submenu")
check(#root.elements == 3, "nothing added to the menu itself")
local said = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) table.insert(said, t) end }
if entry then entry.callback() end
check(ClassicFriendsListDB.friends["charlotte elle"] and ClassicFriendsListDB.friends["charlotte elle"].name == "Charlotte Elle",
  "clicked: the whole name added (Charlotte Elle)")
check(said[#said] and said[#said]:find("Charlotte Elle", 1, true), "said in the chat: " .. tostring(said[#said]))
root, sub = Open("MENU_UNIT_TARGET", { unit = "target" })
entry = Entry(sub)
check(entry and entry.enabled == false, "greyed once in the list")
root, sub = Open("MENU_UNIT_PARTY", { unit = "party1" })
entry = Entry(sub)
check(entry and entry.enabled ~= false, "Charlotte Moon, same first name: her own entry, enabled")
root, sub = Open("MENU_UNIT_CHAT_ROSTER", { name = "elle-Realm", surname = "woods" })
entry = Entry(sub)
if entry then entry.callback() end
check(ClassicFriendsListDB.friends["elle woods"] ~= nil, "no unit: its name and surname (Elle Woods)")
root, sub = Open("MENU_UNIT_RAID_PLAYER", { unit = "target" }, true)
check(Entry(sub) ~= nil, "found in a submenu of the menu too")
root, sub = Open("MENU_UNIT_TARGET", { unit = "player" })
check(Entry(sub) == nil, "never for oneself")
secret = function(v) return type(v) == "string" and v:find("Charlotte", 1, true) ~= nil end -- (and what is made of it)
root, sub = Open("MENU_UNIT_TARGET", { unit = "target", name = "Charlotte" })
secret = function() return false end
check(Entry(sub) == nil, "a secret name: no entry, no error")

out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
