-- The sniper's tab built from its XML template on the game's templates, every control clicked
local H = ...
local env = H.env
local f = env.CreateFrame("Frame", "ClaraSniperFrame", env.UIParent, "ClaraSniperTabFrameTemplate")
assert(f and f.Go and f.windows and #f.windows == 9, "the tab not built from its template")
f:Show()
f.Go:GetScript("OnClick")(f.Go)
for _, b in ipairs(f.windows) do b:GetScript("OnClick")(b) end
f.Mode:GetScript("OnClick")(f.Mode)
f.Slider:GetScript("OnValueChanged")(f.Slider, 55)
f.Box:SetText("12"); f.Box:GetScript("OnEnterPressed")(f.Box)
f.Sound:GetScript("OnClick")(f.Sound)
f:GetScript("OnMouseWheel")(f, -1)
f.Go:GetScript("OnClick")(f.Go)
print("scenario: sniper tab built and clicked")
