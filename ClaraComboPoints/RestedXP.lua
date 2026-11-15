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

-- A line's text without its colors (WoW Forever writes the rest's name in gold: "|cffffd100Rested|r")
local function Plain(text) return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

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
  local tail = head:sub(#stateName + 1) -- ("  xp: 1,600 - 16%", put after the rest's name)
  local lines = {}
  for i = 1, GameTooltip:NumLines() do
    local line = _G["GameTooltipTextLeft" .. i]
    local text = line and line:GetText()
    if type(text) == "string" and not issecret(text) then
      local plain = Plain(text)
      if plain:find(head, 1, true) then return end -- (already there)
      lines[#lines + 1] = { line = line, text = text, plain = plain }
    end
  end
  -- On the game's rest line (the one starting with the rest's name, whatever its colors): after its name
  for _, l in ipairs(lines) do
    if l.plain:find("^%s*" .. Escape(stateName)) then
      local _, last = l.text:find(Escape(stateName))
      if last then
        l.line:SetText(l.text:sub(1, last) .. tail .. l.text:sub(last + 1))
        GameTooltip:Show()
        return
      end
    end
  end
  -- (no such line: one of its own)
  GameTooltip:AddLine(head, 1, 1, 1)
  GameTooltip:Show()
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
