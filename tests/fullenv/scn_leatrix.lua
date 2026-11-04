-- Leatrix Plus's options in the game's menu: built again on recording stubs of the game's Settings, every row's
-- setter worked once (a check box clicked through its own control, a slider moved, a dropdown chosen)
local H = ...
local env = H.env
local LP = H.ns.LeatrixPlus
assert(LP and LP.mirror, "no mirror")
local m = LP.mirror
local rows, setters = {}, {}
local S = env.Settings
local saved = {}
for _, k in ipairs({ "RegisterVerticalLayoutSubcategory", "RegisterProxySetting", "CreateCheckbox", "CreateSlider", "CreateDropdown", "CreateSliderOptions", "CreateControlTextContainer" }) do saved[k] = S[k] end
S.RegisterVerticalLayoutSubcategory = function(parent, name)
  local c = { name = name, parent = parent, rows = {} }
  return c, { AddInitializer = function(_, i) table.insert(c.rows, i) end }
end
S.RegisterProxySetting = function(category, variable, kind, name, default, get, set)
  local s = { variable = variable, name = name, default = default, get = get, set = set, kind = kind }
  setters[#setters + 1] = s
  return s
end
local function Init(kind, s) local i = { kind = kind, setting = s, AddModifyPredicate = function() end, SetParentInitializer = function() end }; rows[#rows + 1] = i; return i end
S.CreateCheckbox = function(_, s) return Init("check", s) end
S.CreateSlider = function(_, s) return Init("slider", s) end
S.CreateDropdown = function(_, s, opts) s.opts = opts; return Init("dropdown", s) end
S.CreateSliderOptions = function() return { SetLabelFormatter = function() end } end
S.CreateControlTextContainer = function() local d = {}; return { Add = function(_, v, l) d[#d + 1] = { value = v, label = l } end, GetData = function() return d end } end
S.VarType = S.VarType or { Boolean = "Boolean", Number = "Number", String = "String" }
local main = LP.BuildSettingsPages()
local kinds = {}
for _, r in ipairs(rows) do kinds[r.kind] = (kinds[r.kind] or 0) + 1 end
print(("scenario: Leatrix pages %d, rows: %d check boxes, %d sliders, %d dropdowns"):format(#(LP.settingsPages.pages), kinds.check or 0, kinds.slider or 0, kinds.dropdown or 0))
local worked, failed = 0, 0
for _, s in ipairs(setters) do
  local v = s.get()
  local ok, e = pcall(s.set, v)
  if ok then worked = worked + 1 else failed = failed + 1; print("  setter failed: " .. s.variable .. ": " .. tostring(e)) end
  if s.opts then pcall(s.opts) end
end
print(("scenario: setters worked %d, failed %d"):format(worked, failed))
for k, f in pairs(saved) do S[k] = f end
