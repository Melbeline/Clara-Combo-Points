-- The sync between the WoW accounts (Modules/Sync): the other accounts' files merged at login (the newer
-- entry wins, an entry removed stays removed, the lists from before the sync put together), the key
-- shared (the smaller kept), the hidden channel, a character met in a group trusted once the player says
-- so, the entries exchanged live (signed, in parts), each change sent as it comes
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false, tullarange = false, names = false,
  tooltipanchor = false } }
MailFrame = CreateFrame("Frame", "MailFrame", UIParent)
SendMailFrame = CreateFrame("Frame", "SendMailFrame", MailFrame)
SendMailNameEditBox = CreateFrame("EditBox", "SendMailNameEditBox", SendMailFrame)
function SendMail() end
function UnitLevel() return 60 end
local now = 5000
time = function() return now end
S.channels = { "General", "Trade" }
-- this account's lists, from before the sync (no times yet)
ClaraMailDB = { recipients = {
  dave = { name = "Dave", last = 10, cats = { friend = true } },
  carol = { name = "Carol", last = 20, cats = {} },
  erin = { name = "Erin", last = 30, cats = {} } },
  st = { r = { carol = 1500, erin = 3000 } } }
-- another account's file, put in this one's by the script
ClaraSyncIncoming = { ["WANJ"] = {
  ClaraMailDB = { recipients = {
      dave = { name = "Dave", last = 40, cats = { bankalt = true } },
      frank = { name = "Frank", last = 50, cats = { mainalt = true } },
      erin = { name = "Erin", last = 60, cats = { customer = true } } },
    own = { frank = true },
    st = { r = { carol = 2000, frank = 2500, erin = 2900 }, o = { frank = 2500 } } },
  ClaraCraftDB = { chars = { ["Frank-Forever"] = { bags = { [106] = 7 }, bank = {}, mail = {}, at = 2600, class = "MAGE" } },
    sends = { ["Frank-Forever-2700-1"] = { to = "Lola-Forever", at = 2700, items = { [106] = 3 } } } },
  ClaraSyncDB = { key = "0000aaaa0000aaaa", trusted = { ["Frank-Forever"] = true } },
} }

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
if not ns.Sync then out("(no sync between accounts in this version)"); out(""); out("0 failure(s)"); return end
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
local function Run() while M.timers and #M.timers > 0 do M.RunTimer() end end
for _ = 1, 20 do if ClaraSyncDB then break end M.RunTimer() end -- (the sync starts the next frame, after the others)
M.Fire("PLAYER_ENTERING_WORLD")
local Sync, Mail, Craft = ns.Sync, ns.Mail, ns.Craft
local mdb = ClaraMailDB

out("== the other accounts' files, at login")
check(Sync and ClaraSyncIncoming == nil, "taken in, then dropped from this account's file")
check(mdb.recipients.frank and mdb.recipients.frank.cats.mainalt and mdb.own.frank, "a character only the other account knew: here now")
check(mdb.recipients.carol == nil, "removed there after it changed here: removed here too")
check(mdb.recipients.erin and mdb.recipients.erin.last == 30 and not mdb.recipients.erin.cats.customer, "changed here later: this account's kept")
check(mdb.recipients.dave.cats.friend and mdb.recipients.dave.cats.bankalt and mdb.recipients.dave.last == 40,
  "from before the sync on both sides: the two put together")
check(Craft.db.chars["Frank-Forever"] and Craft.db.chars["Frank-Forever"].bags[106] == 7, "the other account's stock")
check(Craft.Mailed("Lola-Forever", 106) == 3, "and the mail it sent here")
check(ClaraSyncDB.key == "0000aaaa0000aaaa" and ClaraSyncDB.trusted["Frank-Forever"], "the smaller key kept, its trusted characters too")

out("== the channel")
Run()
local channel = "ClaraSync" .. ("%06x"):format(Sync.Hash("0000aaaa0000aaaa"))
local function Joined(name) for _, n in ipairs(M.joined) do if n == name then return true end end return false end
check(Joined(channel), "the hidden channel joined, after the game's own")
table.insert(S.channels, channel)
M.Fire("PLAYER_ENTERING_WORLD"); Run()
check(Sync.Status().channel, "in it")

