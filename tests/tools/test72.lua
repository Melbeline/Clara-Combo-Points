-- Beside LootOptimizer Forever (Modules/LOFPlus, no code of LOF's): its bags full window compact (no portrait, its
-- content higher, smaller), no "Not worth a swap" window when the loot is worth less than every bag item (a chat
-- line, LOF's session stopped), its other windows untouched; turned back; its windows in Clara's look. LOF stood in
-- for: its public table and named windows, as LOF 1.6.5 has them.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

if not io.open(ADDON_DIR .. "/Modules/LOFPlus/LOFPlus.lua", "rb") then -- (the Light version: not built in)
  out("  ok   the Light version: not in it"); out("0 failure(s)"); return
end
GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false,
  leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false,
  mail = false, classicui = false, tullarange = false, names = false, tooltipanchor = false, idtip = false, soloraidframe = false,
  enemycasts = false, reverseengineering = false, money = false } }

-- LOF, as its public side is
local calls, stopped, portrait = {}, 0, true
function ButtonFrameTemplate_HidePortrait() portrait = false end
function ButtonFrameTemplate_ShowPortrait() portrait = true end
local function Styled(name, keep)
  local f = CreateFrame("Frame", name, UIParent)
  f.styled, f.template, f.top = true, "ButtonFrameTemplate", keep and -64 or -30
  f.instr = f:CreateFontString()
  local b = CreateFrame("Button", nil, f)
  b.Left, b.Middle, b.Right = b:CreateTexture(), b:CreateTexture(), b:CreateTexture()
  f.okButton = b
  return f
end
local layoutTops = {}
LOF = { UI = { Kit = {} }, Capture = {}, FormatMoney = function(c) return c .. "c" end }
function LOF.Capture.StopSession() stopped = stopped + 1 end
local function Popup() if not LOF_SwapPopup then Styled("LOF_SwapPopup", true):Hide() end return LOF_SwapPopup end
function LOF.UI.ShowSwapPopup(d) table.insert(calls, "swap"); local f = Popup(); table.insert(layoutTops, f.top); f:Show() end
function LOF.UI.ShowInfoPopup(d) table.insert(calls, "info:" .. tostring(d.infoKind)); Popup():Show() end
function LOF.UI.ShowMakeRoomNowPopup(d) table.insert(calls, "room"); Popup():Show() end
function LOF.UI.ToggleDashboard() if not LOF_MainFrame then Styled("LOF_MainFrame", true) end LOF_MainFrame:SetShown(not LOF_MainFrame:IsShown()) end
function LOF.UI.IsDashboardOpen() return LOF_MainFrame ~= nil and LOF_MainFrame:IsShown() end
function LOF.UI.ToggleList()
  if not LOF_ListPopup then
    LOF_ListPopup = CreateFrame("Frame", "LOF_ListPopup", UIParent, "BackdropTemplate")
    LOF_ListPopup:SetBackdrop({ bgFile = "x" })
  end
  LOF_ListPopup:Show()
end
local dressedWindows, dressedDialogs = {}, {}

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
local DressWindow, DressDialog = ns.DressWindow, ns.DressDialog
function ns:DressWindow(f, opts) dressedWindows[f] = opts; return DressWindow(self, f, opts) end
function ns:DressDialog(f, opts) dressedDialogs[f] = opts; return DressDialog(self, f, opts) end
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
local P = ns.LOFPlus

out("== beside LOF")
check(P and P.attached, "LOF there: Clara beside it")
check(#(ns.qolSwitches.lofplus or {}) == 2, "two boxes on its page")
check(ns:QolState("lofplus") == "on", "a module of Clara's (Economy and professions)")

out("== the loot worth less than every bag item: no window")
local low = { infoKind = "low_value", lootItem = { name = "Linen Scrap", value = 10 }, bagItem = { name = "Wool Cloth", value = 33 } }
M.chat = {}
LOF.UI.ShowInfoPopup(low)
check(#calls == 0, "LOF's Not worth a swap window not opened")
check(stopped == 1, "LOF's session stopped (the next loot is asked about again)")
check(M.chat[1] and M.chat[1]:find("Linen Scrap", 1, true) and M.chat[1]:find("10c", 1, true) and M.chat[1]:find("33c", 1, true), "a chat line instead: " .. tostring(M.chat[1]))
LOF.UI.ShowInfoPopup({ infoKind = "nothing_swappable", lootItem = { name = "x", value = 1 } })
check(calls[1] == "info:nothing_swappable", "nothing swappable: its window still")
check(calls[2] == "info:nothing_swappable" and not portrait and LOF_SwapPopup.top == -30, "its first show: compact, laid out again at once with the new top")

out("== the bags full window, compact")
calls, layoutTops = {}, {}
LOF.UI.ShowSwapPopup({ lootItem = {}, bagItem = {} })
local f = LOF_SwapPopup
check(not portrait and f.top == -30, "no portrait, its content higher")
check(#calls == 1 and layoutTops[1] == -30, "compact from then on: laid out once, higher")
check(math.abs(f:GetScale() - 0.85) < 1e-6, "smaller")
calls = {}
LOF.UI.ShowSwapPopup({ lootItem = {}, bagItem = {} })
check(#calls == 1, "afterwards laid out once")
check(dressedWindows[f] and dressedWindows[f].portrait == false, "in Clara's look, as a window without portrait")

out("== turned off")
ns.LOFPlusSet("compact", false); ns.LOFPlusSet("quiet", false)
calls, layoutTops = {}, {}
LOF.UI.ShowSwapPopup({ lootItem = {}, bagItem = {} })
check(portrait and f.top == -64 and f:GetScale() == 1 and layoutTops[2] == -64, "compact off: LOF's own window again")
calls = {}
LOF.UI.ShowInfoPopup(low)
check(calls[1] == "info:low_value", "quiet off: LOF's Not worth a swap window again")
check(ClaraComboPointsDB.lofPlus and ClaraComboPointsDB.lofPlus.compact == false, "kept with Clara's settings")

out("== its other windows in Clara's look")
LOF.UI.ToggleDashboard()
check(dressedWindows[LOF_MainFrame] and dressedWindows[LOF_MainFrame].portrait == true, "its main window, with its portrait")
LOF.UI.ToggleList()
check(dressedDialogs[LOF_ListPopup] and dressedDialogs[LOF_ListPopup].fill, "a plain panel: the game's dialog border and fill")
ns:OpenQol("lofplus")
check(LOF_MainFrame:IsShown(), "its button on Clara's page: LOF's window")

out(fails .. " failure(s)")
