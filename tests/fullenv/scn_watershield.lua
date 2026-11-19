-- Water Shield Tracker in the harness (the game's frames, templates, animations): a rogue first (nothing made),
-- its page opened, "every class" ticked: its icon made and shown, its secure button, the aura changes, its sliders,
-- the text's place, /ws lock and reset; no error
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
local W = ns.WaterShield
check(W ~= nil and W.frame == nil, "a rogue: nothing made")
local page, parts = ns.WaterShieldPage, ns.WaterShieldParts
local onShow = page and page:GetScript("OnShow")
check(onShow ~= nil, "its page")
if onShow then onShow(page) end
check(parts.allClasses ~= nil and parts.size ~= nil and parts.radios and parts.radios.BOTTOMRIGHT ~= nil, "its parts built")
-- (the harness's check boxes neither tick nor tell they are ticked, its frames never say they show: the setting
-- itself, then the world shown again)
env.ClaraWaterShieldDB.allClasses = true
local ok, e = pcall(H.Fire, "PLAYER_ENTERING_WORLD", false, true)
check(ok, "every class ticked " .. tostring(e or ""))
check(W.frame ~= nil, "its icon made")
check(rawget(env, "ClaraWaterShieldCastButton") ~= nil, "its secure button")
H.Fire("UNIT_AURA", "player")
H.Fire("PLAYER_REGEN_DISABLED")
H.Fire("PLAYER_REGEN_ENABLED")
local okR = pcall(parts.radios.BOTTOMRIGHT:GetScript("OnClick"), parts.radios.BOTTOMRIGHT)
check(okR and env.ClaraWaterShieldDB.textAnchor == "BOTTOMRIGHT", "the number at the bottom right")
local slash = env.SlashCmdList and env.SlashCmdList.CLARAWATERSHIELD
check(slash ~= nil, "/ws")
if slash then
  check(pcall(slash, "lock") and env.ClaraWaterShieldDB.locked == true, "/ws lock")
  check(pcall(slash, "reset") and env.ClaraWaterShieldDB.point == "CENTER", "/ws reset")
end
print("scenario: water shield failures " .. fails)