-- what was sent: the parts put together, read back
local function Sent(from)
  local whole, msgs = {}, {}
  for i = from or 1, #M.addonSent do
    local p = M.addonSent[i]
    if p[1] == "ClaraSync" then
      local id, k, n, body = p[2]:match("^(%w%w%d)(%d+)/(%d+):(.*)$")
      local slot = p[3] .. id
      whole[slot] = whole[slot] or {}
      whole[slot][tonumber(k)] = body
      if #whole[slot] == tonumber(n) then
        local text = table.concat(whole[slot])
        local msg = ns.Deserialize(ns.Decode64(text:sub(7)))
        msgs[#msgs + 1] = { tag = text:sub(1, 6), msg = msg, chatType = p[3], target = p[4], text = text }
        whole[slot] = nil
      end
    end
  end
  return msgs
end
-- a message as another client sends it
local function Deliver(msg, sender, chatType, key)
  local payload = ns.Encode64(ns.Serialize(msg))
  local tag = key == false and "------" or ("%06x"):format(Sync.Hash((key or ClaraSyncDB.key) .. payload))
  local text = tag .. payload
  local n = math.ceil(#text / 100)
  for i = 1, n do Sync.OnAddon("ClaraSync", "ab1" .. i .. "/" .. n .. ":" .. text:sub((i - 1) * 100 + 1, i * 100), chatType, sender) end
end

out("== each change as it comes")
local mark = #M.addonSent + 1
Mail.SetCategory("Gus", "friend", true)
check(mdb.st.r.gus == now, "a change here: its time kept")
Run()
local msgs = Sent(mark)
local got
for _, m in ipairs(msgs) do if m.msg.t == "B" and m.msg.k == "r" then got = m end end
check(got and got.chatType == "CHANNEL" and got.msg.e[1][1] == "gus" and got.msg.e[1][3].c.friend, "sent on the channel at once, signed")
check(got and got.tag == ("%06x"):format(Sync.Hash(ClaraSyncDB.key .. got.text:sub(7))), "its signature: the shared key's")

out("== another of the player's characters, live")
now = 6000
Deliver({ t = "B", k = "r", e = { { "gus", 5900, { n = "Gus", l = 99, c = { bankalt = true } } }, { "hal", 5800, { n = "Hal", l = 1, c = {} } } } },
  "Frank", "CHANNEL")
check(mdb.recipients.gus.cats.bankalt and not mdb.recipients.gus.cats.friend and mdb.recipients.hal, "its newer entries taken")
Deliver({ t = "B", k = "r", e = { { "gus", 100, false } } }, "Frank", "CHANNEL")
check(mdb.recipients.gus, "an older removal: ignored")
Deliver({ t = "B", k = "r", e = { { "hal", 5950, false } } }, "Frank", "CHANNEL")
check(mdb.recipients.hal == nil and mdb.st.r.hal == 5950, "a newer removal: removed, its time kept")
Deliver({ t = "B", k = "r", e = { { "ivy", 5950, { n = "Ivy", l = 1, c = {} } } } }, "Mallory", "CHANNEL", "wrongkey12345678")
check(mdb.recipients.ivy == nil, "signed with another key: nothing taken")
S.inCombat = false

out("== meeting: what the other lacks")
mark = #M.addonSent + 1
local digests = Sync.Digests()
digests.r = { 0, 0, 0, 0, 0, 0, 0, 0 }
Deliver({ t = "H", d = digests }, "Frank", "CHANNEL")
Run()
msgs = Sent(mark)
local buckets, hello = 0, false
for _, m in ipairs(msgs) do
  if m.msg.t == "B" and m.msg.k == "r" then buckets = buckets + 1 end
  if m.msg.t == "H" then hello = true end
end
check(buckets > 0 and buckets <= 8, "its digests differ: the differing buckets sent (" .. buckets .. ")")
check(hello, "and a hello back, for what it has that this one lacks")
mark = #M.addonSent + 1
Deliver({ t = "H", d = Sync.Digests() }, "Frank", "CHANNEL")
Run()
buckets = 0
for _, m in ipairs(Sent(mark)) do if m.msg.t == "B" then buckets = buckets + 1 end end
check(buckets == 0, "the same digests: nothing sent")

out("== a character met in a group")
S.group = "party"
Deliver({ t = "H", d = {} }, "Zed", "PARTY", "zedkey0000000000")
local popup = StaticPopupDialogs.CLARA_SYNC_TRUST
check(popup and M.popup and M.popup.which == "CLARA_SYNC_TRUST" and M.popup.text:find("Zed uses Clara too", 1, true),
  "unknown, its hello unsigned with our key: the player is asked")
mark = #M.addonSent + 1
popup.OnAccept(nil, "Zed-Forever")
Run()
local key
for _, m in ipairs(Sent(mark)) do if m.msg.t == "K" and m.chatType == "WHISPER" then key = m end end
check(ClaraSyncDB.trusted["Zed-Forever"] and key and key.target == "Zed-Forever" and key.tag == "------", "trusted: the key whispered to it")
Deliver({ t = "K", k = "00000000zzzzzzzz" }, "Zed", "WHISPER", false)
Run()
check(ClaraSyncDB.key == "00000000zzzzzzzz", "its key smaller: taken")
check(Joined("ClaraSync" .. ("%06x"):format(Sync.Hash("00000000zzzzzzzz"))), "the channel changed with it")
Deliver({ t = "K", k = "000" }, "Yan", "WHISPER", false)
check(ClaraSyncDB.key == "00000000zzzzzzzz", "a key from a character not trusted: ignored")
Deliver({ t = "H", d = {} }, "Wil", "PARTY", "wilkey0000000000")
popup.OnCancel(nil, "Wil-Forever", "clicked")
check(ClaraSyncDB.declined["Wil-Forever"], "said no: not asked again")

out("== the stock")
mark = #M.addonSent + 1
S.bags = { [106] = 1 }
S.container = nil
Craft.db.chars["Lola-Forever"].at = 0
Craft.ScanBags()
Run()
check(#Sent(mark) > 0, "a character's stock: sent")
Deliver({ t = "B", k = "h", e = { { "Lola-Forever", 99999, { bags = { [106] = 999 }, bank = {}, mail = {}, at = 99999 } } } }, "Zed", "CHANNEL")
check(Craft.db.chars["Lola-Forever"].bags[106] ~= 999, "this character's own stock: never taken from another")

out("== off")
Sync.SetOn(false)
mark = #M.addonSent + 1
Mail.SetCategory("Jo", "friend", true)
Run()
check(#Sent(mark) == 0, "unticked: nothing sent")
Sync.SetOn(true)

out("")
out(fails .. " failure(s)")
