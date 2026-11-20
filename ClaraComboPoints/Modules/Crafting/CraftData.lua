-- Clara Combo Points - Reverse Engineering, its data (CraftUI.lua shows it, CraftGame.lua puts it in the
-- game's professions window, ClassicUI's window calls it). Kept for the account (ClaraCraftDB), and
-- shared with the other WoW accounts (Modules/Sync):
--   the account's characters' bags, bank and mailbox, read when each is open (each with when, the newer
--   wins), and each mail sent to one of them (counted on it until it opens its mail); the account bank;
--   the recipes seen in a professions window, any character's: what each makes, how many, from what,
--   and who knows it, so that a reagent made by another profession shows its own reagents too.
-- Also the search (a recipe found by its name or one of its reagents; "Name" in quotes: that recipe
-- alone) and the filter on what is in reach (all of a recipe's reagents, or some; the bags, or the
-- bank too).

local ADDON, ns = ...

local state = ns:QolState("reverseengineering")
-- Its own addon running: the text list is that one's; the rest is ours all the same.
if state ~= "on" and state ~= "standalone" then return end

local C = {}
ns.Craft = C
C.textAllowed = state == "on"

local issecret = issecretvalue or function() return false end
local floor, max, min = math.floor, math.max, math.min

local MAIL_KEEP = 30 * 86400    -- a mail sent, forgotten after the mail's own life
local MODES = { icons = true, text = true, off = true }

---------------------------------------------------------------------------
-- Saved data
---------------------------------------------------------------------------
local function Counts(t)
  local out = {}
  if type(t) == "table" then
    for id, n in pairs(t) do
      if type(id) == "number" and type(n) == "number" and n > 0 then out[id] = floor(n) end
    end
  end
  return out
end

