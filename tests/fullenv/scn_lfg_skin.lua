-- LFG Forever's window dressed by ClassicUI (the version with ClassicUI): the skin runs through, on the real window
local H = ...
local env, ns = H.env, H.ns
env.SlashCmdList.LFGFOREVER("")
local frame = env.LFGForeverFrame
assert(frame, "no window")
local cui = ns.ClassicUIPrivate
assert(cui and cui.ClaraLFGForeverSkin, "no skin")
if cui.panels then cui.panels.active = true end
cui.ClaraLFGForeverSkin(frame)
print("scenario: LFG Forever skinned, filters shown = " .. tostring(frame.filtersShown))
-- the arrow, twice
frame.FiltersToggle:GetScript("OnClick")(frame.FiltersToggle)
frame.FiltersToggle:GetScript("OnClick")(frame.FiltersToggle)
frame.FiltersSearch:GetScript("OnClick")(frame.FiltersSearch)
print("scenario: arrow and Search Again clicked")
