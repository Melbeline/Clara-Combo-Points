-- Clara Combo Points - beside LootOptimizer Forever (LOF, by Peter; its own addon, "All Rights Reserved": none of
-- its code is here, it is changed from outside as it runs, through what it makes public: its LOF table and its
-- named windows). Nothing happens without it.
--   * Its "bags full" window, compact: no portrait (the empty band under its title goes), and smaller.
--   * No window when the loot is worth less than every item LOF could swap it for (its "Not worth a swap"
--     window): a line in the chat instead, the loot left where it is. Its other windows (a swap worth it, gear,
--     a quest item, a reagent, nothing swappable) still open.
--   * Its windows in Clara's look (Look.lua): ClassicUI's old window while ClassicUI runs, the game's dialog
--     border round its plain panels, red buttons under ClassicUI.
-- Each part has its box on its page (Esc > Options > AddOns > Clara > Economy and professions).
local ADDON, ns = ...
local L = ns.L

local DEFAULTS = { compact = true, quiet = true }
local COMPACT_SCALE = 0.85
local COMPACT_TOP = -30 -- (its content's top without the portrait; with it, -64)

local function Get(key)
  local saved = ns.sv and ns.sv.lofPlus
  local v = saved and saved[key]
  if v == nil then return DEFAULTS[key] end
  return v
end
local function Set(key, v)
  if not ns.sv then return end
  local saved = ns.sv.lofPlus or {}
  if v == DEFAULTS[key] then saved[key] = nil else saved[key] = v end
  ns.sv.lofPlus = next(saved) and saved or nil
end
ns.LOFPlusGet, ns.LOFPlusSet = Get, Set

if not ns:QolRuns("lofplus") then return end

ns:SetQolSwitches("lofplus", {
  { label = "LOFPLUS_COMPACT", get = function() return Get("compact") end, set = function(on) Set("compact", on) end },
  { label = "LOFPLUS_QUIET", get = function() return Get("quiet") end, set = function(on) Set("quiet", on) end },
})
ns:SetQolOpener("lofplus", function()
  local LOF = _G.LOF
  if LOF and LOF.UI and LOF.UI.ToggleDashboard and not (LOF.UI.IsDashboardOpen and LOF.UI.IsDashboardOpen()) then
    LOF.UI.ToggleDashboard()
  end
end)

local P = {} -- (for the tests)
ns.LOFPlus = P

---------------------------------------------------------------------------
-- The bags full window, compact
---------------------------------------------------------------------------
local function Popup() return _G.LOF_SwapPopup end

-- Its look for the setting: portrait and top as LOF has them, or none and higher up, smaller
function P.Compact(f)
  if not (f and f.styled) then return false end
  local want = Get("compact") and true or false
  if f.claraTop == nil then f.claraTop = f.top end
  local changed = (f.claraCompact or false) ~= want
  if changed then
    f.claraCompact = want
    if f.template == "ButtonFrameTemplate" then
      if want and ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(f) end
      if not want and ButtonFrameTemplate_ShowPortrait then ButtonFrameTemplate_ShowPortrait(f) end
    end
    f.top = want and COMPACT_TOP or f.claraTop
    if f.instr then -- (the instructions' place: built at its first top)
      f.instr:ClearAllPoints()
      f.instr:SetPoint("TOPLEFT", f, "TOPLEFT", 16, f.top)
    end
  end
  f:SetScale(want and COMPACT_SCALE or 1)
  return changed
end

-- A chat line instead of the "Not worth a swap" window
local function Quietly(d)
  local LOF = _G.LOF
  local loot, bag = d.lootItem or {}, d.bagItem or {}
  local money = LOF and LOF.FormatMoney or GetCoinTextureString or tostring
  local text = L.LOFPLUS_NOT_WORTH:format(loot.link or loot.name or "?", money(tonumber(loot.value) or 0),
    money(tonumber(bag.value) or 0))
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99LOF|r " .. text) end
  if LOF and LOF.Capture and LOF.Capture.StopSession then LOF.Capture.StopSession() end
end
P.Quietly = Quietly

-- The loot worth less than the cheapest bag item LOF could swap it for (its own verdict, "low_value")
function P.NotWorth(d)
  return type(d) == "table" and d.infoKind == "low_value" and d.bagItem ~= nil
end

local POPUPS = { "ShowSwapPopup", "ShowInfoPopup", "ShowMakeRoomNowPopup", "ShowDestroyInstructions",
  "ShowLeftBehindPopup" }

local function WrapPopups(UI)
  for _, key in ipairs(POPUPS) do
    local original = type(UI[key]) == "function" and UI[key]
    if original then
      UI[key] = function(...)
        if key == "ShowInfoPopup" and Get("quiet") and P.NotWorth((...)) then return Quietly((...)) end
        local results = { original(...) }
        -- laid out again at once with the new top when the look changed (LOF lays it out as it shows it)
        if P.Compact(Popup()) and Popup():IsShown() then original(...) end
        return unpack(results)
      end
    end
  end
end

---------------------------------------------------------------------------
-- Its windows in Clara's look
---------------------------------------------------------------------------
-- (its windows from the game's ButtonFrameTemplate, the main one keeping its portrait; the others plain panels)
local WINDOWS = { "LOF_MainFrame", "LOF_SwapPopup", "LOF_HoldingsFrame", "LOF_SettingsFrame", "LOF_AltMailFrame",
  "LOF_GuideFrame", "LOF_ListPopup", "LOF_ConfirmDialog" }
local dressed = {}

local function Buttons(frame, out, depth)
  if not (frame and frame.GetChildren) or depth > 4 then return out end
  for _, child in ipairs({ frame:GetChildren() }) do
    if child.IsObjectType and child:IsObjectType("Button") and child.Left and child.Middle and child.Right then
      out[#out + 1] = child
    end
    Buttons(child, out, depth + 1)
  end
  return out
end

function P.Dress()
  for _, name in ipairs(WINDOWS) do
    local f = _G[name]
    if f and not dressed[f] then
      dressed[f] = true
      local buttons = Buttons(f, {}, 0)
      if f.styled then
        ns:DressWindow(f, { portrait = name == "LOF_MainFrame" or (name == "LOF_SwapPopup" and not Get("compact")) })
        for _, b in ipairs(buttons) do ns:DressButton(b) end
      elseif f.SetBackdrop then
        ns:DressDialog(f, { fill = true, dark = true, close = f.close or f.CloseButton, buttons = buttons })
      end
    end
  end
end

-- After each of its public UI calls (windows are built on their first show): the new ones dressed
local function HookUI(UI)
  for key, fn in pairs(UI) do
    if type(fn) == "function" then hooksecurefunc(UI, key, P.Dress) end
  end
  if type(UI.Kit) == "table" then
    for key, fn in pairs(UI.Kit) do
      if type(fn) == "function" then hooksecurefunc(UI.Kit, key, P.Dress) end
    end
  end
end

function P.Attach()
  local LOF = _G.LOF
  if P.attached or not (type(LOF) == "table" and type(LOF.UI) == "table") then return false end
  P.attached = true
  WrapPopups(LOF.UI)
  HookUI(LOF.UI)
  P.Dress()
  return true
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, name)
  if event == "ADDON_LOADED" and name ~= "LOF" then return end
  if P.Attach() then self:UnregisterAllEvents() end
end)