local function Clean(db)
  db = type(db) == "table" and db or {}
  local chars = {}
  for key, c in pairs(type(db.chars) == "table" and db.chars or {}) do
    if type(key) == "string" and key:find("-", 1, true) and type(c) == "table" then
      chars[key] = { bags = Counts(c.bags), bank = Counts(c.bank), mail = Counts(c.mail),
        mailAt = type(c.mailAt) == "number" and c.mailAt or nil, at = type(c.at) == "number" and c.at or 0,
        class = type(c.class) == "string" and c.class or nil, remote = c.remote == true or nil }
    end
  end
  -- the mails sent to the account's characters: { to, at, items } each, by a key of its own
  local sends = {}
  for uid, s in pairs(type(db.sends) == "table" and db.sends or {}) do
    if type(uid) == "string" and type(s) == "table" and type(s.to) == "string" and type(s.at) == "number" then
      local items = Counts(s.items)
      if next(items) then sends[uid] = { to = s.to, at = s.at, items = items } end
    end
  end
  -- (before the sync: what was mailed lay on the character)
  for key, c in pairs(type(db.chars) == "table" and db.chars or {}) do
    local items = type(c) == "table" and Counts(c.sent)
    if items and next(items) and chars[key] then
      sends["old-" .. key] = { to = key, at = type(c.sentAt) == "number" and c.sentAt or 0, items = items }
    end
  end
  local recipes = {}
  for id, r in pairs(type(db.recipes) == "table" and db.recipes or {}) do
    if type(id) == "number" and type(r) == "table" and type(r.o) == "number" and type(r.r) == "table" then
      local list = {}
      for i = 1, #r.r - 1, 2 do
        if type(r.r[i]) == "number" and type(r.r[i + 1]) == "number" then
          list[#list + 1] = r.r[i]; list[#list + 1] = r.r[i + 1]
        end
      end
      local who = {}
      for k, on in pairs(type(r.w) == "table" and r.w or {}) do if type(k) == "string" and on == true then who[k] = true end end
      recipes[id] = { o = r.o, m = type(r.m) == "number" and r.m > 0 and r.m or 1, r = list, w = who,
        p = type(r.p) == "string" and r.p or nil, q = type(r.q) == "string" and r.q or nil, t = type(r.t) == "number" and r.t or 0 }
    end
  end
  -- the subcomponents folded (their reagents hidden), by the item they make
  local collapsed = {}
  for id, on in pairs(type(db.collapsed) == "table" and db.collapsed or {}) do
    if type(id) == "number" and on == true then collapsed[id] = true end
  end
  local filter = type(db.filter) == "table" and db.filter or {}
  local function Off(v) if v == false then return false end end -- (a box unticked; nil: its default, on)
  return { mode = MODES[db.mode] and db.mode or nil, chest = Off(db.chest), search = Off(db.search), nested = db.nested == true or nil,
    filter = { on = filter.on == true or nil, bank = filter.bank == true or nil, part = filter.part == true or nil },
    chars = chars, account = Counts(db.account), accountAt = type(db.accountAt) == "number" and db.accountAt or 0,
    recipes = recipes, sends = sends, collapsed = next(collapsed) and collapsed or nil }
end
C.Clean = Clean

local db, me, mine
local realm

function C.Mode()
  local mode = db and db.mode or "icons"
  if mode == "text" and not C.textAllowed then return "icons" end
  return mode
end
function C.SetMode(mode) if MODES[mode] then db.mode = mode ~= "icons" and mode or nil end end
function C.Option(key) return db ~= nil and db[key] ~= false end
function C.SetOption(key, on) if on then db[key] = nil else db[key] = false end end
function C.Nested() return db ~= nil and db.nested == true end
function C.SetNested(on) db.nested = on and true or nil end
function C.Collapsed(id) return db ~= nil and db.collapsed ~= nil and db.collapsed[id] == true end
function C.SetCollapsed(id, on)
  if not db or type(id) ~= "number" then return end
  db.collapsed = db.collapsed or {}
  db.collapsed[id] = on and true or nil
  if not next(db.collapsed) then db.collapsed = nil end
end
function C.Filter() return db and db.filter or {} end
function C.SetFilter(key, on) db.filter[key] = on and true or nil end

---------------------------------------------------------------------------
-- Characters
---------------------------------------------------------------------------
-- A character's key: Name-Realm (the realm as the game writes it in names, without spaces)
-- (Clara Combo Points) The account's characters are kept by the first name the game gives them
-- (UnitName: on WoW Forever the surname comes apart). A whole name typed ("Clara Moon", in the mail's
-- To field) is that character: its key ("Clara-Realm"), when the account has exactly one so named.
local function OwnFirst(full, where)
  local first = type(full) == "string" and full:match("^(%S+)%s+%S")
  if not first then return nil end
  local want = (first .. "-" .. (where or realm or "")):lower()
  local found
  for key, c in pairs(db.chars) do
    if not c.remote and key:lower() == want then
      if found then return nil end
      found = key
    end
  end
  return found
end

local function KeyOf(name)
  if type(name) ~= "string" or name == "" or issecret(name) then return nil end
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  if not name:find("-", 1, true) then name = name .. "-" .. (realm or "") end
  for key in pairs(db.chars) do
    if key:lower() == name:lower() then return key end
  end
  local base, where = name:match("^(.-)%-([^%-]*)$")
  return OwnFirst(base, where) or name
end
C.KeyOf = KeyOf

-- Mails to the account's characters recorded under a whole name by earlier versions: under the
-- character's own key again (one character, one entry), at every start.
local function MergeWholeNames()
  local merged = false
  for key, c in pairs(db.chars) do
    if c.remote then
      local base, where = key:match("^(.-)%-([^%-]*)$")
      local own = OwnFirst(base, where)
      if own and own ~= key then
        for uid, s in pairs(db.sends) do
          if s.to == key then s.to = own; if C.Touched then C.Touched("s", uid) end end
        end
        db.chars[key] = nil
        merged = true
      end
    end
  end
  return merged
end
C.MergeWholeNames = MergeWholeNames

local function ShortName(key)
  local name, where = key:match("^(.-)%-(.*)$")
  if where == realm then return name end
  return key
end
C.ShortName = ShortName

-- One of the account's characters: met here (any level), or one the mail module knows as such
-- (the account's own, Main/alt or Bank alt)
function C.IsMine(name)
  local key = KeyOf(name)
  if not key then return false end
  if db.chars[key] and not db.chars[key].remote then return true end
  local mail = ns.Mail and ns.Mail.db
  if mail then
    local short = key:match("^(.-)%-") or key
    local lower = short:lower()
    if mail.own and mail.own[lower] then return true end
    if ns.Mail.HasCategory and (ns.Mail.HasCategory(short, "mainalt") or ns.Mail.HasCategory(short, "bankalt")) then
      return true
    end
  end
  return db.chars[key] ~= nil
end

---------------------------------------------------------------------------
-- What is where
---------------------------------------------------------------------------
local function ItemCount(id, bank)
  local get = C_Item and C_Item.GetItemCount or GetItemCount
  return get and get(id, bank or false) or 0
end

-- Bags now (the game's own count)
function C.Bags(id) return ItemCount(id) end

-- The bank: as read at the last visit (the game's own count while it is open); the account's tabs apart
function C.Bank(id) return (mine and mine.bank[id] or 0) end
function C.AccountBank(id) return db and db.account[id] or 0 end

-- In reach as the settings say: bags, and the bank if asked
function C.Have(id, withBank)
  local n = C.Bags(id)
  if withBank then n = n + C.Bank(id) + C.AccountBank(id) end
  return n
end

-- What was mailed to a character and not seen in its mailbox yet
local function Mailed(key, id)
  local c = db.chars[key]
  local seen = c and c.mailAt or 0
  local n = 0
  for _, s in pairs(db.sends) do
    if s.to == key and s.at > seen then n = n + (s.items[id] or 0) end
  end
  return n
end
C.Mailed = Mailed

-- The account's other characters having some: { { name, bags, bank, mail }, ... }, most first
function C.Others(id)
  local list = {}
  for key, c in pairs(db.chars) do
    if key ~= me then
      local bags, bank, mail = c.bags[id] or 0, c.bank[id] or 0, (c.mail[id] or 0) + Mailed(key, id)
      if bags + bank + mail > 0 then
        list[#list + 1] = { name = ShortName(key), bags = bags, bank = bank, mail = mail, class = c.class,
          remote = c.remote, total = bags + bank + mail }
      end
    end
  end
  table.sort(list, function(a, b)
    if a.total ~= b.total then return a.total > b.total end
    return a.name < b.name
  end)
  return list
end

local function Scan(bags)
  local counts = {}
  local api = C_Container
  if not (api and api.GetContainerNumSlots and api.GetContainerItemInfo) then return counts end
  for _, bag in ipairs(bags) do
    for slot = 1, api.GetContainerNumSlots(bag) or 0 do
      local info = api.GetContainerItemInfo(bag, slot)
      local id, n = info and info.itemID, info and info.stackCount
      if id and n and not issecret(id) and not issecret(n) then counts[id] = (counts[id] or 0) + n end
    end
  end
  return counts
end

local B = Enum and Enum.BagIndex or {}
local BAGS, BANK, ACCOUNT = { 0, 1, 2, 3, 4 }, {}, {}
if B.ReagentBag then BAGS[#BAGS + 1] = B.ReagentBag end
if B.Keyring then BAGS[#BAGS + 1] = B.Keyring end
for i = 1, 9 do
  if B["CharacterBankTab_" .. i] then BANK[#BANK + 1] = B["CharacterBankTab_" .. i] end
  if B["AccountBankTab_" .. i] then ACCOUNT[#ACCOUNT + 1] = B["AccountBankTab_" .. i] end
end
if #BANK == 0 then -- (the old bank: its own slots, then its bags)
  BANK[1] = BANK_CONTAINER or -1
  for i = (NUM_BAG_SLOTS or 4) + 1, (NUM_BAG_SLOTS or 4) + (NUM_BANKBAGSLOTS or 6) do BANK[#BANK + 1] = i end
end

local bankOpen = false

-- This character's entry changed (C.Touched: the sync sends it on)
local function Touch(kind, key)
  if C.Touched then C.Touched(kind, key) end
end

local function Same(a, b)
  for id, n in pairs(a) do if b[id] ~= n then return false end end
  for id in pairs(b) do if not a[id] then return false end end
  return true
end

function C.ScanBags()
  if not mine then return end
  local bags = Scan(BAGS)
  if Same(bags, mine.bags) and mine.at > 0 then return end
  mine.bags, mine.at = bags, time()
  Touch("h", me)
end
function C.ScanBank()
  if not (mine and bankOpen) then return end
  local bank = Scan(BANK)
  if not Same(bank, mine.bank) then
    mine.bank, mine.at = bank, time()
    Touch("h", me)
  end
  if #ACCOUNT > 0 then
    local account = Scan(ACCOUNT)
    if (next(account) or next(db.account)) and not Same(account, db.account) then
      db.account, db.accountAt = account, time()
      Touch("a", "a")
    end
  end
end

-- The mailbox as it is: what was mailed to this character is in it now
function C.ScanMail()
  if not (mine and GetInboxNumItems and GetInboxItem) then return end
  local counts = {}
  for i = 1, GetInboxNumItems() or 0 do
    for j = 1, ATTACHMENTS_MAX_RECEIVE or 16 do
      local _, id, _, n = GetInboxItem(i, j)
      if id and n and not issecret(id) then counts[id] = (counts[id] or 0) + n end
    end
  end
  mine.mail, mine.mailAt, mine.at = counts, time(), time()
  Touch("h", me)
end

-- A mail going to one of the account's characters: its attachments counted on that one
local pending
local function OnSend(name)
  pending = nil
  if not (db and C.IsMine(name) and GetSendMailItem) then return end
  local items = {}
  for i = 1, ATTACHMENTS_MAX_SEND or 12 do
    local _, id, _, n = GetSendMailItem(i)
    if id and n and not issecret(id) then items[id] = (items[id] or 0) + n end
  end
  if next(items) then pending = { key = KeyOf(name), items = items } end
end

local sendCount = 0
local function Sent()
  if not pending then return end
  local key, items = pending.key, pending.items
  pending = nil
  if not db.chars[key] then
    db.chars[key] = { bags = {}, bank = {}, mail = {}, at = 0, remote = true }
  end
  sendCount = sendCount + 1
  local uid = ("%s-%d-%d"):format(me or "?", time(), sendCount)
  db.sends[uid] = { to = key, at = time(), items = items }
  Touch("s", uid)
end
C.OnSend, C.Sent = OnSend, Sent -- (for the tests)

---------------------------------------------------------------------------
-- Recipes
---------------------------------------------------------------------------
local live = {}      -- recipe ID -> { o, m, r, q, name } read from the game this session
local byItem         -- item made -> recipe ID

local function Schematic(id)
  local api = C_TradeSkillUI
  if not (api and api.GetRecipeSchematic) then return end
  local ok, s = pcall(api.GetRecipeSchematic, id, false)
  if ok and type(s) == "table" then return s end
end

local BASIC = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic

-- A recipe as the game gives it (its basic reagents, the first item of each), kept for the session
function C.Read(id)
  if live[id] ~= nil then return live[id] or nil end
  local s = Schematic(id)
  if not s or not s.outputItemID then live[id] = false return nil end
  local list = {}
  for _, slot in ipairs(s.reagentSlotSchematics or {}) do
    local first = slot.reagents and slot.reagents[1]
    if (BASIC == nil or slot.reagentType == nil or slot.reagentType == BASIC) and first and first.itemID
      and (slot.quantityRequired or 0) > 0 then
      list[#list + 1] = first.itemID
      list[#list + 1] = slot.quantityRequired
    end
  end
  local needs = {}
  local api = C_TradeSkillUI
  local reqs = api.GetRecipeRequirements and api.GetRecipeRequirements(id)
  for _, req in ipairs(reqs or {}) do if type(req.name) == "string" then needs[#needs + 1] = req.name end end
  local r = { o = s.outputItemID, m = max(1, s.quantityMin or 1), r = list, q = #needs > 0 and table.concat(needs, ", ") or nil,
    name = s.name }
  live[id] = r
  return r
end

-- Kept for the account, with who knows it
local function Keep(id, profession)
  local r = C.Read(id)
  if not r then return end
  local old = db.recipes[id]
  if old and me and old.w[me] and old.p then return end -- (known already, by this character)
  local who = old and old.w or {}
  if me then who[me] = true end
  db.recipes[id] = { o = r.o, m = r.m, r = r.r, q = r.q, p = profession or (old and old.p), w = who, t = time() }
  byItem = nil
  Touch("p", id)
end
function C.RecipesChanged() byItem = nil end

-- A recipe, read now or kept from before
function C.Recipe(id) return C.Read(id) or db.recipes[id] end

-- The recipe making an item (one this character knows first)
function C.RecipeFor(itemID)
  if not byItem then
    byItem = {}
    for id, r in pairs(db.recipes) do
      if not byItem[r.o] or (me and r.w[me]) then byItem[r.o] = id end
    end
    for id, r in pairs(live) do if r then byItem[r.o] = byItem[r.o] or id end end
  end
  return byItem[itemID]
end

-- Who else knows it, and in which profession
function C.KnownBy(id)
  local r = db.recipes[id]
  if not r then return nil end
  local names = {}
  for key in pairs(r.w) do names[#names + 1] = ShortName(key) end
  table.sort(names)
  return names, r.p, me and r.w[me]
end

-- Reagents as { { id, count }, ... }
function C.Reagents(id)
  local r = C.Recipe(id)
  local out = {}
  if not r then return out end
  for i = 1, #r.r - 1, 2 do out[#out + 1] = { r.r[i], r.r[i + 1] } end
  return out
end

-- How many can be made from the bags (its own recipe's reagents)
function C.Craftable(id, withBank)
  local r = C.Recipe(id)
  if not r or #r.r == 0 then return 0 end
  local crafts
  for i = 1, #r.r - 1, 2 do
    local n = floor(C.Have(r.r[i], withBank) / r.r[i + 1])
    crafts = crafts and min(crafts, n) or n
  end
  return (crafts or 0) * r.m
end

-- The open window's recipes kept, a few a frame (its list is long)
local queue, queued = {}, {}
local function Drain()
  for _ = 1, 12 do
    local job = table.remove(queue)
    if not job then return end
    Keep(job[1], job[2])
  end
  C_Timer.After(0, Drain)
end
function C.LearnWindow()
  local api = C_TradeSkillUI
  if not (api and api.GetFilteredRecipeIDs and api.GetRecipeInfo) then return end
  if api.IsTradeSkillLinked and api.IsTradeSkillLinked() then return end
  if api.IsNPCCrafting and api.IsNPCCrafting() then return end
  local prof = api.GetBaseProfessionInfo and api.GetBaseProfessionInfo()
  local profession = prof and prof.professionName
  local ids = (api.GetAllRecipeIDs and api.GetAllRecipeIDs()) or api.GetFilteredRecipeIDs() or {}
  local start = #queue == 0
  for _, id in ipairs(ids) do
    local info = not queued[id] and api.GetRecipeInfo(id)
    if info and info.learned then
      queued[id] = true
      queue[#queue + 1] = { id, profession }
    end
  end
  if start and #queue > 0 then C_Timer.After(0, Drain) end
end

---------------------------------------------------------------------------
-- The search: a recipe's name, or one of its reagents' (accents and case aside); "Name" in quotes:
-- the recipe of that very name (or making that very item), alone
---------------------------------------------------------------------------
local hay = {}       -- recipe ID -> { name, item, all } (search keys); kept once every name was there

-- An item's name. One the game does not have yet is asked for once (its answer, GET_ITEM_INFO_RECEIVED or
-- ITEM_DATA_LOAD_RESULT, says when it came, or that it never will), then left alone: asked again each time the
-- recipes are searched, the game's answers made the professions list again and again, its rows never clickable
-- (the list made anew between the press and the release). A request with no answer is tried once more a minute on.
local asked = {}     -- item ID -> when it was asked for (an answer pending)
local missing = {}   -- item ID -> true: the game said it has no such item
C.itemRequests = {}  -- (when items were asked for, for the mouse report)
local RETRY = 60
local function ItemName(id)
  if missing[id] then return nil end
  local at = asked[id]
  if at and GetTime() - at < RETRY then return nil end -- (asked: its answer awaited, not asked again)
  local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
  if name then
    asked[id] = nil
    return name
  end
  if at then missing[id] = true return nil end -- (asked twice, never came)
  asked[id] = GetTime()
  local list = C.itemRequests
  list[#list + 1] = GetTime()
  if #list > 50 then table.remove(list, 1) end
  if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
  return nil
end
C.ItemName = ItemName
-- The game's answer: the name there now, or none to wait for
function C.ItemAnswered(id, ok)
  if type(id) ~= "number" or not asked[id] then return end
  asked[id] = nil
  if ok == false then missing[id] = true end
end
function C.ItemMissing(id) return missing[id] == true end

local function Hay(id, name)
  local h = hay[id]
  if h then return h end
  local key = ns.SearchKey
  local r = C.Recipe(id)
  local whole = true
  local parts = { key(ns, name or (r and r.name) or "") }
  local item = r and ItemName(r.o)
  if r and not item and not missing[r.o] then whole = false end
  if item then parts[#parts + 1] = key(ns, item) end
  for _, reagent in ipairs(C.Reagents(id)) do
    local n = ItemName(reagent[1])
    if n then parts[#parts + 1] = key(ns, n) elseif not missing[reagent[1]] then whole = false end
  end
  h = { name = parts[1], item = item and key(ns, item) or parts[1], all = table.concat(parts, "\n") }
  if whole then hay[id] = h end
  return h
end

local QUOTES = { { '^"(.*)"$' }, { "^\194\171%s*(.-)%s*\194\187$" }, { "^\226\128\156(.*)\226\128\157$" } }

-- The text's parts: its search key, and whether it is in quotes
function C.Query(text)
  text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then return nil end
  for _, q in ipairs(QUOTES) do
    local inner = text:match(q[1])
    if inner then return ns:SearchKey(inner), true end
  end
  return ns:SearchKey(text), false
end

function C.Match(id, name, text)
  if not C.Option("search") then
    return text == nil or text == "" or (type(name) == "string" and name:lower():find(tostring(text):lower(), 1, true) ~= nil)
  end
  local key, exact = C.Query(text)
  if not key then return true end
  if key == "" then return not exact end
  local h = Hay(id, name)
  if exact then return h.name == key or h.item == key end
  return h.all:find(key, 1, true) ~= nil
end

---------------------------------------------------------------------------
-- The filter: a recipe whose reagents are in reach (all of them, or some)
---------------------------------------------------------------------------
function C.FilterOn() return db ~= nil and db.filter.on == true end

function C.Shown(id)
  local f = db and db.filter
  if not (f and f.on) then return true end
  local list = C.Reagents(id)
  if #list == 0 then return true end
  for _, reagent in ipairs(list) do
    local have = C.Have(reagent[1], f.bank)
    if f.part then
      if have > 0 then return true end
    elseif have < reagent[2] then
      return false
    end
  end
  return not f.part
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local soon = {}
local function Soon(key, fn, delay)
  if soon[key] then return end
  soon[key] = true
  C_Timer.After(delay or 0.3, function() soon[key] = nil; fn() end)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, arg, arg2)
  if event == "BAG_UPDATE_DELAYED" then
    Soon("bags", function()
      C.ScanBags()
      if bankOpen then C.ScanBank() end
      if C.Changed then C.Changed() end
    end)
  elseif event == "BANKFRAME_OPENED" then
    bankOpen = true
    C.ScanBank()
    if C.Changed then C.Changed() end
  elseif event == "BANKFRAME_CLOSED" then
    C.ScanBank()
    bankOpen = false
  elseif event == "PLAYERBANKSLOTS_CHANGED" then
    Soon("bank", C.ScanBank)
  elseif event == "MAIL_SHOW" then
    events:RegisterEvent("MAIL_INBOX_UPDATE")
    events:RegisterEvent("MAIL_SEND_SUCCESS")
    events:RegisterEvent("MAIL_FAILED")
    events:RegisterEvent("MAIL_CLOSED")
  elseif event == "MAIL_CLOSED" then
    for _, e in ipairs({ "MAIL_INBOX_UPDATE", "MAIL_SEND_SUCCESS", "MAIL_FAILED", "MAIL_CLOSED" }) do events:UnregisterEvent(e) end
    pending = nil
  elseif event == "MAIL_INBOX_UPDATE" then
    Soon("mail", C.ScanMail)
  elseif event == "MAIL_SEND_SUCCESS" then
    Sent()
  elseif event == "MAIL_FAILED" then
    pending = nil
  elseif event == "TRADE_SKILL_LIST_UPDATE" or event == "TRADE_SKILL_SHOW" then
    Soon("learn", C.LearnWindow, 1)
  elseif event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
    C.ItemAnswered(arg, arg2)
  end
end)

local function Start()
  ClaraCraftDB = Clean(ClaraCraftDB)
  db = ClaraCraftDB
  C.db = db
  realm = GetNormalizedRealmName and GetNormalizedRealmName() or (GetRealmName and GetRealmName() or ""):gsub("%s", "")
  local name = UnitName("player")
  if type(name) == "string" and realm and realm ~= "" then
    me = name .. "-" .. realm
    mine = db.chars[me]
    if not mine then
      mine = { bags = {}, bank = {}, mail = {}, at = 0 }
      db.chars[me] = mine
    end
    mine.remote = nil
    mine.class = select(2, UnitClass("player"))
  end
  C.me = me
  MergeWholeNames()
  for uid, s in pairs(db.sends) do
    if time() - s.at > MAIL_KEEP then db.sends[uid] = nil end
  end
  C.ScanBags()
  for _, e in ipairs({ "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED", "MAIL_SHOW",
    "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT" }) do
    pcall(events.RegisterEvent, events, e)
  end
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_LOGIN")
  Start()
end)
if SendMail then hooksecurefunc("SendMail", OnSend) end
