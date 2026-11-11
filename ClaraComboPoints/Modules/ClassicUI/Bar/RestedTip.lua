local _, ClaraNS = ... -- (Clara Combo Points: ClassicUI Forever built in, QoL.lua)
if not (type(ClaraNS) == "table" and ClaraNS.ClassicUIRuns) then return end
local ns = ClaraNS.ClassicUIPrivate
local L = ns.L

-- Rested XP in the XP bar's tooltip (option, on by default): on the client's rest line, after its name
-- ("Rested  xp : 1600 - 10%": the rested XP left, and what it is of the level), as 1.x players read it.

local function Escape(text) return (text:gsub("[%%%(%)%.%+%-%*%?%[%]%^%$]", "%%%0")) end

local function RestedLine()
    if not (ns.db and ns.db.xpTipRested == true) then return end
    if not GameTooltip:IsShown() then return end
    local rest, most = GetXPExhaustion(), UnitXPMax("player")
    if not rest or ns.AnySecret(rest, most) or rest <= 0 or most <= 0 then return end
    local _, stateName = GetRestState()
    if type(stateName) ~= "string" or ns.IsSecret(stateName) or stateName == "" then return end
    local head = L["UI_RESTED_XP_INLINE"]:format(stateName, BreakUpLargeNumbers(rest), math.floor(rest / most * 100 + .5))
    for i = 2, GameTooltip:NumLines() do
        local line = _G["GameTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if type(text) == "string" and not ns.IsSecret(text) and text:find("^" .. Escape(stateName)) then
            if text:find(head, 1, true) then return end -- (already there)
            line:SetText((text:gsub("^" .. Escape(stateName), (head:gsub("%%", "%%%%")), 1)))
            GameTooltip:Show()
            return
        end
    end
end

ns.EventFrame("PLAYER_LOGIN", function()
    -- (on by default: put on once for those who had it off from before)
    local sv = ClaraNS.sv
    if ns.db and sv and not sv.cuiRestedOn then
        ns.db.xpTipRested = true
        sv.cuiRestedOn = true
    end
    for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        for _, bar in pairs(container and container.bars or {}) do
            if bar.ExhaustionTick then ns.HookScriptOnce(bar, "OnEnter", RestedLine) end
        end
    end
end)
