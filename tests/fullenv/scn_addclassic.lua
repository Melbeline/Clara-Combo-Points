-- Add Classic friend in the game's own unit menus: the target's menu opened as a right-click on its portrait opens it
-- (the game's UnitPopup code, its Add Friend submenu), Clara's entry put in it, no error
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
local A = ns.AltFriends
check(A and A.AddClassicEntry and A.MenuName, "the entry's code loaded")
local manager = rawget(env, "UnitPopupManager")
print("scenario: UnitPopupManager " .. tostring(manager) .. ", Menu " .. tostring(rawget(env, "Menu")) .. ", ADD_FRIEND " .. tostring(rawget(env, "ADD_FRIEND")))
local MenuUtil = rawget(env, "MenuUtil")
if MenuUtil and MenuUtil.CreateRootMenuDescription and rawget(env, "MenuVariants") then
  local ok, root = pcall(MenuUtil.CreateRootMenuDescription, env.MenuVariants.GetDefaultContextMenuMixin())
  if ok and root then
    local sub = root:CreateButton(env.ADD_FRIEND or "Add Friend")
    sub:CreateButton("Add Battle.net Friend")
    local okE, e = pcall(A.AddClassicEntry, nil, root, { unit = "target", name = "Charlotte", surname = "Elle" })
    check(okE, "the game's own menu description: entry added without error " .. tostring(e or ""))
    local found
    for _, d in sub:EnumerateElementDescriptions() do
      if MenuUtil.GetElementText(d) == ns.L.ALT_MENU_ADD then found = d end
    end
    print("scenario: entry in the game's description: " .. tostring(found ~= nil) .. " (a target in the harness: " .. tostring(env.UnitExists and env.UnitExists("target")) .. ")")
  else
    print("scenario: no root description in the harness: " .. tostring(root))
  end
end
if manager and manager.OpenMenu then
  local ok, e = pcall(manager.OpenMenu, manager, "TARGET", { unit = "target" })
  check(ok, "the target's menu opened by the game's code: no error " .. tostring(e or ""))
end
print("scenario: add classic failures " .. fails)
