-- Clara Combo Points - the sync between the WoW accounts of one Battle.net: the mail module's lists (the
-- characters, the categories, the items given, the account's own characters) and Reverse Engineering's
-- stock (each character's bags, bank and mailbox, the mails sent between them, the account bank, the
-- recipes known), the gold tracker's characters (their gold, level and class; the accounts' names) and the
-- auction house prices (Prices.lua: live, only those of the items the player's characters hold). The bar
-- and the modules' settings are not shared: each WoW account keeps its own.
-- Every entry carries when it last changed; the newer wins (an entry removed keeps that time: removed
-- then). Two ways, together:
--   live, between characters online at the same time: their group (party or raid) and a hidden chat
--   channel only the player's characters join (its name from a key they share). A change goes out at
--   once (a character's bags at most every half minute); when two meet, each sends what the other lacks,
--   their entries compared in small batches. Every message is signed with the key;
--   between sessions: the Windows script (Synchro\ClaraSync.ps1) writes the other WoW accounts' data
--   into this one's saved file (ClaraSyncIncoming), merged here at login.
-- A character met in a group is trusted once the player says it is one of theirs (or it is known: met
-- by the sync, or Main/alt or Bank alt in the mail module); the two then share their key.

local ADDON, ns = ...
local L = ns.L
local M, C, Gd, Pr = ns.Mail, ns.Craft, ns.Money, ns.Prices
if not (M or C or Gd or Pr) then return end

local issecret = issecretvalue or function() return false end
local floor, max = math.floor, math.max

local PREFIX = "ClaraSync"
local PART = 230              -- a message's text, at most (the game takes 255 with our marks)
local HELLO_AGAIN = 60        -- the same character greeted at most this often
local CHAR_EVERY = 30         -- a character's bags sent at most this often
local SEND_EVERY = 0.12       -- between two messages
local CHUNK = 150             -- entries in one message, at most (a scan's prices: several messages)
local THROTTLED = { [3] = true, [8] = true, [11] = true } -- (the game's SendAddonMessageResult: throttled, locked)

local S = {}
ns.Sync = S

---------------------------------------------------------------------------
-- Its own saved data (ClaraSyncDB): the key, the characters trusted, those declined; on or off
---------------------------------------------------------------------------
local sdb
local function Clean(db)
  db = type(db) == "table" and db or {}
  local function Set(t)
    local out = {}
    for k, v in pairs(type(t) == "table" and t or {}) do if type(k) == "string" and v == true then out[k] = true end end
    return out
  end
  return { key = type(db.key) == "string" and #db.key >= 8 and db.key or nil, trusted = Set(db.trusted),
    declined = Set(db.declined), off = db.off == true or nil }
end

local CHARS = "abcdefghijklmnopqrstuvwxyz0123456789"
local function Random(n)
  local out = {}
  for i = 1, n do
    local k = math.random(1, #CHARS)
    out[i] = CHARS:sub(k, k)
  end
  return table.concat(out)
end

function S.On() return sdb ~= nil and not sdb.off end

---------------------------------------------------------------------------
-- Hashing (not a lock: it keeps out what is not ours)
---------------------------------------------------------------------------
local function Hash(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 16777216 end
  return h
end
S.Hash = Hash

local function Hex(n) return ("%06x"):format(n) end

-- A value written the same way everywhere (keys in order), to compare two clients' entries
local function Canon(v)
  if type(v) ~= "table" then return tostring(v) end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b)
    if type(a) == type(b) then return a < b end
    return type(a) < type(b)
  end)
  local out = {}
  for i, k in ipairs(keys) do out[i] = tostring(k) .. "=" .. Canon(v[k]) end
  return "{" .. table.concat(out, ",") .. "}"
end
S.Canon = Canon

---------------------------------------------------------------------------
-- The kinds of entries: where each is, its time, its content
--   r: a character of the mail list   c: a category   i: an item given   o: one of the account's own
--   h: a character's stock            s: a mail sent  a: the account bank p: a recipe known
--   n: an account's name (gold)       g: a character's gold, level and class
-- d is { mail = ClaraMailDB, craft = ClaraCraftDB, money = ClaraMoneyDB } (this account's, or another's from its file)
---------------------------------------------------------------------------
local K = {}
local ORDER = { "c", "r", "i", "o", "h", "s", "a", "p", "n", "g", "v" } -- (categories before the characters in them)

local function Union(a, b)
  for k in pairs(a or {}) do b[k] = true end
  return b
end

if M then
  K.r = { buckets = 8,
    keys = function(d, out) for k in pairs(d.mail.recipients) do out[k] = true end for k in pairs(d.mail.st.r) do out[k] = true end end,
    stamp = function(d, key) return d.mail.st.r[key] or 0 end,
    get = function(d, key)
      local r = d.mail.recipients[key]
      return r and { n = r.name, l = r.last, c = r.cats } or nil
    end,
    put = function(key, rec, at)
      local db = M.db
      if rec then
        local cats = {}
        for id, on in pairs(type(rec.c) == "table" and rec.c or {}) do if type(id) == "string" and on == true then cats[id] = true end end
        db.recipients[key] = { name = type(rec.n) == "string" and rec.n or key, last = type(rec.l) == "number" and rec.l or 0, cats = cats }
      else
        db.recipients[key] = nil
      end
      db.st.r[key] = at
    end,
    -- the same time on both sides (the lists from before the sync): the two put together
    union = function(key, rec)
      local r = M.db.recipients[key]
      if not (r and rec) then return rec ~= nil and not r end
      r.last = max(r.last or 0, type(rec.l) == "number" and rec.l or 0)
      for id, on in pairs(type(rec.c) == "table" and rec.c or {}) do if type(id) == "string" and on == true then r.cats[id] = true end end
      return false
    end,
  }
  K.c = { buckets = 1,
    keys = function(d, out) for _, c in ipairs(d.mail.categories) do out[c.id] = true end for k in pairs(d.mail.st.c) do out[k] = true end end,
    stamp = function(d, key) return d.mail.st.c[key] or 0 end,
    get = function(d, key)
      for _, c in ipairs(d.mail.categories) do if c.id == key then return { n = c.name or false } end end
    end,
    put = function(key, rec, at)
      local db = M.db
      local at_i
      for i, c in ipairs(db.categories) do if c.id == key then at_i = i end end
      if rec then
        local name = type(rec.n) == "string" and rec.n or nil
        if at_i then db.categories[at_i].name = name else table.insert(db.categories, { id = key, name = name }) end
        local n = tonumber(tostring(key):match("^c(%d+)"))
        if n and n >= db.nextId then db.nextId = n + 1 end
      elseif at_i then
        table.remove(db.categories, at_i)
        for _, r in pairs(db.recipients) do r.cats[key] = nil end
        if db.sort == key then db.sort = "last" end
      end
      db.st.c[key] = at
    end,
  }
  K.i = { buckets = 4,
    keys = function(d, out) for k in pairs(d.mail.items) do out[k] = true end for k in pairs(d.mail.st.i) do out[k] = true end end,
    stamp = function(d, key) return d.mail.st.i[key] or 0 end,
    get = function(d, key) local a = d.mail.items[key]; return a and { cat = a.cat, who = a.who } or nil end,
    put = function(key, rec, at)
      if type(key) ~= "number" then return end
      if rec and type(rec.cat) == "string" then
        M.db.items[key] = { cat = rec.cat, who = type(rec.who) == "string" and rec.who or nil }
      else
        M.db.items[key] = nil
      end
      M.db.st.i[key] = at
    end,
  }
  K.o = { buckets = 1,
    keys = function(d, out) for k in pairs(d.mail.own) do out[k] = true end for k in pairs(d.mail.st.o) do out[k] = true end end,
    stamp = function(d, key) return d.mail.st.o[key] or 0 end,
    get = function(d, key) return d.mail.own[key] and true or nil end,
    put = function(key, rec, at)
      M.db.own[key] = rec and true or nil
      M.db.st.o[key] = at
    end,
    union = function(key, rec)
      if rec and not M.db.own[key] then M.db.own[key] = true end
      return false
    end,
  }
end

if C then
  K.h = { buckets = 8, every = CHAR_EVERY,
    keys = function(d, out) for k in pairs(d.craft.chars) do out[k] = true end end,
    stamp = function(d, key) local c = d.craft.chars[key]; return c and c.at or 0 end,
    get = function(d, key)
      local c = d.craft.chars[key]
      return c and { bags = c.bags, bank = c.bank, mail = c.mail, mailAt = c.mailAt, at = c.at, class = c.class, remote = c.remote } or nil
    end,
    put = function(key, rec)
      if type(key) ~= "string" or key == C.me or type(rec) ~= "table" then return end
      local clean = C.Clean({ chars = { [key] = rec } }).chars[key]
      if clean then C.db.chars[key] = clean end
    end,
  }
  K.s = { buckets = 4,
    keys = function(d, out) for k in pairs(d.craft.sends) do out[k] = true end end,
    stamp = function(d, key) local s = d.craft.sends[key]; return s and s.at or 0 end,
    get = function(d, key) return d.craft.sends[key] end,
    put = function(key, rec)
      if type(key) ~= "string" or type(rec) ~= "table" then return end
      local clean = C.Clean({ sends = { [key] = rec } }).sends[key]
      if clean and time() - clean.at < 30 * 86400 then C.db.sends[key] = clean end
      if clean and not C.db.chars[clean.to] then
        C.db.chars[clean.to] = { bags = {}, bank = {}, mail = {}, at = 0, remote = true }
      end
    end,
  }
  K.a = { buckets = 1,
    keys = function(d, out) if next(d.craft.account) or (d.craft.accountAt or 0) > 0 then out.a = true end end,
    stamp = function(d) return d.craft.accountAt or 0 end,
    get = function(d) return { items = d.craft.account } end,
    put = function(_, rec, at)
      C.db.account = C.Clean({ account = rec and rec.items }).account
      C.db.accountAt = at
    end,
  }
  K.p = { buckets = 16, live = true, -- (only as they are learned: the files bring the rest)
    keys = function(d, out) for k in pairs(d.craft.recipes) do out[k] = true end end,
    stamp = function(d, key) local r = d.craft.recipes[key]; return r and r.t or 0 end,
    get = function(d, key) return d.craft.recipes[key] end,
    put = function(key, rec, at)
      if type(key) ~= "number" or type(rec) ~= "table" then return end
      local clean = C.Clean({ recipes = { [key] = rec } }).recipes[key]
      if not clean then return end
      local old = C.db.recipes[key]
      if old then Union(old.w, clean.w) end
      C.db.recipes[key] = clean
      C.RecipesChanged()
    end,
    -- whoever knows it, both sides' together
    union = function(key, rec)
      local old = C.db.recipes[key]
      if old and type(rec) == "table" and type(rec.w) == "table" then
        for k, on in pairs(rec.w) do if type(k) == "string" and on == true then old.w[k] = true end end
        C.RecipesChanged()
      end
      return old == nil
    end,
  }
end

if Gd then
  K.n = { buckets = 1,
    keys = function(d, out) for id in pairs(d.money.accounts) do out[id] = true end end,
    stamp = function(d, id) local a = d.money.accounts[id]; return a and a.at or 0 end,
    get = function(d, id) local a = d.money.accounts[id]; return a and { n = a.n } or nil end,
    put = function(id, rec, at)
      if type(id) ~= "string" or type(rec) ~= "table" or type(rec.n) ~= "string" or rec.n == "" then return end
      Gd.db.accounts[id] = { n = rec.n:sub(1, 24), at = at }
      if Gd.Changed then Gd.Changed() end
    end,
  }
  K.g = { buckets = 4, every = 30, -- (gold changes often: sent at most every half minute)
    keys = function(d, out)
      for key in pairs(d.money.chars) do out[key] = true end
      for key in pairs(d.money.gone) do out[key] = true end
    end,
    stamp = function(d, key) local r = d.money.chars[key]; return r and r.at or d.money.gone[key] or 0 end,
    get = function(d, key)
      local r = d.money.chars[key]
      return r and { n = r.n, r = r.r, c = r.c, l = r.l, m = r.m, a = r.a } or nil
    end,
    put = function(key, rec, at)
      if type(key) ~= "string" then return end
      local clean = rec and Gd.CleanChar(rec, at)
      if clean then
        Gd.db.chars[key] = clean
        Gd.db.gone[key] = nil
      else
        Gd.db.chars[key] = nil
        Gd.db.gone[key] = at
      end
      if Gd.Changed then Gd.Changed() end
    end,
  }
end

if Pr then
  -- an auction house price, by realm and Auctionator's item key: live only (a whole scan comes by the files)
  K.v = { buckets = 16, live = true, every = 20,
    keys = function(d, out) for key in pairs(d.prices.items) do out[key] = true end end,
    stamp = function(d, key) local r = d.prices.items[key]; return r and r.t or 0 end,
    get = function(d, key) local r = d.prices.items[key]; return r and { m = r.m, d = r.d, a = r.a } or nil end,
    put = function(key, rec, at) if rec then Pr.Put(key, rec, at) end end,
    union = function() return false end, -- (the same time: the same scan)
  }
end

local function Dbs() return { mail = M and M.db, craft = C and C.db, money = Gd and Gd.db, prices = Pr and Pr.db } end

local function Keys(kind, d)
  local out = {}
  K[kind].keys(d, out)
  return out
end

-- An entry from elsewhere: kept if newer (an older one: left as it is)
local function Apply(kind, key, rec, at)
  local k = K[kind]
  if not k or key == nil or type(at) ~= "number" then return false end
  if rec == false then rec = nil end
  local mineAt = k.stamp(Dbs(), key)
  if at > mineAt then
    k.put(key, rec, at)
    return true
  elseif at == mineAt then
    if k.union then
      local take = k.union(key, rec)
      if take then k.put(key, rec, at) end
      return true
    end
    -- the same time, two contents: the same one kept on both sides (the larger, as written)
    local here = k.get(Dbs(), key)
    if rec and Canon(rec) > (here and Canon(here) or "") then k.put(key, rec, at) return true end
  end
  return false
end
S.Apply = Apply

local function Changed()
  if M and M.Changed then M.Changed() end
  if C and C.Changed then C.Changed() end
  if Gd and Gd.Changed then Gd.Changed() end
end

-- A whole set of entries (another account's, from its file) taken in
function S.MergeFrom(d)
  local any = false
  for _, kind in ipairs(ORDER) do
    if K[kind] then
      for key in pairs(Keys(kind, d)) do
        if Apply(kind, key, K[kind].get(d, key), K[kind].stamp(d, key)) then any = true end
      end
    end
  end
  return any
end

---------------------------------------------------------------------------
-- Comparing: each kind's entries in buckets, a number for each bucket
---------------------------------------------------------------------------
local function Bucket(key, n) return Hash(tostring(key)) % n + 1 end

local function Print(key, kind, d)
  local rec = K[kind].get(d, key)
  return tostring(key) .. "=" .. K[kind].stamp(d, key) .. ":" .. Hash(rec and Canon(rec) or "-")
end

function S.Digests()
  local d, out = Dbs(), {}
  for _, kind in ipairs(ORDER) do
    local k = K[kind]
    if k and not k.live then
      local lists = {}
      for key in pairs(Keys(kind, d)) do
        local b = Bucket(key, k.buckets)
        lists[b] = lists[b] or {}
        table.insert(lists[b], Print(key, kind, d))
      end
      local digest = {}
      for b = 1, k.buckets do
        local list = lists[b]
        if list then table.sort(list) digest[b] = Hash(table.concat(list, ";")) else digest[b] = 0 end
      end
      out[kind] = digest
    end
  end
  return out
end

-- A bucket's entries: { { key, time, content or false }, ... }
function S.BucketEntries(kind, b)
  local d, k, list = Dbs(), K[kind], {}
  for key in pairs(Keys(kind, d)) do
    if Bucket(key, k.buckets) == b then list[#list + 1] = { key, k.stamp(d, key), k.get(d, key) or false } end
  end
  return list
end

---------------------------------------------------------------------------
-- Sending: signed, in parts, one part at a time (the game throttles)
---------------------------------------------------------------------------
local queue, sending = {}, false
local me, myKey, realm
local channelName, channelId

local function Pump()
  local entry = queue[1]
  if not entry then sending = false return end
  local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, entry[1], entry[2], entry[3])
  if ok and THROTTLED[result] then
    C_Timer.After(1.5, Pump)
    return
  end
  table.remove(queue, 1)
  C_Timer.After(SEND_EVERY, Pump)
end

local function Push(text, chatType, target)
  queue[#queue + 1] = { text, chatType, target }
  if not sending then
    sending = true
    C_Timer.After(0, Pump)
  end
end

local msgCount = 0
-- A message, signed with the key and cut in parts; to: a character (whispered), or everyone (group and
-- channel); unsigned: the key itself, whispered
local function Send(msg, to, unsigned)
  local payload = ns.Encode64(ns.Serialize(msg))
  local text = (unsigned and "------" or Hex(Hash(sdb.key .. payload))) .. payload
  msgCount = msgCount + 1
  local id = Random(2) .. (msgCount % 10)
  local parts = math.ceil(#text / PART)
  for i = 1, parts do
    local part = id .. i .. "/" .. parts .. ":" .. text:sub((i - 1) * PART + 1, i * PART)
    if to then
      Push(part, "WHISPER", to)
    else
      if IsInRaid and IsInRaid() then Push(part, "RAID") elseif IsInGroup and IsInGroup() then Push(part, "PARTY") end
      if channelId then Push(part, "CHANNEL", tostring(channelId)) end
    end
  end
end
S.Send = Send

---------------------------------------------------------------------------
-- Who is one of the player's characters
---------------------------------------------------------------------------
local function KeyOf(sender)
  if type(sender) ~= "string" or issecret(sender) then return nil end
  if sender:find("-", 1, true) then return sender end
  return sender .. "-" .. (realm or "")
end

local function Trusted(key)
  if not key then return false end
  if sdb.trusted[key] then return true end
  if C and C.db.chars[key] and not C.db.chars[key].remote then return true end
  local short = key:match("^(.-)%-") or key
  if M and M.db then
    if M.db.own[short:lower()] then return true end
    if M.HasCategory(short, "mainalt") or M.HasCategory(short, "bankalt") then return true end
  end
  return false
end
S.Trusted = Trusted

---------------------------------------------------------------------------
-- The channel: its name from the key; hidden from the chat
---------------------------------------------------------------------------
local function ChannelName(key) return "ClaraSync" .. Hex(Hash(key)) end

local joinTries = 0
local function Join()
  if not S.On() then return end
  local id = GetChannelName(channelName)
  if id and id > 0 then
    channelId = id
    for i = 1, NUM_CHAT_WINDOWS or 10 do
      local frame = _G["ChatFrame" .. i]
      if frame and frame.RemoveChannel then pcall(frame.RemoveChannel, frame, channelName) end
    end
    return
  end
  joinTries = joinTries + 1
  if joinTries > 6 then return end
  if select("#", GetChannelList()) == 0 and joinTries < 5 then C_Timer.After(4, Join) return end
  -- (the game's own UI joins with JoinPermanentChannel: the last resort, if the other two are not there)
  local join = JoinChannelByName or JoinTemporaryChannel or JoinPermanentChannel
  if join then pcall(join, channelName) end
  C_Timer.After(5, Join)
end

local function SetKey(key)
  if key == myKey then return end
  if channelName and LeaveChannelByName then pcall(LeaveChannelByName, channelName) end
  myKey, sdb.key = key, key
  channelName, channelId, joinTries = ChannelName(key), nil, 0
  Join()
end

-- Two keys meeting: both sides keep the smaller
local function Adopt(key)
  if type(key) == "string" and #key >= 8 and key < myKey then SetKey(key) return true end
  return false
end

local function Quiet(_, _, _, _, _, channel, ...)
  local base = select(5, ...)
  for _, s in ipairs({ channel, base }) do
    if type(s) == "string" and not issecret(s) and s:find("ClaraSync", 1, true) then return true end
  end
  return false
end
local AddFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
if AddFilter then
  for _, e in ipairs({ "CHAT_MSG_CHANNEL", "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER" }) do AddFilter(e, Quiet) end
end

---------------------------------------------------------------------------
-- Meeting: hello (the digests), the buckets that differ, each change as it comes
---------------------------------------------------------------------------
local greeted = {}    -- character -> when greeted last
S.seen = {}           -- character -> when heard last

local function Hello(to)
  if not S.On() then return end
  Send({ t = "H", d = S.Digests() }, to)
end
S.Hello = Hello

local function OnHello(sender, msg)
  local theirs = type(msg.d) == "table" and msg.d or {}
  local mine = S.Digests()
  for kind, digest in pairs(mine) do
    local other = type(theirs[kind]) == "table" and theirs[kind] or {}
    for b = 1, #digest do
      if digest[b] ~= other[b] and digest[b] ~= 0 then
        Send({ t = "B", k = kind, b = b, e = S.BucketEntries(kind, b) })
      end
    end
  end
  if not greeted[sender] or GetTime() - greeted[sender] > HELLO_AGAIN then
    greeted[sender] = GetTime()
    Hello()
  end
end

local function OnEntries(list, kind)
  local any = false
  for _, e in ipairs(type(list) == "table" and list or {}) do
    if type(e) == "table" and Apply(kind, e[1], e[2] ~= nil and e[3] or nil, e[2]) then any = true end
  end
  if any then Changed() end
end

-- A change here: out at once (a character's stock at most every half minute)
local pending, timers = {}, {}
local function Flush(kind)
  timers[kind] = nil
  local d, k, list = Dbs(), K[kind], {}
  for key in pairs(pending[kind] or {}) do list[#list + 1] = { key, k.stamp(d, key), k.get(d, key) or false } end
  pending[kind] = nil
  if not S.On() then return end
  for first = 1, #list, CHUNK do
    local part = {}
    for i = first, math.min(first + CHUNK - 1, #list) do part[#part + 1] = list[i] end
    Send({ t = "B", k = kind, e = part })
  end
end

local function Touched(kind, key)
  if not (K[kind] and S.On()) then return end
  pending[kind] = pending[kind] or {}
  pending[kind][key] = true
  if not timers[kind] then
    timers[kind] = true
    C_Timer.After(K[kind].every or 1, function() Flush(kind) end)
  end
end
S.Touched = Touched

---------------------------------------------------------------------------
-- Trusting a character met in a group
---------------------------------------------------------------------------
local asked = {}
local function Trust(key)
  sdb.trusted[key] = true
  sdb.declined[key] = nil
  Send({ t = "K", k = myKey }, key, true)
  Hello()
end
S.Trust = Trust

local function Ask(key)
  if asked[key] or sdb.declined[key] then return end
  asked[key] = true
  if not (StaticPopupDialogs and StaticPopup_Show) then return end
  StaticPopupDialogs.CLARA_SYNC_TRUST = StaticPopupDialogs.CLARA_SYNC_TRUST or {
    text = L.SYNC_TRUST, button1 = YES or "Yes", button2 = NO or "No", timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function(_, data) if data then Trust(data) end end,
    OnCancel = function(_, data, reason) if data and reason ~= "timeout" then sdb.declined[data] = true end end,
  }
  StaticPopup_Show("CLARA_SYNC_TRUST", (key:match("^(.-)%-") or key), nil, key)
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
local parts = {}   -- sender .. id -> { n, got, list }

local function Handle(sender, chatType, text)
  local key = KeyOf(sender)
  if not key or key == me then return end
  local tag, payload = text:sub(1, 6), text:sub(7)
  local msg = ns.Deserialize(ns.Decode64(payload) or "")
  if type(msg) ~= "table" then return end
  if tag == "------" then
    -- the key, whispered by a character trusted
    if msg.t == "K" and chatType == "WHISPER" and Trusted(key) then
      if not Adopt(msg.k) and type(msg.k) == "string" and msg.k > myKey then Send({ t = "K", k = myKey }, key, true) end
      Hello()
    end
    return
  end
  if tag ~= Hex(Hash(myKey .. payload)) then
    -- not signed with our key: met in a group, maybe one of the player's characters
    if msg.t == "H" and (chatType == "PARTY" or chatType == "RAID") then
      if Trusted(key) then Send({ t = "K", k = myKey }, key, true) else Ask(key) end
    end
    return
  end
  -- signed: one of ours (the channel's are trusted by the key itself)
  if not sdb.trusted[key] then sdb.trusted[key] = true end
  S.seen[key] = GetTime()
  if msg.t == "H" then
    OnHello(key, msg)
  elseif msg.t == "B" and K[msg.k] then
    OnEntries(msg.e, msg.k)
  end
end

local function OnAddon(prefix, text, chatType, sender)
  if prefix ~= PREFIX or type(text) ~= "string" or issecret(text) or not S.On() then return end
  local id, i, n, body = text:match("^(%w%w%d)(%d+)/(%d+):(.*)$")
  i, n = tonumber(i), tonumber(n)
  if not (id and i and n and n >= 1 and i <= n and n <= 400) then return end
  local slot = tostring(sender) .. id
  local p = parts[slot]
  if not p or p.n ~= n then
    p = { n = n, got = 0, list = {}, at = GetTime() }
    parts[slot] = p
  end
  if not p.list[i] then
    p.list[i] = body
    p.got = p.got + 1
  end
  if p.got < n then return end
  parts[slot] = nil
  Handle(sender, chatType, table.concat(p.list))
end
S.OnAddon = OnAddon -- (for the tests)

-- Parts never completed: dropped after a minute
C_Timer.NewTicker(60, function()
  for slot, p in pairs(parts) do if GetTime() - p.at > 60 then parts[slot] = nil end end
end)

---------------------------------------------------------------------------
-- The other accounts' files (the Windows script put them in this one's): merged at login
---------------------------------------------------------------------------
local function TakeIncoming()
  local incoming = ClaraSyncIncoming
  ClaraSyncIncoming = nil
  if type(incoming) ~= "table" then return false end
  local any = false
  for folder, src in pairs(incoming) do
    if type(src) == "table" then
      local d = {
        mail = M and type(src.ClaraMailDB) == "table" and M.Clean(src.ClaraMailDB) or (M and M.Clean(nil)),
        craft = C and type(src.ClaraCraftDB) == "table" and C.Clean(src.ClaraCraftDB) or (C and C.Clean(nil)),
        money = Gd and Gd.Clean(src.ClaraMoneyDB),
        prices = Pr and Pr.Clean(src.ClaraPricesDB),
      }
      -- that account's name: its folder, as the Windows script names its part (unless the player named it)
      if Gd and d.money.me and Gd.FolderName(d.money.me, folder) then any = true end
      if S.MergeFrom(d) then any = true end
      local other = type(src.ClaraSyncDB) == "table" and Clean(src.ClaraSyncDB)
      if other then
        if other.key and other.key < sdb.key then sdb.key = other.key end
        for k in pairs(other.trusted) do sdb.trusted[k] = true end
      end
    end
  end
  return any
end
S.TakeIncoming = TakeIncoming

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
  if event == "CHAT_MSG_ADDON" then
    OnAddon(...)
  elseif event == "GROUP_ROSTER_UPDATE" then
    if not S.helloSoon then
      S.helloSoon = true
      C_Timer.After(3, function() S.helloSoon = nil; if IsInGroup and IsInGroup() then Hello() end end)
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    joinTries = 0
    C_Timer.After(5, Join)
  end
end)

local function Start()
  ClaraSyncDB = Clean(ClaraSyncDB)
  sdb = ClaraSyncDB
  S.db = sdb
  if not sdb.key then sdb.key = Random(16) end
  realm = GetNormalizedRealmName and GetNormalizedRealmName() or (GetRealmName and GetRealmName() or ""):gsub("%s", "")
  local name = UnitName("player")
  me = type(name) == "string" and (name .. "-" .. (realm or "")) or nil
  -- this WoW account's mark on the mail categories it makes (never shared with another account's)
  local sv = ns.sv
  if sv then
    sv.syncMark = sv.syncMark or Random(3)
    if M then M.idMark = "-" .. sv.syncMark end
  end
  if TakeIncoming() then Changed() end
  myKey = sdb.key
  channelName = ChannelName(myKey)
  if M then M.Touched = Touched end
  if C then C.Touched = Touched end
  if Gd then Gd.Touched = Touched end
  if Pr then Pr.Touched = Touched end
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end
  for _, e in ipairs({ "CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do events:RegisterEvent(e) end
  C_Timer.After(8, function() Hello() end)
end

function S.SetOn(on)
  sdb.off = not on or nil
  if on then
    joinTries = 0
    Join()
    Hello()
  elseif channelName and LeaveChannelByName then
    pcall(LeaveChannelByName, channelName)
    channelId = nil
  end
end

-- Where it stands, for its options and /cl sync
function S.Status()
  local online = 0
  for _, at in pairs(S.seen) do if GetTime() - at < 300 then online = online + 1 end end
  local trusted = 0
  for _ in pairs(sdb.trusted) do trusted = trusted + 1 end
  return { on = S.On(), channel = channelId ~= nil, online = online, trusted = trusted, key = myKey and Hex(Hash(myKey)) }
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_LOGIN")
  C_Timer.After(0, Start) -- (after the mail module and Reverse Engineering have their data)
end)
