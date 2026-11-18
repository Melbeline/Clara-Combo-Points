-- ClassicUI's quest log share (the avec version, Modules/ClassicUI/Quest/QuestLogShare.lua): one press, its macro under
-- the 255 characters the game runs, its last step the map's own close button (the zone button's toggle, three more
-- Opens, left the map open when its quest panel was not as the player keeps it). Other versions: not in them.
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local f = io.open(ADDON_DIR .. "/Modules/ClassicUI/Quest/QuestLogShare.lua", "rb")
if not f then out("  ok   not in this version (ClassicUI's quest log: the avec version only)"); out("0 failure(s)"); return 0 end
local src = f:read("*a"); f:close()

local made, aimed = {}, {}
local function Button(name)
  local b = { name = name, scripts = {} }
  function b:GetName() return self.name end
  function b:SetScript(k, fn) self.scripts[k] = fn end
  function b:IsShown() return self.shown ~= false end
  function b:IsVisible() return true end
  function b:IsEnabled() return true end
  return b
end
local QL = {}
local ns = { L = setmetatable({}, { __index = function(_, k) return k end }), QL = QL }
function ns.ClickProxy(name) local b = Button(name); made[name] = b; return b end
function ns.SetAttributeIf(frame, key, value) if key == "clickbutton" then aimed[frame.name] = value end end
local ClaraNS = { ClassicUIRuns = true, ClassicUIPrivate = ns }
local frame = { share = Button("share") }
function QL.Frame() return frame end
function QL.SelectedID() return 4242 end
local mapShown = false
WorldMapFrame = Button("WorldMapFrame")
function WorldMapFrame:IsShown() return mapShown end
WorldMapFrame.BorderFrame = { CloseButton = Button("WorldMapFrameCloseButton") }
WorldMapFrame.SidePanelToggle = { OpenButton = Button("Open"), CloseButton = Button("Shut") }
QuestMapFrame = Button("QuestMapFrame")
MinimapCluster = { ZoneTextButton = Button("MinimapZoneTextButton") }
InCombatLockdown = function() return false end
IsModifierKeyDown = function() return false end

local chunk = assert(loadstring(src, "@QuestLogShare.lua"))
chunk("ClaraComboPoints", ClaraNS)
local macro = QL.ShareMacro()
check(type(macro) == "string", "a macro for the picked quest")
local lines = {}
for line in (macro or ""):gmatch("[^\n]+") do lines[#lines + 1] = line end
check(#macro <= 255, "under the 255 characters the game runs (" .. #(macro or "") .. ")")
check(#lines == 13, "13 steps, one line each (" .. #lines .. ")")
check(lines[1] == "/click [nomod] FCUIQS1", "first: the map opened (" .. tostring(lines[1]) .. ")")
-- the press: the map now open, the close step aims at the map's own close button
mapShown = true
local closeAim
for name, b in pairs(made) do
  if b.scripts.PreClick and lines[12] and lines[12]:find(name .. "$") then b.scripts.PreClick(b) end
end
local lastName = lines[13] and lines[13]:match("(FCUIQS%d+)$")
check(lastName and aimed[lastName] == WorldMapFrame.BorderFrame.CloseButton, "last: the map's own close button")
out(string.format("\n%d failure(s)", fails))
return fails
