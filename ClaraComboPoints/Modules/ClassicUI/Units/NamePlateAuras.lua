local _, ClaraNS = ... -- (Clara Combo Points: ClassicUI Forever built in, QoL.lua)
if not (type(ClaraNS) == "table" and ClaraNS.ClassicUIRuns) then return end
local ns = ClaraNS.ClassicUIPrivate

-- The theme on the client's nameplate aura rings (as drawn with the theme off). Watch only: new rings are found after
-- aura updates, in the next frame.

local RING_ATLAS = "UI-HUD-CoolDownManager-IconOverlay"
local LISTS = { "DebuffListFrame", "BuffListFrame", "CrowdControlListFrame" }
local RING_EVENTS = { "UNIT_AURA", "NAME_PLATE_UNIT_ADDED" }

local ringed = setmetatable({}, { __mode = "k" })   -- aura item -> true once its ring is tinted

local function TintRegion(region, item)
    if ringed[item] or not region.GetAtlas or ns.Safe(region:GetAtlas()) ~= RING_ATLAS then return end
    ringed[item] = true
    ns.BronzeTint(region)
end

local function TintItem(item)
    if not ringed[item] then ns.EachRegion(item, TintRegion, item) end
end

local function TintPlate(unitFrame)
    local auras = unitFrame.AurasFrame
    if not auras then return end
    for _, key in ipairs(LISTS) do
        if auras[key] then ns.EachChild(auras[key], TintItem) end
    end
end

local function TintAll()
    ns.NP.EachPlate(TintPlate)
end

-- (Clara Combo Points: only the plates whose auras changed, not every plate on screen at each aura event of one; all of
-- them on a client without the lookup by unit)
local changed, unknown = {}, false

local function TintChanged()
    if unknown then
        unknown = false
        wipe(changed)
        return TintAll()
    end
    for unit in pairs(changed) do
        changed[unit] = nil
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        local unitFrame = ok and plate and plate.UnitFrame
        if unitFrame and not ns.IsForbidden(unitFrame) then TintPlate(unitFrame) end
    end
end

ns.EventFrame(RING_EVENTS, function(_, _, unit)
    if (issecretvalue and issecretvalue(unit)) or type(unit) ~= "string" or not unit:find("^nameplate") then return end
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
        unknown = true
    else
        changed[unit] = true
    end
    ns.Sched.NextFrame("namePlates.auraRings", TintChanged)
end)
