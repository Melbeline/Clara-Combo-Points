-- /who cooldown (Modules/WhoCooldown): after a /who the server refuses another for 7 s (the user's measure); the Who
-- list's search button shows the time left (a line crossing it, or the seconds in place of its text) and flashes when
-- /who is ready again. A /who sent meanwhile (refused) does not start it again. Its card's two boxes: both off, nothing.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70888", "Nov 10 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, mail = false, classicui = false, tullarange = false,
  names = false, tooltipanchor = false }, whoCD = { low = 6, high = 9 } }
C_FriendList = { SendWho = function() end, GetNumWhoResults = function() return 0, 0 end, GetWhoInfo = function() return nil end }
local refresh = CreateFrame("Button", "WhoFrameWhoButton", UIParent, "UIPanelButtonTemplate")
refresh:SetSize(85, 22); refresh:SetText("Refresh"); refresh:Show()
S.class = "ROGUE"; S.locale = "enUS"
local ns = {}
M.now = 1000
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local function Step(seconds) local n = math.floor(seconds / .1 + .5) for _ = 1, n do M.Frame(.1) end end
local function Parts()
  local p = ns.whoCooldownButtons and ns.whoCooldownButtons[refresh]
  if p then return p.overlay, p.line, p.fill, p.flash end
end
check(ns:QolRuns("whocooldown"), "on by default")
check(ns:WhoCooldownMode() == "bar" and ns:WhoCooldownLength() == 7, "the bar, 7 s")
check(ns.sv.whoCD.low == nil and ns.sv.whoCD.high == nil, "what the first version learned dropped")
local sw = ns.qolSwitches.whocooldown
check(sw and #sw == 2 and sw[1].label == "WHO_CD_BAR" and sw[2].label == "WHO_CD_COUNT" and sw[1].get() and not sw[2].get(), "its card: two boxes, the bar ticked")

out("== a /who: the line crosses the button for 7 s")
C_FriendList.SendWho('"Charlotte"')
Step(.1)
local o, line = Parts()
check(o and o:IsShown() and line:IsShown(), "the line over the button at once")
local function X() local p = line._points and line._points[1] return p and p[4] end
local x1 = X()
Step(3)
local x2 = X()
check(x1 and x2 and x2 > x1, "it moves left to right (" .. tostring(x1) .. " -> " .. tostring(x2) .. ")")
out("== another /who 3 s later (refused by the server): the time goes on")
C_FriendList.SendWho("Lia")
Step(.1)
check(X() >= x2, "not started again")
Step(3.5) -- (6.7 s since the first)
check(line:IsShown(), "6.7 s: still on")
Step(.5)
local _, _, _, flash = Parts()
check(not line:IsShown() and flash:GetAlpha() > 0, "7 s: gone, the flash")
Step(1)
check(flash:GetAlpha() == 0 and not o:IsShown(), "the flash faded, nothing left over the button")

out("== countdown")
sw[2].set(true)
check(ns:WhoCooldownMode() == "count" and not sw[1].get(), "the countdown box ticks off the bar")
C_FriendList.SendWho("x")
Step(.1)
check(refresh:GetText() == "7", "the seconds left in place of Refresh: " .. tostring(refresh:GetText()))
Step(1)
check(refresh:GetText() == "6", "then 6")
Step(6)
check(refresh:GetText() == "Refresh", "at the end: Refresh back")
Step(1)

out("== both boxes off: nothing")
sw[2].set(false)
check(ns:WhoCooldownMode() == "none", "neither ticked")
C_FriendList.SendWho("c"); Step(.5)
check(not line:IsShown() and refresh:GetText() == "Refresh", "no line, no countdown")
Step(7)
check(flash:GetAlpha() == 0, "no flash")
out(string.format("\n%d failure(s)", fails))
return fails
