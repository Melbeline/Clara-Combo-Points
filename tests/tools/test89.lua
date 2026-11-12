-- Windows in a fight, in the mouse report (GameFixes.lua): a window the game's panel manager did not show in a fight
-- (and who asked), its "Interface action failed" and who made it, Clara's own refusals and where from, the blocked calls
-- the game names; the game's windows protected now, with the protected frames inside them
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local function Win(name, protected, kids)
  local f = { name = name, shown = false, kids = kids or {} }
  function f:IsShown() return self.shown end
  function f:IsProtected() return protected, false end
  function f:GetChildren() return unpack(self.kids) end
  function f:GetDebugName() return self.name end
  function f:GetName() return self.name end
  _G[name] = f
  return f
end
local raidButton = { name = "RaidFrame.RaidGroupButton1" }
function raidButton:IsProtected() return true, true end
function raidButton:GetChildren() end
function raidButton:GetDebugName() return self.name end
local raidFrame = { name = "RaidFrame", kids = { raidButton } }
function raidFrame:IsProtected() return true, false end
function raidFrame:GetChildren() return unpack(self.kids) end
function raidFrame:GetDebugName() return self.name end
local friends = Win("TestSocialFrame", true, { raidFrame })
local character = Win("TestSheetFrame", false)
UIPanelWindows = { TestSocialFrame = { area = "left" }, TestSheetFrame = { area = "left" } }
local blockedSaid = 0
function ShowUIPanel(frame) if not InCombatLockdown() then frame.shown = true end end
function DisplayInterfaceActionBlockedMessage() blockedSaid = blockedSaid + 1 end
ERR_NOT_IN_COMBAT = "You can't do that while in combat"
UIErrorsFrame = { AddMessage = function() end }

local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
local function Report() return table.concat(ns:FightWindowsReport(), "\n") end
check(Report():find("nothing refused this session", 1, true) ~= nil, "nothing yet")

out("== out of combat: a window opens, nothing noted")
ShowUIPanel(character)
check(character.shown and not Report():find("not shown", 1, true), "shown, not noted")

out("== in combat: the game's key opens the social window, refused")
S.inCombat = true
M.stack = '[string "@Interface/AddOns/Blizzard_FrameXML/Bindings.lua"]:1: in function <...>'
ShowUIPanel(friends)
local r = Report()
check(r:find("TestSocialFrame not shown (asked by Bindings:1, the window protected)", 1, true) ~= nil, "noted, with who asked and why")

out("== Clara's own refusal, and the game's")
M.stack = '[string "@Interface/AddOns/ClaraComboPoints/Modules/ClassicUI/UI/Dialogs.lua"]:478: in function SayNotInCombat\n'
  .. '[string "@Interface/AddOns/ClaraComboPoints/Modules/ClassicUI/Social/SocialWindow.lua"]:201: in function <...>'
UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1)
M.stack = '[string "@Interface/AddOns/Blizzard_UIErrors/UIErrorsFrame.lua"]:50: in function <...>'
UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1)
r = Report()
check(r:find("from SocialWindow:201", 1, true) ~= nil, "Clara's refusal: where it came from")
check(select(2, r:gsub("You can't do that while in combat", "")) == 1, "the game's own refusal (casting...): not noted")

out("== the blocked-action message and a blocked call")
M.stack = '[string "@Interface/AddOns/ClaraComboPoints/Modules/ClassicUI/Social/GuildOpeners.lua"]:120: in function <...>'
DisplayInterfaceActionBlockedMessage()
M.Fire("ADDON_ACTION_BLOCKED", "ClaraComboPoints", "Frame:Show()")
r = Report()
check(r:find('"Interface action failed" (GuildOpeners:120)', 1, true) ~= nil, "the message: who made it")
check(r:find("blocked: ClaraComboPoints Frame:Show()", 1, true) ~= nil, "the blocked call")
S.inCombat = false
M.stack = nil

out("== protected windows now")
check(r:find("TestSocialFrame: RaidFrame.RaidGroupButton1", 1, true) ~= nil, "the social window, and the raid button that makes it so")
check(not r:find("TestSheetFrame:", 1, true), "an unprotected window: not listed")
out("\n" .. r)
out(string.format("\n%d failure(s)", fails))
return fails
