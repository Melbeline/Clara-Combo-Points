-- Add Classic friend (AltFriends.lua): in the game's Add Friend submenu of another player's menu, its whole name
-- (first name and surname) put in Clara's list; greyed when already in it; never for oneself, never without the submenu
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
GetCurrentRegionName = GetCurrentRegionName or function() return "EU" end
-- (every module off: only the core runs)
ClaraComboPointsDB = { qol = setmetatable({}, { __index = function() return false end }) }
local units = { target = { "Charlotte", "Elle" }, party1 = { "Charlotte", "Moon" }, player = { "Lola", "Brume" } }
function UnitNameUnmodified(u) local x = units[u] if x then return x[1], x[2] end end
function UnitName(u) local x = units[u] if x then return x[1] end end

local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints")
ns.sv.altFriends = {}
local A = ns.AltFriends
function ns:FullName(u) return u == "player" and "Lola Brume" or nil end

local tags = {}
for tag in pairs(M.menuModifiers) do tags[tag] = true end
check(tags.MENU_UNIT_TARGET and tags.MENU_UNIT_PARTY and tags.MENU_UNIT_RAID_PLAYER and tags.MENU_UNIT_CHAT_ROSTER,
  "registered for the target's, a party member's, a raid member's and the chat's menus")

-- A menu as the game builds it: the Add Friend submenu with its Battle.net entry
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
local function Open(contextData, nested)
  local root, sub = Menu(nested)
  for _, fn in ipairs(M.menuModifiers.MENU_UNIT_TARGET) do fn(UIParent, root, contextData) end
  return root, sub
end
local function Entry(sub)
  for _, d in sub:EnumerateElementDescriptions() do if d.text == "Add Classic friend" then return d end end
end

local root, sub = Open({ unit = "target", name = "Charlotte", surname = "Elle" })
local entry = Entry(sub)
check(entry ~= nil and sub.elements[#sub.elements] == entry, "Add Classic friend at the end of the Add Friend submenu")
check(#root.elements == 3, "nothing added to the menu itself")
check(entry and entry.enabled ~= false, "enabled: not in the list yet")
local said = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) table.insert(said, t) end }
if entry then entry.callback() end
check(ns.sv.altFriends["charlotte elle"] and ns.sv.altFriends["charlotte elle"].name == "Charlotte Elle",
  "clicked: the whole name added (Charlotte Elle)")
check(said[#said] and said[#said]:find("Charlotte Elle", 1, true), "said in the chat: " .. tostring(said[#said]))

root, sub = Open({ unit = "target", name = "Charlotte", surname = "Elle" })
entry = Entry(sub)
check(entry and entry.enabled == false, "greyed once in the list")

root, sub = Open({ unit = "party1" })
entry = Entry(sub)
check(entry and entry.enabled ~= false, "Charlotte Moon, same first name: her own entry, enabled")
if entry then entry.callback() end
check(ns.sv.altFriends["charlotte moon"] ~= nil, "Charlotte Moon added by her whole name")

root, sub = Open({ name = "elle-Realm", surname = "woods" })
entry = Entry(sub)
if entry then entry.callback() end
check(ns.sv.altFriends["elle woods"] and ns.sv.altFriends["elle woods"].name == "Elle Woods",
  "no unit (a name in the chat): its name and surname, written as the game writes it")

root, sub = Open({ unit = "target" }, true)
check(Entry(sub) ~= nil, "found in a submenu of the menu too")

root, sub = Open({ unit = "player" })
check(Entry(sub) == nil, "never for oneself")

local plain = MenuUtil.CreateFrame()
plain:CreateButton("Whisper")
for _, fn in ipairs(M.menuModifiers.MENU_UNIT_TARGET) do fn(UIParent, plain, { unit = "target" }) end
check(#plain.elements == 1, "no Add Friend submenu: nothing added")

local secret = MenuUtil.CreateFrame()
local s2 = secret:CreateButton("Add Friend")
local was = issecretvalue
issecretvalue = function(v) return type(v) == "string" and v:find("Charlotte", 1, true) ~= nil end -- (and what is made of it)
for _, fn in ipairs(M.menuModifiers.MENU_UNIT_TARGET) do fn(UIParent, secret, { unit = "target", name = "Charlotte" }) end
issecretvalue = was
check(#s2.elements == 0, "a secret name: no entry, no error")

out(fails == 0 and "ALL PASS" or (fails .. " FAILED"))
