local _, ClaraNS = ... -- (Clara Combo Points: ClassicUI Forever built in, QoL.lua)
if not (type(ClaraNS) == "table" and ClaraNS.ClassicUIRuns) then return end
local ns = ClaraNS.ClassicUIPrivate

-- Clara Combo Points: LFG Forever's window (Modules/LFGForever/window.lua, built in) in this look while Window
-- frames is on: the old window's metal, title strip, rock and close button round it; the marble of the old lists in
-- its two columns (the list, the filters and whispers), a shade darker as in 1.x; the red buttons; the old tabs over
-- the filters. Its side tabs and its arrows stay the game's. Off, the game's own look stays.
-- Called once, as the window first shows (window.lua's DressWindow, in a pcall).

local P = ns.panels
local MARBLE = { coords = { 0, 1, 0, 1 } }

-- An inset column: its thin border gone, the old marble under it
local function Marble(inset)
    if not inset then return end
    if inset.NineSlice then ns.FadeTextures(inset.NineSlice) end
    if inset.Bg and inset.Bg.SetAlpha then inset.Bg:SetAlpha(0) end
    local floor = ns.TileTex(ns.OwnTexture(inset, "insetFloor", "BACKGROUND", -1), "marbleBg", MARBLE)
    floor:ClearAllPoints()
    floor:SetAllPoints(inset)
    floor:Show()
    local veil = ns.OwnTexture(inset, "insetVeil", "BACKGROUND", 0)
    veil:SetColorTexture(0, 0, 0, 1 - ns.PANE_SHADE)
    veil:SetAllPoints(floor)
    veil:Show()
end

-- Every red-button-shaped button under a frame (the game's UIPanelButtonTemplate: its Left, Middle and Right)
local function RedButtons(frame, depth)
    if not frame or (depth or 0) > 6 or not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.IsObjectType and child:IsObjectType("Button") and child.Left and child.Middle and child.Right
            and child.GetText and not child.isTabOnTop then
            ns.SkinRedButton(child)
        end
        RedButtons(child, (depth or 0) + 1)
    end
end

function ns.ClaraLFGForeverSkin(frame)
    if not (P and P.active and frame and frame.Content) then return end
    local content = frame.Content
    ns.SkinWindow(content, {})
    Marble(content.ListPanel)
    Marble(content.FilterPanel)
    RedButtons(content)
    local tabs = content.FilterPanel and content.FilterPanel.TabSystem
    if tabs and tabs.GetChildren then
        for _, tab in ipairs({ tabs:GetChildren() }) do ns.SkinTopTab(tab, nil, nil, true) end
    end
end
