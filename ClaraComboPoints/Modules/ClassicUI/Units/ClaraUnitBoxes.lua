local _, ClaraNS = ... -- (Clara Combo Points: ClassicUI Forever built in, QoL.lua)
if not (type(ClaraNS) == "table" and ClaraNS.ClassicUIRuns) then return end
local ns = ClaraNS.ClassicUIPrivate

-- (Clara Combo Points) The distance box of Clara's UnitBoxes.lua on the classic target and focus frames: beside the
-- threat percent (ThreatNumber.lua), in its art, its border drawn longer (the ends as drawn, the straight middle
-- stretched). With the distance on, the two side by side over the name box (the threat percent alone stays in its
-- place); while it shows, the name steps up for it as for the threat percent. Clara reads, colors and shows it.

local UF = ns.UF
local BOX_W, BOX_H, FILL_H, FILL_Y, TEXT_Y = 49, 18, 14, -3, -4
local RANGE_W, GAP = 66, 6
local END_W, TEX_W, TEX_BOTTOM = 9, 64, 0.5625 -- (the border's file: its ends 9 wide)
local FRAMES = { target = "TargetFrame", focus = "FocusFrame" }
local boxes, shown, placed = {}, {}, setmetatable({}, { __mode = "k" })

local function Piece(box, left, right)
    local piece = box:CreateTexture(nil, "ARTWORK")
    ns.SetTex(piece, "threatBorder")
    piece:SetTexCoord(left / TEX_W, right / TEX_W, 0, TEX_BOTTOM)
    return piece
end

local function Build(frame)
    local box = ns.NewFrame("Frame", nil, frame)
    box:SetSize(RANGE_W, BOX_H)
    box:SetPoint("BOTTOM", frame, "TOP", UF.THREAT_BOX_X + (BOX_W + GAP) / 2, UF.THREAT_BOX_Y)
    box.fill = box:CreateTexture(nil, "BACKGROUND")
    ns.SetTex(box.fill, "statusBar")
    box.fill:SetSize(RANGE_W - 12, FILL_H)
    box.fill:SetPoint("TOP", box, "TOP", 0, FILL_Y)
    local left, right = Piece(box, 0, END_W), Piece(box, BOX_W - END_W, BOX_W)
    left:SetSize(END_W, BOX_H)
    left:SetPoint("TOPLEFT", box, "TOPLEFT")
    right:SetSize(END_W, BOX_H)
    right:SetPoint("TOPRIGHT", box, "TOPRIGHT")
    box.border = Piece(box, END_W, BOX_W - END_W)
    box.border:SetPoint("TOPLEFT", left, "TOPRIGHT")
    box.border:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    box.text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    box.text:SetPoint("TOP", box, "TOP", 0, TEXT_Y)
    box:Hide()
    return box
end

-- The unit's box while its frame is classic (Clara's own boxes otherwise); pair: the distance on, the threat percent
-- placed beside it.
function ns.ClaraRangeBox(unit, pair)
    local name = FRAMES[unit]
    local frame = name and _G[name]
    if not (frame and UF and UF.active and UF.On and UF.On(unit) and UF.THREAT_BOX_X) then return nil end
    local box = boxes[unit]
    if not box then
        box = Build(frame)
        boxes[unit] = box
    end
    pair = pair and true or false
    local threat = UF.ThreatBox and UF.ThreatBox(unit)
    if threat and placed[threat] ~= pair then
        placed[threat] = pair
        threat:SetPoint("BOTTOM", frame, "TOP", UF.THREAT_BOX_X - (pair and (GAP + RANGE_W) / 2 or 0), UF.THREAT_BOX_Y)
    end
    return box
end

-- The name over a thick bar steps up while either box shows (UnitFrameCore.lua's NameSpot).
local threatShown = UF and UF.ThreatShown
if UF then
    function UF.ThreatShown(unit) return shown[unit] == true or (threatShown ~= nil and threatShown(unit)) end
end

function ns.ClaraRangeShown(unit, on)
    if shown[unit] == on then return end
    shown[unit] = on
    if UF and UF.PlaceTargetName then UF.PlaceTargetName(unit) end
end
