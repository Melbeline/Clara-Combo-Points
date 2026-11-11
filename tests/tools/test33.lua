-- 1.60: addons' chat lines hidden for 10 s after logging in; the damage meter box
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function has(text) for _, t in ipairs(M.chat) do if t == text then return true end end return false end
local ADDON_STACK = "[Interface/AddOns/Leatrix_Plus/Leatrix_Plus.lua]:13287: in function <...>\n[C]: in ?"
local GAME_STACK = "[Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrame.lua]:10: in function <...>"
local function say(text, stack) M.stack = stack; ChatFrame1:AddMessage(text); M.stack = nil end

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
S.cvars = { damageMeterEnabled = "1" }
C_CVar = C_CVar or {}
C_CVar.GetCVar = function(k) return S.cvars[k] end
C_CVar.SetCVar = function(k, v) S.cvars[k] = tostring(v) end
M.now = 5
M.LoadAddon(ADDON_DIR, ns)
say("BigAddon loaded. Type /big", ADDON_STACK)
check(not has("BigAddon loaded. Type /big"), "an addon's line while the addons load: taken out")
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
say("Leatrix Plus 1.60.21 loaded.", ADDON_STACK)
check(not has("Leatrix Plus 1.60.21 loaded."), "at login: taken out")
M.now = 20
M.Fire("PLAYER_ENTERING_WORLD", true, false)
say("Welcome to World of Warcraft!", GAME_STACK)
check(has("Welcome to World of Warcraft!"), "the game's own line stays")
M.now = 29
say("WeakAuras: 3 auras loaded", ADDON_STACK)
check(not has("WeakAuras: 3 auras loaded"), "9 s after the world shows: still taken out")
M.now = 31
say("Details: segment saved", ADDON_STACK)
check(has("Details: segment saved"), "past 10 s: shown")
M.Fire("PLAYER_ENTERING_WORLD", false, false)
M.now = 32
say("Zoned: addon line", ADDON_STACK)
check(has("Zoned: addon line"), "a later loading screen (zoning): nothing hidden")

out("== the option, in the game's options only")
check(ns:QuietLogin() == true and ns.sv.quietLogin == nil, "on by default")
local category = ns.settingsCategory
M.ShowSettingsPage(category)
local box
for _, f in ipairs(M.frames) do
  local t = f._kind == "CheckButton" and (f.Text or f.text)
  if t and t._text == "Hide addon messages in the chat for 10 seconds after logging in" and f:IsVisible() then box = f end
end
check(box and box:GetChecked() == true, "a box under Reload UI, ticked")
box:Click()
check(ns.sv.quietLogin == false and not ns:QuietLogin(), "unticked: off, kept")

out("== the damage meter in the portrait's menu")
M.OpenUnitMenu("SELF")
local texts = M.UnitMenuTexts()
-- (More...: the section's last line, its own menu holding the toggles used now and then)
local function More()
  for _, e in ipairs(M.unitMenu.root.elements) do if e.text == "More..." then return e end end
end
local function InMore(text)
  local more = More()
  for _, e in ipairs(more and more.elements or {}) do if e.text == text then return e end end
end
local moreAt
for i, t in ipairs(texts) do if t == "More..." then moreAt = i end end
check(moreAt and texts[moreAt - 1] == "<frame>" and moreAt == #texts,
  "More... last in the Clara Combo Points section, at the menu's end: " .. table.concat(texts, " | "))
check(texts[moreAt - 5] == "Leave Party", "the game's own entries left as they are (Leave Party the last of them)")
local d = InMore("Show damage meter")
check(d ~= nil and More().elements[#More().elements].text == "Options", "the damage meter box under More..., Options last")
check(d.isSelected() == true, "ticked: the meter shown")
d.setSelected()
check(S.cvars.damageMeterEnabled == "0" and d.isSelected() == false, "unticked: the game's damage meter hidden (its setting off)")
d.setSelected()
check(S.cvars.damageMeterEnabled == "1", "ticked again: shown")
M.CloseUnitMenu()
S.cvars.damageMeterEnabled = nil
M.OpenUnitMenu("SELF")
texts = M.UnitMenuTexts()
check(not InMore("Show damage meter"), "a client without the meter: no box")
M.CloseUnitMenu()
out("== DynamicCam's camera in the portrait's menu")
local hasCam = false -- (the branches without DynamicCam: no box at all)
for _, m in ipairs(ns.QOL_MODULES or {}) do if m.key == "dynamiccam" then hasCam = true end end
if not hasCam then
  ns.CameraAvailable = function() return true end
  M.OpenUnitMenu("SELF")
  check(not table.concat(M.UnitMenuTexts(), "|"):find("Dynamic camera", 1, true), "DynamicCam not built in: no box")
  M.CloseUnitMenu()
else
local camOn = true
ns.CameraAvailable = function() return true end
ns.CameraOn = function() return camOn end
ns.SetCameraOn = function(_, on) camOn = on end
M.OpenUnitMenu("SELF")
local box = InMore("Dynamic camera")
check(box ~= nil, "a box under More...")
check(box.isSelected() == true, "ticked: the camera changes on")
box.setSelected()
check(camOn == false and box.isSelected() == false, "unticked: off in one click")
M.CloseUnitMenu()
ns.CameraAvailable = function() return false end
M.OpenUnitMenu("SELF")
check(not InMore("Dynamic camera"), "no DynamicCam: no box")
M.CloseUnitMenu()
end
out(fails .. " failure(s)")
