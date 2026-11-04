-- DoesItDie built in (Modules/DoesItDie): its own shared table (Clara's untouched), saved in ClaraDoesItDieDB,
-- the game's look by default (the target health bar's own texture, dark red, the boss skull), its page under
-- its page under Combat, its window from its Options button
local M, S = MOCK, MOCK.state
local E = dofile(TOOLS_DIR .. "/erf_env.lua")
geterrorhandler = function() return function(e) MOCK.errors = MOCK.errors or {}; table.insert(MOCK.errors, e) end end
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false,
  dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false, tullarange = false,
  names = false, tooltipanchor = false, mail = false, reverseengineering = false, idtip = false, soloraidframe = false } }
-- Forever's target frame: its health bar wears an atlas
TargetFrame = CreateFrame("Frame", "TargetFrame", UIParent)
TargetFrame.TargetFrameContent = { TargetFrameContentMain = { HealthBarsContainer = {} } }
local bar = CreateFrame("StatusBar", nil, TargetFrame)
bar:SetSize(120, 20)
local barTexture = bar:CreateTexture()
function barTexture:GetAtlas() return "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health" end
function bar:GetStatusBarTexture() return barTexture end
TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar = bar
TargetFrame.TargetFrameContainer = { Portrait = TargetFrame:CreateTexture() }

local ns = {}
S.class = "WARLOCK"; S.locale = "frFR"
E.Load(ADDON_DIR, ns)
local claraDB = ns.db
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false)
for _, e in ipairs(M.errors or {}) do out("ERR " .. tostring(e)) end

out("== built in")
local P = ns.DoesItDiePrivate
check(ns.DoesItDieRuns and P and P.db == ClaraDoesItDieDB, "runs, its own shared table, saved in ClaraDoesItDieDB")
check(ns.db ~= ClaraDoesItDieDB and ns.display == nil and ns.refresh == nil, "Clara's own table untouched")
check(DoesItDie and DoesItDie.GetDamage ~= nil or DoesItDie ~= nil, "its public API for other addons")
check(SlashCmdList.DOESITDIE and SLASH_DOESITDIE1 == "/did", "/did")
check(ns.doesItDieCategory and ns.doesItDieCategory.parent == ns.qolThemes.combat, "its page under Combat")
check(ns:CanOpenQol("doesitdie"), "its window from the Improvements tab")
M.showKids = true
local okOpen, errOpen = pcall(ns.OpenQol, ns, "doesitdie")
local win = _G.DoesItDieOptions
check(okOpen and win and win:IsShown(), "it opens " .. tostring(errOpen or ""))
local edge = win and win.claraEdge
local classic = ns:ClassicLook() -- (the Light version: Classic's dialog box)
check(edge and win._backdrop == nil and (classic and edge._backdrop and edge._backdrop.edgeFile:find("DialogBox%-Border")
  or not classic and edge.layoutType == "Dialog"), "in the game's dialog border, or Classic's (Look.lua), not its flat one")
if win then win:Hide() end
M.showKids = nil

out("== the game's look by default")
local db = ClaraDoesItDieDB
check(db.fillTexture == "bar" and db.fillColor == "blood" and db.dotColors == "single" and db.skullIcon == "boss"
  and not db.showGlow and not db.showShine and db.outlineStyle == "solid", "a dark red fill in the health bar's own texture, the boss skull, no glow or shine")
check(db.plateFillTexture == "bar" and db.focusFillTexture == "bar", "the same on the focus and the nameplates")
local fills = P.lists.fills
check(fills[2].id == "bar" and P.findById(P.lists.colors, "blood"), "\"The health bar's own look\" and the game's dark red among the choices")
local t = UIParent:CreateTexture()
P.setFillTexture(t, fills[2], bar)
check(t._atlas == "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health", "the fill takes the bar's own atlas (Forever's)")
function barTexture:GetAtlas() return nil end
function barTexture:GetTexture() return "Interface\\TargetingFrame\\UI-StatusBar" end
local t2 = UIParent:CreateTexture()
P.setFillTexture(t2, fills[2], bar)
check(t2._file == "Interface\\TargetingFrame\\UI-StatusBar", "or its file (ClassicUI's classic bar)")
local t3 = UIParent:CreateTexture()
P.setFillTexture(t3, fills[2], nil)
check(t3._file == "Interface\\TargetingFrame\\UI-StatusBar", "no bar found: the classic one")
check(P.textureDir == "Interface\\AddOns\\ClaraComboPoints\\Modules\\DoesItDie\\Textures\\", "its own textures found in Clara's folder")

out("")
out("== quiet while nothing is tracked")
local P = ns.DoesItDiePrivate
local refreshes, refresh = 0, P.refresh
P.refresh = function(...) refreshes = refreshes + 1 return refresh(...) end
for _ = 1, 30 do M.Frame(1 / 30) end -- (a second: the driver's last pass, then quiet)
local settled = refreshes
for _ = 1, 60 do M.Frame(1 / 30) end -- (two more seconds)
check(settled <= 1 and refreshes == settled, "no DoT tracked: no refresh 10 times a second (" .. settled .. ", then " .. refreshes .. ")")
local idle = P.tracking.idle
P.tracking.idle = function() return false end -- (a DoT on its way)
for _ = 1, 30 do M.Frame(1 / 30) end
check(refreshes - settled >= 8, "something tracked: refreshed again (" .. (refreshes - settled) .. " in a second)")
P.tracking.idle, P.refresh = idle, refresh

out(fails .. " failure(s)")
