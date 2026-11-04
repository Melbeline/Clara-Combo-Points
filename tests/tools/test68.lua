-- One look for Clara's windows (Look.lua): the game's dialog border and title plate with the game's interface,
-- ClassicUI's dressing while ClassicUI dresses windows, Classic's dialog box from the game's files in the Light
-- version; BuyEmAll's, DoesItDie's and the options window's dressed as they first show
local M, S = MOCK, MOCK.state
M.showKids = true -- (as the game: a child's OnShow runs as its parent shows)
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false, tullarange = false, names = false,
  tooltipanchor = false, mail = false, reverseengineering = false, idtip = false, soloraidframe = false, enemycasts = false } }

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false)

local function Dialog()
  local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  f:SetSize(300, 200)
  f:SetBackdrop({ bgFile = "x" })
  f:Hide()
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  local ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  return f, close, ok
end

local SRC = assert(io.open(ADDON_DIR .. "/Look.lua")):read("*a")
local LIGHT = SRC:find("local OLD_LOOK = true", 1, true) ~= nil
local function OldEdgeOf(frame) local e = frame.claraEdge return e and e._backdrop and e._backdrop.edgeFile == "Interface\\DialogFrame\\UI-DialogBox-Border" end
if LIGHT then
  out("== the Light version: Classic's look everywhere")
  check(ns:ClassicLook(), "Classic's look without ClassicUI")
  local d, dclose = Dialog()
  ns:DressDialog(d, { fill = true, close = dclose })
  d:Show()
  check(OldEdgeOf(d), "a dialog: Classic's dialog box")
  ClaraBuyEmAllFrame:Show()
  check(OldEdgeOf(ClaraBuyEmAllFrame), "BuyEmAll's window too")
  ClaraBuyEmAllFrame:Hide()
  SlashCmdList.CLARACOMBOPOINTS("")
  local o = ClaraComboPointsOptions
  check(o and o:IsShown() and OldEdgeOf(o), "the options window: Classic's dialog edge round it")
  out(fails .. " failures")
  return
end

out("== the game's look")
check(not ns:ClassicLook(), "no ClassicUI: the game's")
local f, close, ok = Dialog()
ns:DressDialog(f, { fill = true, close = close, buttons = { ok } })
check(f._backdrop == nil and f.claraEdge == nil, "its own backdrop off; dressed only as it shows")
f:Show()
local edge = f.claraEdge
check(edge and edge.layoutType == "Dialog" and edge.TopLeftCorner ~= nil, "the game's dialog border (its Dialog layout)")
check(close:GetFrameLevel() > edge:GetFrameLevel(), "its close button over the border")
local fills = 0
for _, r in ipairs(M.regions) do if r._parent == f and r._file == "Interface\\DialogFrame\\UI-DialogBox-Background" then fills = fills + 1 end end
check(fills == 1, "the dialog's fill under it")
f:Hide(); f:Show()
check(f.claraEdge == edge, "dressed once")
local w, wclose = Dialog()
w:Show()
ns:DressDialog(w, { close = wclose })
check(w.claraEdge ~= nil, "a dialog shown already: dressed at once")

out("== BuyEmAll, DoesItDie, the options window")
local bea = ClaraBuyEmAllFrame
check(bea and bea.claraEdge == nil, "BuyEmAll's window: not yet")
bea:Show()
check(bea.claraEdge and bea.claraEdge.layoutType == "Dialog", "shown: in the game's dialog border")
bea:Hide()
SlashCmdList.CLARACOMBOPOINTS("")
local p = ClaraComboPointsOptions
check(p and p:IsShown() and p.claraEdge == nil, "the options window: the game's own window, untouched")

out("== ClassicUI's look")
local calls = {}
local function Record(name, fail) return function(...) calls[#calls + 1] = { name, ... }; if fail then error("boom") end end end
local cui = {
  panels = { active = true },
  OwnBackdropFrame = function(parent) calls[#calls + 1] = { "OwnBackdropFrame" }; return CreateFrame("Frame", nil, parent, "BackdropTemplate") end,
  Backdrop = function(frame, info) calls[#calls + 1] = { "Backdrop", info }; frame:SetBackdrop(info) end,
  DialogEdge = function(size) return { edgeFile = "old", edgeSize = size } end,
  OldDialogHeader = Record("OldDialogHeader"), SkinCloseButton = Record("SkinCloseButton"),
  SkinRedButton = Record("SkinRedButton"), SkinCheckbox = Record("SkinCheckbox"),
  SkinWindow = Record("SkinWindow"), SkinTopTab = Record("SkinTopTab", true),
}
ns.ClassicUIRuns, ns.ClassicUIPrivate = true, cui
local function Called(name) local n = 0 for _, c in ipairs(calls) do if c[1] == name then n = n + 1 end end return n end
check(ns:ClassicLook(), "ClassicUI dressing windows: Classic's look")
f, close, ok = Dialog()
ns:DressDialog(f, { fill = true, close = close, buttons = { ok } })
f:Show()
check(f.claraEdge and f.claraEdge._backdrop and f.claraEdge._backdrop.edgeFile == "old", "ClassicUI's old dialog edge, in its theme")
check(Called("SkinCloseButton") == 1 and Called("SkinRedButton") == 1, "its close and red buttons")
local win = CreateFrame("Frame", nil, UIParent, "DefaultPanelTemplate")
win:Hide()
local tab = CreateFrame("Button", nil, win, "PanelTopTabButtonTemplate")
ns:DressWindow(win, { portrait = false, tabs = { tab } })
win:Show()
local skin
for _, c in ipairs(calls) do if c[1] == "SkinWindow" then skin = c end end
check(skin and skin[2] == win and skin[3].portrait == false and skin[3].scrollBars == false, "a window: ClassicUI's own window dressing")
check(Called("SkinTopTab") == 1 and win:IsShown(), "its tabs (a failing one breaks nothing)")
local cb = CreateFrame("CheckButton", nil, UIParent, "UICheckButtonTemplate")
ns:DressCheck(cb)
check(Called("SkinCheckbox") == 1, "a check box: ClassicUI's")
cui.panels.active = false
check(not ns:ClassicLook(), "ClassicUI's window frames off: the game's look")
ns.ClassicUIRuns, ns.ClassicUIPrivate = nil, nil

out("== the Light version")
local light = SRC:gsub("local OLD_LOOK = false", "local OLD_LOOK = true", 1)
local ns2 = {}
assert(loadstring(light))("ClaraComboPoints", ns2)
check(ns2:ClassicLook(), "Classic's look without ClassicUI")
f, close = Dialog()
ns2:DressDialog(f, { fill = true, close = close })
f:Show()
local bd = f.claraEdge and f.claraEdge._backdrop
check(bd and bd.edgeFile == "Interface\\DialogFrame\\UI-DialogBox-Border" and bd.edgeSize == 32, "Classic's dialog border, from the game's files")
win = CreateFrame("Frame", nil, UIParent, "PortraitFrameTemplate")
NineSliceUtil.ApplyLayoutByName(win.NineSlice, "PortraitFrameTemplate")
win:Hide()
ns2:DressWindow(win)
win:Show()
check(win.NineSlice.TopLeftCorner:GetAlpha() == 0 and win.claraEdge and win.claraEdge._backdrop.edgeFile:find("DialogBox%-Border"),
  "a window: its metal faded, Classic's dialog edge round it")
check(win.PortraitContainer.portrait:IsShown(), "its portrait kept")

out(fails .. " failures")
