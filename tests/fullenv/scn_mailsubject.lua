-- The mail's subject (MailSubject.lua) on the game's own mail (Blizzard_MailFrame of 1.60.1): its SendMailFrame_Update,
-- C.O.D. off, leaves the subject empty (the bug); Clara's update after it names the mail; the items taken off, it goes;
-- C.O.D. on, the game names it itself and Clara sees no fix. (The harness's hooksecurefunc does nothing: Clara's update
-- is called after the game's, as the hook would.)
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
check(ns.MailSubjectUpdate ~= nil, "loaded")
local update, box = rawget(env, "SendMailFrame_Update"), rawget(env, "SendMailSubjectEditBox")
print("scenario: the game's mail here " .. tostring(update ~= nil and box ~= nil))
if update and box then
  local mail, cod = {}, false
  rawset(env, "HasSendMailItem", function(i) return mail[i] ~= nil end)
  rawset(env, "GetSendMailItem", function(i) local m = mail[i]; if m then return m[1], 2589, 132889, m[2], 1 end end)
  local C_Mail = rawget(env, "C_Mail") or {}
  rawset(env, "C_Mail", C_Mail)
  local realCod = C_Mail.IsCODEnabled
  C_Mail.IsCODEnabled = function() return cod end
  local function Both()
    local ok, e = pcall(update)
    if not ok then print("scenario: the game's update " .. tostring(e)) end
    local ok2, e2 = pcall(ns.MailSubjectUpdate)
    check(ok2, "Clara's update: no error " .. tostring(e2 or ""))
  end
  box:SetText("")
  mail[1] = { "Linen Cloth", 1 }
  local ok, e = pcall(update)
  print("scenario: the game's update alone " .. tostring(ok) .. " " .. tostring(e or ""))
  check(box:GetText() == "", "the game's own update, C.O.D. off: the subject left empty (the bug) '" .. tostring(box:GetText()) .. "'")
  pcall(ns.MailSubjectUpdate)
  check(box:GetText() == "Linen Cloth", "Clara's after it: named '" .. tostring(box:GetText()) .. "'")
  mail[2] = { "Wool Cloth", 20 }
  mail[1] = nil
  Both()
  check(box:GetText() == "Wool Cloth (20)", "the first taken off: the next one's '" .. tostring(box:GetText()) .. "'")
  mail[2] = nil
  Both()
  check(box:GetText() == "", "all taken off: gone")
  cod = true
  mail[1] = { "Silk Cloth", 3 }
  Both()
  check(box:GetText() == "Silk Cloth (3)", "C.O.D. on: the game's own name '" .. tostring(box:GetText()) .. "'")
  check(not (ns.sv and ns.sv.mailSubjectFixed), "C.O.D. on: not taken for the fix")
  mail[1] = nil
  Both()
  check(box:GetText() == "", "C.O.D. on, all taken off: gone")
  C_Mail.IsCODEnabled = realCod
end
print("scenario: mailsubject failures " .. fails)
