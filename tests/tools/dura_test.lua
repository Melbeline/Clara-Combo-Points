-- Leatrix Plus's durability button in Clara (Modules/LeatrixPlus/Leatrix_Plus.lua): its D, its place (lupa, Lua 5.1).
local ADDON = ...
local function readfile(p) local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return s end
local fails = 0
local function check(c, m) print((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local src = readfile(ADDON .. "/Modules/LeatrixPlus/Leatrix_Plus.lua")
local block = src:match("(\t\t\t%-%- %(Clara Combo Points: a gold D.-\n\t\t\tend%)\n)")
check(block ~= nil, "the block there")
local function Region()
  local r = { points = {} }
  function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
  function r:ClearAllPoints() self.points = {} end
  function r:SetSize(w, h) self.w, self.h = w, h end
  function r:GetSize() return self.w, self.h end
  function r:SetColorTexture(...) self.color = { ... } end
  function r:SetText(t) self.text = t end
  function r:IsShown() return self.shown end
  return r
end
local cButton = Region()
cButton.w, cButton.h = 28, 28
local made = {}
function cButton:CreateTexture(_, layer, _, sub) local t = Region() t.layer, t.sub = layer, sub made.cover = t return t end
function cButton:CreateFontString(_, layer, font) local t = Region() t.layer, t.font = layer, font made.letter = t return t end
function cButton:HookScript(k, fn) self[k] = fn end
local env = { cButton = cButton, CharacterFrameLeftPaneHost = Region() }
env._G = env
local fn = assert(loadstring(block))
setfenv(fn, env)
fn()
check(made.letter and made.letter.text == "D" and made.letter.layer == "OVERLAY" and made.letter.font == "GameFontNormal", "a gold D over it")
check(made.cover and made.cover.layer == "ARTWORK" and made.cover.sub == 7 and made.cover.color[4] == 1, "its arrow covered (opaque, over the button's art)")
local tl, br = made.cover.points[1], made.cover.points[2]
check(tl[1] == "TOPLEFT" and tl[2] == 4 and tl[3] == -6 and br[1] == "BOTTOMRIGHT" and br[2] == -5 and br[3] == 6,
  "covering the arrow's square (8 to 16 across, 9 to 19 down on 28) inside the rim")
-- no ClassicUI: Leatrix's own place
cButton:OnShow()
local p = cButton.points[1]
check(p and p[1] == "BOTTOMRIGHT" and p[2] == env.CharacterFrameLeftPaneHost and p[4] == -6 and p[5] == 6 and cButton.w == 28,
  "without ClassicUI's arrow: Leatrix's own place and size")
-- ClassicUI's arrow shown: left of it, its size
local arrow = Region()
arrow.w, arrow.h, arrow.shown = 26, 26, true
env.ForeverClassicUIEquipmentToggle = arrow
cButton:OnShow()
p = cButton.points[1]
check(p and p[1] == "RIGHT" and p[2] == arrow and p[3] == "LEFT" and p[4] == 2 and p[5] == 0 and cButton.w == 26 and cButton.h == 26,
  "with ClassicUI's arrow: by it (its right edge 2 into the arrow's frame: the rims 8 px apart, as from the ammo slot), its size")
arrow.shown = false
cButton:OnShow()
p = cButton.points[1]
check(p and p[1] == "BOTTOMRIGHT" and cButton.w == 28, "its arrow hidden (the pet view): back to its own place")
print("")
print(fails .. " failure(s)")
