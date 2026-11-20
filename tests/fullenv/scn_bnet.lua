-- The game's social friends list with the harness's frames: Clara's hooks on it, the list refreshed by the game's own
-- code, its Battle.net friends put back when its search gives none: no error
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
local social = rawget(env, "SocialUIFrame")
local view = social and social.FriendsList
print("scenario: SocialUIFrame " .. tostring(social) .. ", its FriendsList " .. tostring(view) .. ", BnetBack " .. tostring(ns.AltFriends and ns.AltFriends.BnetBack))
if view and ns.AltFriends and ns.AltFriends.HookSocial then
  local ok, e = pcall(ns.AltFriends.HookSocial)
  check(ok, "hooked on the game's list " .. tostring(e or ""))
  if view.Refresh then
    ok, e = pcall(view.Refresh, view)
    check(ok, "the game's own refresh: no error " .. tostring(e or ""))
  end
end
if ns.AltFriends and ns.AltFriends.BnetReport then
  local ok, lines = pcall(ns.AltFriends.BnetReport)
  check(ok and type(lines) == "table", "its report line: " .. tostring(ok and lines[1]))
end
print("scenario: bnet failures " .. fails)
