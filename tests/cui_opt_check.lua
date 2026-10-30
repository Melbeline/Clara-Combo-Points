-- ClassicUI's options: under Clara's Interface page (else its own entry); its pages under it
local path = ...
local reg = {}
local function cat(name, parent) return { name = name, parent = parent, GetID = function(self) return self.name end } end
local function setup(withParent)
  reg = {}
  Settings = {
    RegisterAddOnCategory = function(c) reg[#reg + 1] = "addon " .. c.name end,
    RegisterCanvasLayoutCategory = function(f, n) reg[#reg + 1] = "category " .. n; return cat(n) end,
    RegisterCanvasLayoutSubcategory = function(p, f, n) reg[#reg + 1] = "sub " .. n .. " of " .. p.name; return cat(n, p) end,
    OpenToCategory = function(id) reg[#reg + 1] = "open " .. tostring(id) end,
  }
  local init
  local priv = { L = setmetatable({}, { __index = function(_, k) return k end }), options = { TITLE = "ClassicUI Forever" },
    OptionsCanvas = function(page) return {} end, OptionsPageNames = function() return { "Bars", "Frames" } end,
    RegisterModule = function(name, m) if name == "options" then init = m.init end end, Print = function() end }
  local clara = { ClassicUIRuns = true, ClassicUIPrivate = priv }
  if withParent then function clara:QolCategory(key) return key == "classicui" and cat("Interface") or nil end end
  SlashCmdList = {}
  local fn = assert(loadfile(path))
  fn("ClaraComboPoints", clara)
  init()
  priv.OpenBlizzardSettings()
  return table.concat(reg, "; ")
end
local a = setup(true)
print(a)
assert(a == "sub ClassicUI Forever of Interface; sub Bars of ClassicUI Forever; sub Frames of ClassicUI Forever; open ClassicUI Forever", "under Interface")
local b = setup(false)
print(b)
assert(b:find("^category ClassicUI Forever; addon ClassicUI Forever"), "alone: its own entry")
print("OK")
