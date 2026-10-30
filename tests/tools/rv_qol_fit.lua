-- rv: does each module's page fit in the Improvements view at the window's smallest size?
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { buyemall = false, leatrix = false, nodesight = false, wst = false } }
local ns = {}
S.class = "ROGUE"; S.locale = os.getenv("RV_LOCALE") or "deDE"
M.LoadAddon(ADDON_DIR, ns)
local function sw(label) return { label = label, get = function() return true end, set = function() end } end
ns:SetQolSwitches("wst", { sw("WST_SW_HUNTER"), sw("WST_SW_HUNTERS_ONLY"), sw("WST_SW_PLAYER"), sw("WST_SW_TARGET"), sw("WST_SW_LOCKED") })
ns:SetQolSwitches("nodesight", { sw("NS_SW_SCAN"), sw("NS_SW_SYMBOLS"), sw("NS_SW_ARROW"), sw("NS_SW_HERBS"), sw("NS_SW_ORE") })
ns:SetQolSwitches("buyemall", { sw("BEA_SW_CONFIRM") })
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
M.Fire("PLAYER_ENTERING_WORLD", true, false)
ns.QolState = function() return "on" end -- as when the modules run
ns.QolEnabled = function() return true end
ns.sv.window.w, ns.sv.window.h = ns.MIN_WINDOW_W, ns.MIN_WINDOW_H
SlashCmdList.CLARACOMBOPOINTS("")
local panel = ClaraComboPointsOptions
panel.qolTab:Click()
local pl, pb, pw, ph = M.Rect(panel)
local vl, vb, vw, vh = M.Rect(panel.qolView)
out(("window %dx%d  view l=%.0f b=%.0f w=%.0f h=%.0f"):format(pw, ph, vl - pl, vb - pb, vw, vh))
for _, key in ipairs({ "buyemall", "leatrix", "nodesight", "wst" }) do
  -- click its line
  for _, f in ipairs(M.frames) do
    if f._kind == "Button" and f.name and f.name._text == ns.L["QOL_NAV_" .. key:upper()] and f:IsVisible() then f:Click() break end
  end
  -- lowest visible region inside the view, and rightmost
  local low, right = math.huge, -math.huge
  local lowWhat, rightWhat
  for _, r in ipairs(M.regions) do
    if r.IsVisible and r:IsVisible() then
      local p = r._parent
      local inside = false
      while p do if p == panel.qolView then inside = true break end p = p._parent end
      if inside and r._points and #r._points > 0 then
        local l, b, w, h = M.Rect(r)
        if h > 0 and b < low then low = b; lowWhat = tostring(r._text or r._kind) end
        if l + w > right then right = l + w; rightWhat = tostring(r._text or r._kind) end
      end
    end
  end
  for _, f in ipairs(M.frames) do
    if f:IsVisible() then
      local p = f._parent
      local inside = false
      while p do if p == panel.qolView then inside = true break end p = p._parent end
      local anchoredBottom = false
      for _, pt in ipairs(f._points or {}) do if pt[1]:find("BOTTOM") then anchoredBottom = true end end
      if inside and f._points and #f._points > 0 and not anchoredBottom then
        local l, b, w, h = M.Rect(f)
        if h > 0 and b < low then low = b; lowWhat = f._kind end
        if l + w > right then right = l + w; rightWhat = f._kind end
      end
    end
  end
  out("  lowest: " .. tostring(lowWhat):sub(1,40) .. "  rightmost: " .. tostring(rightWhat):sub(1,40))
  out(("%s: lowest %.0f (view bottom %.0f, window bottom %.0f); rightmost %.0f (window right %.0f)"):format(key, low, vb, pb, right, pl + pw))
  check(low >= vb - 1, key .. ": fits above the footer")
  check(right <= pl + pw, key .. ": fits inside the window's width")
end
out(fails .. " failure(s)")
