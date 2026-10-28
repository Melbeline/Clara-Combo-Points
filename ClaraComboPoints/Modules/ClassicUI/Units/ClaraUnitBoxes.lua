local _, ClaraNS = ... -- (Clara Combo Points: ClassicUI Forever built in, QoL.lua)
if not (type(ClaraNS) == "table" and ClaraNS.ClassicUIRuns) then return end
local ns = ClaraNS.ClassicUIPrivate

-- (Clara Combo Points) Clara's boxes over the classic target and focus frames (its UnitBoxes.lua: the attack speed,
-- the distance) in this art: the threat percent's border, drawn longer for a longer box (the ends as drawn, the
-- straight middle stretched). Clara places them with the threat percent's own box (ThreatNumber.lua) over the name
-- box, and fills them; while one shows, the name steps up for it as for the threat percent.

local UF = ns.UF
local BOX_W, BOX_H, FILL_W, FILL_H, FILL_Y, TEXT_Y = 49, 18, 37, 14, -3, -4
local END_W, TEX_W, TEX_BOTTOM = 9, 64, 0.5625 -- (the border's file: its ends 9 wide)
local FRAMES = { target = "TargetFrame", focus = "FocusFrame" }
local spots, shown = {}, {}

local function Piece(box, left, right)
    local piece = box:CreateTexture(nil, "ARTWORK")
    ns.SetTex(piece, "threatBorder")
    piece:SetTexCoord(left / TEX_W, right / TEX_W, 0, TEX_BOTTOM)
    return piece
end

local function Build(frame, width)
    local box = ns.NewFrame("Frame", nil, frame)
    box:SetSize(width, BOX_H)
    box.fill = box:CreateTexture(nil, "BACKGROUND")
    ns.SetTex(box.fill, "statusBar")
    box.fill:SetSize(width - (BOX_W - FILL_W), FILL_H)
    box.fill:SetPoint("TOP", box, "TOP", 0, FILL_Y)
    if width == BOX_W then
        box.border = Piece(box, 0, BOX_W)
        box.border:SetAllPoints(box)
    else
        local left, right = Piece(box, 0, END_W), Piece(box, BOX_W - END_W, BOX_W)
        left:SetSize(END_W, BOX_H)
        left:SetPoint("TOPLEFT", box, "TOPLEFT")
        right:SetSize(END_W, BOX_H)
        right:SetPoint("TOPRIGHT", box, "TOPRIGHT")
        box.border = Piece(box, END_W, BOX_W - END_W)
        box.border:SetPoint("TOPLEFT", left, "TOPRIGHT")
        box.border:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    end
    box.text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    box.text:SetPoint("TOP", box, "TOP", 0, TEXT_Y)
    box:Hide()
    return box
end

-- The unit's spot while its frame is classic (Clara's own boxes otherwise): where the name box is, how wide, the
-- threat percent's box and whether it is on, a box maker, and the name told.
function ns.ClaraClassicSpot(unit)
    local name = FRAMES[unit]
    local frame = name and _G[name]
    if not (frame and UF and UF.active and UF.On and UF.On(unit) and UF.THREAT_BOX_X) then return nil end
    local spot = spots[unit]
    if not spot then
        spot = { anchor = frame, x = UF.THREAT_BOX_X, y = UF.THREAT_BOX_Y, width = UF.BAR_W or 119, boxes = {} }
        function spot.Make(width) return Build(frame, width) end
        function spot.Shown(any)
            if shown[unit] == any then return end
            shown[unit] = any
            if UF.PlaceTargetName then UF.PlaceTargetName(unit) end
        end
        spots[unit] = spot
    end
    spot.threat = UF.ThreatBox and UF.ThreatBox(unit)
    spot.threatOn = ns.db == nil or ns.db.threatNumber ~= false
    return spot
end

-- The name over a thick bar steps up while any box shows (UnitFrameCore.lua's NameSpot).
local threatShown = UF and UF.ThreatShown
if UF then
    function UF.ThreatShown(unit) return shown[unit] == true or (threatShown ~= nil and threatShown(unit)) end
end
