local _, ClaraNS = ... -- (Clara Combo Points: ClassicUI Forever built in, QoL.lua)
if not (type(ClaraNS) == "table" and ClaraNS.ClassicUIRuns) then return end
local ns = ClaraNS.ClassicUIPrivate

-- Clara Combo Points: its mail module's recipients window (Modules/Mail/MailUI.lua) in this look while Window frames
-- is on: the window's metal, title strip and rock, its close button, the red buttons. Off, the game's own look stays.

local P = ns.panels

function ns.ClaraMailSkin(kind, frame)
    if not (P and P.active and frame) then return end
    if kind == "window" then
        ns.SkinWindow(frame, { portrait = false })
    elseif kind == "button" then
        ns.SkinRedButton(frame)
    elseif kind == "close" then
        ns.SkinCloseButton(frame)
    end
end
