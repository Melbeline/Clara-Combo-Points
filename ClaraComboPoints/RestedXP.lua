-- Clara Combo Points - the rested XP left, in the experience bar's tooltip: on the game's rest line, after its name
-- ("Rested  xp: 1,600 - 16%": the rested XP still to come, and what it is of the level), as 1.x players read it; on
-- the game's own experience bar (its two places), hovered on the bar or on its rest tick. (ClassicUI Forever had it
-- on its own bar: where ClassicUI runs, it keeps its own, with its box; this one steps aside.)

local ADDON, ns = ...
local L = ns.L

local issecret = issecretvalue or function() return false end
local function Secret(...)
  for i = 1, select("#", ...) do if issecret((select(i, ...))) then return true end end
  return false
end

local function Escape(text) return (text:gsub("[%%%(%)%.%+%-%*%?%[%]%^%$]", "%%%0")) end

local function RestedLine()
  if ns.ClassicUIRuns then return end -- (ClassicUI's own)
  if not (GameTooltip and GameTooltip:IsShown()) then return end
  local rest, most = GetXPExhaustion and GetXPExhaustion(), UnitXPMax("player")
  if not rest or Secret(rest, most) or type(rest) ~= "number" or type(most) ~= "number" or rest <= 0 or most <= 0 then
    return
  end
  local _, stateName = GetRestState()
  if type(stateName) ~= "string" or issecret(stateName) or stateName == "" then return end
  local amount = BreakUpLargeNumbers and BreakUpLargeNumbers(rest) or tostring(rest)
  local head = L.XPR_INLINE:format(stateName, amount, math.floor(rest / most * 100 + .5))
  for i = 2, GameTooltip:NumLines() do
    local line = _G["GameTooltipTextLeft" .. i]
    local text = line and line:GetText()
    if type(text) == "string" and not issecret(text) and text:find("^" .. Escape(stateName)) then
      if text:find(head, 1, true) then return end -- (already there)
      line:SetText((text:gsub("^" .. Escape(stateName), (head:gsub("%%", "%%%%")), 1)))
      GameTooltip:Show()
      return
    end
  end
end
ns.RestedXPLine = RestedLine -- (for the tests)

-- The game's experience bar in its two places (the bars' own hover and their rest tick's), hooked once each
local hooked = setmetatable({}, { __mode = "k" })
local function HookOnce(frame)
  if type(frame) ~= "table" or hooked[frame] or not frame.HookScript then return end
  hooked[frame] = true
  frame:HookScript("OnEnter", RestedLine)
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
    for _, bar in pairs(type(container) == "table" and type(container.bars) == "table" and container.bars or {}) do
      if type(bar) == "table" and bar.ExhaustionTick then
        HookOnce(bar)
        HookOnce(bar.ExhaustionTick)
      end
    end
  end
end)
