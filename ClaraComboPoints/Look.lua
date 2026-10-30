-- Clara Combo Points - one look for Clara's windows and its modules' (the options window, the dialogs of
-- BuyEmAll, DoesItDie, Leatrix Plus, DynamicCam...). With the game's interface: the game's own (its window
-- metal, its dialog border, its buttons). With ClassicUI, while it dresses the game's
-- windows: ClassicUI dresses ours too, as it dresses the game's (the old metal and stone, Classic's dialog
-- box, the red buttons and old boxes, in its theme). The Light version, without ClassicUI, has Classic's
-- dialog box drawn from the game's own files. Each window is dressed as it first shows (ClassicUI's
-- state is known by then); nothing runs after that.

local ADDON, ns = ...

local OLD_LOOK = false -- (the Light version: true, Classic's look without ClassicUI)

local OLD_EDGE = { edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileEdge = true,
  tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } }
local FILL = "Interface\\DialogFrame\\UI-DialogBox-Background"
local PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge",
  "BottomEdge", "LeftEdge", "RightEdge", "Center" }

-- ClassicUI, while it dresses the game's windows
local function ClassicUI()
  local cui = ns.ClassicUIRuns and ns.ClassicUIPrivate
  if cui and cui.panels and cui.panels.active then return cui end
end

-- Classic's look: ClassicUI's, or the Light version's
function ns:ClassicLook() return OLD_LOOK or ClassicUI() ~= nil end

-- (ClassicUI's own dressing: never let it break the window it dresses)
local function Try(fn, ...)
  if type(fn) == "function" then pcall(fn, ...) end
end

-- Once, as the frame first shows (now, if it shows already). Told by a child of its own, whose OnShow runs as
-- the frame shows: the frame's own OnShow can be set again after this, by the window's own code.
local function AtFirstShow(frame, fn)
  if frame:IsShown() and IsLoggedIn() then return fn() end
  local watcher = CreateFrame("Frame", nil, frame)
  watcher:SetScript("OnShow", function(self)
    self:SetScript("OnShow", nil)
    fn()
  end)
end

-- Classic's dialog edge over a frame's own
local function OldEdge(frame)
  local edge = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  edge:SetAllPoints()
  edge:SetBackdrop(OLD_EDGE)
  return edge
end

-- A button of ours, red and old with ClassicUI
function ns:DressButton(button)
  local cui = ClassicUI()
  if cui and button then Try(cui.SkinRedButton, button) end
end

-- A check box of ours, Classic's with ClassicUI
function ns:DressCheck(check)
  local cui = ClassicUI()
  if cui and check then Try(cui.SkinCheckbox, check) end
end

-- A dialog: the game's dialog border (Classic's old box: with ClassicUI, or the Light version) round the frame,
-- over its edges. opts: fill (the dialog's own fill under it, for a frame without one; dark: the darker one),
-- close (its close button), buttons (its buttons).
function ns:DressDialog(frame, opts)
  opts = opts or {}
  if frame.SetBackdrop then frame:SetBackdrop(nil) end
  AtFirstShow(frame, function()
    local cui = ClassicUI()
    if opts.fill then
      local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
      fill:SetTexture(opts.dark and FILL .. "-Dark" or FILL, "REPEAT", "REPEAT")
      fill:SetHorizTile(true)
      fill:SetVertTile(true)
      fill:SetPoint("TOPLEFT", 8, -8)
      fill:SetPoint("BOTTOMRIGHT", -8, 8)
    end
    local edge
    if cui and cui.OwnBackdropFrame and cui.Backdrop and cui.DialogEdge then
      pcall(function()
        edge = cui.OwnBackdropFrame(frame)
        edge:SetAllPoints()
        cui.Backdrop(edge, cui.DialogEdge(32))
      end)
    end
    if not edge and (cui or OLD_LOOK) then edge = OldEdge(frame) end
    if not edge then
      edge = CreateFrame("Frame", nil, frame, "NineSlicePanelTemplate")
      edge:SetAllPoints()
      NineSliceUtil.ApplyLayoutByName(edge, "Dialog")
    end
    frame.claraEdge = edge
    if opts.close then
      opts.close:SetFrameLevel(edge:GetFrameLevel() + 1)
      if cui then Try(cui.SkinCloseButton, opts.close, true) end
    end
    for _, button in ipairs(opts.buttons or {}) do self:DressButton(button) end
  end)
end

-- A window of the game's kinds (a portrait frame, a button frame: its metal in a NineSlice): ClassicUI's old
-- window with ClassicUI (portrait: false for one without; tabs: its tabs along its top); the Light version:
-- Classic's dialog edge instead of the metal.
function ns:DressWindow(frame, opts)
  opts = opts or {}
  AtFirstShow(frame, function()
    local cui = ClassicUI()
    if cui then
      Try(cui.SkinWindow, frame, { portrait = opts.portrait, scrollBars = false })
      for _, tab in ipairs(opts.tabs or {}) do Try(cui.SkinTopTab, tab) end
    elseif OLD_LOOK and frame.NineSlice then
      for _, key in ipairs(PIECES) do
        if frame.NineSlice[key] then frame.NineSlice[key]:SetAlpha(0) end
      end
      frame.claraEdge = OldEdge(frame)
    end
  end)
end
