-- /who cooldown (Modules/WhoCooldown): after a /who the server refuses another a moment; the Who list's search button
-- shows the time left (a line crossing it, or the seconds in place of its text) and flashes when /who is ready again.
-- The time is learned from the server's answers: 5 s at first, less when a /who is taken sooner, just more than a
-- delay the server refused. Its card's two boxes: both off, nothing shown.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70888", "Nov 10 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, mail = false, classicui = false, tullarange = false,
  names = false, tooltipanchor = false } }
local sent = {}
C_FriendList = { SendWho = function(t) sent[#sent + 1] = t end, GetNumWhoResults = function() return 0, 0 end,
  GetWhoInfo = function() return nil end }
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
check(ns:WhoCooldownMode() == "bar" and ns:WhoCooldownLength() == 5, "the bar, 5 s until it learns")
local sw = ns.qolSwitches.whocooldown
check(sw and #sw == 2 and sw[1].label == "WHO_CD_BAR" and sw[2].label == "WHO_CD_COUNT" and sw[1].get() and not sw[2].get(), "its card: two boxes, the bar ticked")
check(ns.L.QOL_NAV_WHOCOOLDOWN ~= nil and ns.L.QOL_ABOUT_WHOCOOLDOWN ~= nil, "its card's name and text")

out("== a /who taken: the line crosses the button")
C_FriendList.SendWho('"Charlotte"')
Step(.2)
M.Fire("WHO_LIST_UPDATE")
Step(.1)
local o, line, fill = Parts()
check(o and o:IsShown() and line:IsShown(), "the line over the button")
local function X() local p = line._points and line._points[1] return p and p[4] end
local x1 = X()
Step(2)
local x2 = X()
check(x1 and x2 and x2 > x1, "it moves left to right (" .. tostring(x1) .. " -> " .. tostring(x2) .. ")")
check(refresh:GetText() == "Refresh", "the text left as it is")
Step(3)
local _, _, _, flash = Parts()
check(not line:IsShown(), "5 s later: the line gone")
check(flash and flash:GetAlpha() > 0, "a light flash: /who ready")
Step(1)
check(flash:GetAlpha() == 0 and not o:IsShown(), "the flash faded, nothing left over the button")

out("== countdown")
sw[2].set(true)
check(ns:WhoCooldownMode() == "count" and not sw[1].get(), "the countdown box ticks off the bar")
C_FriendList.SendWho("x")
Step(1.6) -- (no refusal: taken)
check(refresh:GetText() == "4", "the seconds left in place of Refresh: " .. tostring(refresh:GetText()))
Step(1)
check(refresh:GetText() == "3", "then 3")
Step(3)
check(refresh:GetText() == "Refresh", "at the end: Refresh back")

out("== the server refuses: the time learned past it")
-- taken at 1000 + ~9.3 ; a /who 6 s later refused
local takenAt = M.now - 4.4
Step(.5)
sw[1].set(true)
local before = ns:WhoCooldownLength()
M.now = takenAt + 6
C_FriendList.SendWho("y")
Step(.3)
M.Fire("CHAT_MSG_SYSTEM", "You must wait a moment longer before using /who again.")
Step(.1)
check(ns:WhoCooldownLength() > 6 and ns:WhoCooldownLength() > before, "refused after 6 s: more than 6 s now (" .. ns:WhoCooldownLength() .. ")")
check(line:IsShown(), "and the line shows what is left")
check(ns.sv.whoCD.low ~= nil, "kept with Clara's settings")
Step(3)
out("== a /who taken sooner than thought: the time comes down")
local s = ns.sv.whoCD
s.low, s.high = nil, nil
C_FriendList.SendWho("a"); Step(1.6)
Step(1.4)
C_FriendList.SendWho("b"); Step(1.6) -- (taken 3 s after the one before)
check(ns:WhoCooldownLength() == 3, "taken after 3 s: 3 s now (" .. ns:WhoCooldownLength() .. ")")

out("== both boxes off: nothing")
sw[1].set(false)
check(ns:WhoCooldownMode() == "none", "neither ticked")
Step(4)
C_FriendList.SendWho("c"); Step(1.7)
check(not line:IsShown() and refresh:GetText() == "Refresh", "no line, no countdown")
Step(4)
local _, _, _, flash2 = Parts()
check(flash2:GetAlpha() == 0, "no flash")
out(string.format("\n%d failure(s)", fails))
return fails
