-- The mail recipients arranged by dragging (Modules/Mail) in the harness: the window on the game's own mail frame (if
-- the harness builds it), a name dragged over another place and dropped, with the game's templates: no error. test151
-- checks the rest.
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
local Mail = ns.Mail
check(Mail ~= nil and Mail.DragStart ~= nil, "loaded")
if Mail and rawget(env, "SendMailFrame") then
  for i, n in ipairs({ "Lia Moon", "Lola Elle", "Ana Sun", "Bea Star" }) do Mail.Record(n) end
  local ok, e = pcall(Mail.OnShow)
  check(ok, "the mailbox opened: no error " .. tostring(e or ""))
  if Mail.panel then
    Mail.panel:Show()
    ok, e = pcall(Mail.Changed)
    local cells = {}
    for _, f in pairs(H.frames or {}) do if type(f) == "table" and f.entry and f.GetScript then cells[#cells + 1] = f end end
    print("scenario: names shown " .. #cells .. " (listed " .. #Mail.Sorted() .. ", window shown " .. tostring(Mail.panel:IsShown()) .. ")")
    if #cells >= 2 then
      ok, e = pcall(Mail.DragStart, cells[1])
      check(ok, "a name dragged: no error " .. tostring(e or ""))
      local ghost = rawget(env, "ClaraMailDragGhost")
      if ghost then
        ok, e = pcall(Mail.DragFollow, ghost, 0.05)
        check(ok, "the mouse moved: no error " .. tostring(e or ""))
      end
      ok, e = pcall(Mail.DragStop)
      check(ok, "dropped: no error " .. tostring(e or ""))
    end
  end
else
  print("scenario: the game's mail window not built here")
end
print("scenario: maildrag failures " .. fails)
