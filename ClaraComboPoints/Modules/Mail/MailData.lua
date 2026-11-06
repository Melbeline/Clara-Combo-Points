-- Clara Combo Points - the mail module's data (MailUI.lua shows it): the characters mail was sent
-- to, newest first, and the categories each is in (several at once); the account's own characters
-- join the list as Main/alt once they reach level 3. Categories: four to start with (Main/alt, Bank
-- alt, Friend, Customer), the player's own added or deleted. Items given to a category, or to a
-- character of it (stage 2), stay remembered when the category goes, doing nothing. All of it is
-- account-wide (ClaraMailDB), and passed to another account as a line of text (export / import).

local ADDON, ns = ...
local issecretvalue = issecretvalue or function() return false end
local L = ns.L

if not ns:QolRuns("mail") then return end

local M = {}
ns.Mail = M

local DEFAULTS = { "mainalt", "bankalt", "friend", "customer" } -- (their names: L.MAIL_CAT_<ID>)
local OWN_LEVEL = 3          -- the account's characters join the list as Main/alt from this level
local NAME_MAX = 32          -- a category's name, in letters
local EXPORT_PREFIX = "CCPM1:"
local MAX_IMPORT = 262144

---------------------------------------------------------------------------
-- Saved data
---------------------------------------------------------------------------
local function DefaultCategories()
  local list = {}
  for i, id in ipairs(DEFAULTS) do list[i] = { id = id } end
  return list
end

-- the saved data checked: what is not as it should be is dropped
local function Clean(db)
  db = type(db) == "table" and db or {}
  local categories, known = {}, {}
  if type(db.categories) == "table" then
    for _, c in ipairs(db.categories) do
      if type(c) == "table" and type(c.id) == "string" and not known[c.id]
        and (c.name == nil or (type(c.name) == "string" and c.name ~= "")) then
        known[c.id] = true
        categories[#categories + 1] = { id = c.id, name = c.name }
      end
    end
  else
    categories = DefaultCategories()
    for _, c in ipairs(categories) do known[c.id] = true end
  end
  local recipients = {}
  if type(db.recipients) == "table" then
    for key, r in pairs(db.recipients) do
      if type(key) == "string" and type(r) == "table" and type(r.name) == "string" and r.name ~= "" then
        local cats = {}
        if type(r.cats) == "table" then
          for id, on in pairs(r.cats) do if known[id] and on == true then cats[id] = true end end
        end
        recipients[key] = { name = r.name, last = type(r.last) == "number" and r.last or 0, cats = cats }
      end
    end
  end
  local items = {}
  if type(db.items) == "table" then
    for id, a in pairs(db.items) do
      if type(id) == "number" and type(a) == "table" and type(a.cat) == "string" then
        items[id] = { cat = a.cat, who = type(a.who) == "string" and a.who or nil }
      end
    end
  end
  local own = {}
  if type(db.own) == "table" then
    for key, on in pairs(db.own) do if type(key) == "string" and on == true then own[key] = true end end
  end
  -- the account's characters by their GUID: the key each was last listed under (one character, one entry)
  local guids = {}
  if type(db.guids) == "table" then
    for guid, key in pairs(db.guids) do if type(guid) == "string" and type(key) == "string" then guids[guid] = key end end
  end
  local sort = type(db.sort) == "string" and (db.sort == "last" or known[db.sort]) and db.sort or "last"
  local nextId = type(db.nextId) == "number" and db.nextId >= 1 and math.floor(db.nextId) or 1
  return { categories = categories, recipients = recipients, items = items, own = own, sort = sort, nextId = nextId,
    open = db.open == true or nil, guids = guids }
end

function M.Init()
  ClaraMailDB = Clean(ClaraMailDB)
  M.db = ClaraMailDB
  if M.MergeFirstNames then M.MergeFirstNames() end
end

-- a name's key in the list: its letters as typed, lower case (the game's names are not case-sensitive)
local function Key(name)
  if type(name) ~= "string" then return nil end
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then return nil end
  return name:lower(), name
end
M.Key = Key

---------------------------------------------------------------------------
-- Categories
---------------------------------------------------------------------------
function M.CategoryName(id)
  for _, c in ipairs(M.db.categories) do
    if c.id == id then return c.name or L["MAIL_CAT_" .. id:upper()] or id end
  end
end

function M.Categories()
  local list = {}
  for i, c in ipairs(M.db.categories) do list[i] = { id = c.id, name = M.CategoryName(c.id) } end
  return list
end

local function Trim(text, limit)
  if type(text) ~= "string" then return nil end
  text = text:gsub("[|\n\r]", ""):gsub("^%s+", ""):gsub("%s+$", "")
  local chars = {}
  for ch in text:gmatch("[%z\1-\127\192-\255][\128-\191]*") do
    if #chars == limit then break end
    chars[#chars + 1] = ch
  end
  text = table.concat(chars)
  return text ~= "" and text or nil
end

-- Returns its id, or nil and why ("empty", "exists").
function M.AddCategory(text)
  local name = Trim(text, NAME_MAX)
  if not name then return nil, "empty" end
  for _, c in ipairs(M.Categories()) do
    if c.name:lower() == name:lower() then return nil, "exists" end
  end
  local id = "c" .. M.db.nextId
  M.db.nextId = M.db.nextId + 1
  table.insert(M.db.categories, { id = id, name = name })
  return id
end

-- Gone from the list and from every character; the items given to it keep it, doing nothing.
function M.DeleteCategory(id)
  for i, c in ipairs(M.db.categories) do
    if c.id == id then
      table.remove(M.db.categories, i)
      for _, r in pairs(M.db.recipients) do r.cats[id] = nil end
      if M.db.sort == id then M.db.sort = "last" end
      return true
    end
  end
end

-- The four first categories again, and no character in any; the items keep theirs (dormant), the
-- list of names stays. The account's characters are Main/alt again at their next login.
function M.ResetCategories()
  M.db.categories = DefaultCategories()
  for _, r in pairs(M.db.recipients) do wipe(r.cats) end
  wipe(M.db.own)
  M.db.sort = "last"
end

-- Everything as on the first day: categories, names, the items given to them.
function M.ResetAll()
  local open = M.db.open
  ClaraMailDB = Clean(nil)
  ClaraMailDB.open = open
  M.db = ClaraMailDB
end

---------------------------------------------------------------------------
-- The characters in the list
---------------------------------------------------------------------------
-- Its entry, made if new. A name typed in lower case takes the capitals of a later one.
local function Entry(name)
  local key, shown = Key(name)
  if not key then return nil end
  local r = M.db.recipients[key]
  if not r then
    r = { name = shown, last = 0, cats = {} }
    M.db.recipients[key] = r
  elseif r.name == r.name:lower() and shown ~= shown:lower() then
    r.name = shown
  end
  return r, key
end

function M.Recipient(name)
  local key = Key(name)
  return key and M.db.recipients[key]
end

-- A mail sent: that name first in Last sent.
local clock = 0 -- (two mails in the same second keep their order)
function M.Record(name)
  local r = Entry(name)
  if not r then return end
  local now = time and time() or 0
  clock = math.max(clock + 0.001, now)
  r.last = clock
end

function M.SetCategory(name, id, on)
  local r = Entry(name)
  if r and M.CategoryName(id) then r.cats[id] = on and true or nil end
end

function M.HasCategory(name, id)
  local r = M.Recipient(name)
  return r ~= nil and r.cats[id] == true
end

function M.ClearCategories(name)
  local r = M.Recipient(name)
  if r then wipe(r.cats) end
end

function M.Remove(name)
  local key = Key(name)
  if key then M.db.recipients[key] = nil end
end

-- Its categories' names, in the list's order.
function M.CategoryNames(name)
  local r, names = M.Recipient(name), {}
  if not r then return names end
  for _, c in ipairs(M.Categories()) do
    if r.cats[c.id] then names[#names + 1] = c.name end
  end
  return names
end

-- The characters of a category, newest first.
function M.Members(id)
  local list = {}
  for _, r in pairs(M.db.recipients) do
    if r.cats[id] then list[#list + 1] = r end
  end
  table.sort(list, function(a, b)
    if a.last ~= b.last then return a.last > b.last end
    return a.name:lower() < b.name:lower()
  end)
  return list
end

-- The list as shown: newest first (never mailed: by name); sorted by a category, its characters
-- first (newest first among them); the character logged in left out. Returns the list and how many of
-- it are that category's.
-- (the character logged in is left out: the game sends no mail to oneself)
local function Me()
  local me = {}
  local key = Key(ns:FullName("player"))
  if key then me[key] = true end
  local guid = UnitGUID and UnitGUID("player")
  if type(guid) == "string" and not issecretvalue(guid) and M.db.guids[guid] then me[M.db.guids[guid]] = true end
  return me
end
function M.Sorted(sort)
  sort = sort or M.db.sort
  local first, rest = {}, {}
  local me = Me()
  for key, r in pairs(M.db.recipients) do
    if not me[key] then
      if sort ~= "last" and r.cats[sort] then first[#first + 1] = r else rest[#rest + 1] = r end
    end
  end
  local function Newer(a, b)
    if a.last ~= b.last then return a.last > b.last end
    return a.name:lower() < b.name:lower()
  end
  table.sort(first, Newer)
  table.sort(rest, Newer)
  local n = #first
  for _, r in ipairs(rest) do first[#first + 1] = r end
  return first, n
end

-- One character listed twice (its first name alone, from when the game's settings hid its surname,
-- and its whole name): one entry, under the whole name, its categories, its last mail and the
-- items given to it kept.
local function Merge(from, to, shown)
  local db = M.db
  local a = db.recipients[from]
  if from == to or not a then return false end
  local b = db.recipients[to]
  if b then
    for id in pairs(a.cats) do b.cats[id] = true end
    b.last = math.max(b.last or 0, a.last or 0)
  else
    b = a
    db.recipients[to] = b
  end
  if shown then b.name = shown end
  db.recipients[from] = nil
  if db.own[from] and not db.own[to] then db.own[to] = true end
  for id, item in pairs(db.items) do
    if item.who and Key(item.who) == from then item.who = b.name end
  end
  return true
end
M.Merge = Merge

-- The account's characters listed by their first name alone: under their whole name when it is the
-- only one in the list that starts so ("Elle" and "Elle Woods": one character).
function M.MergeFirstNames()
  local merged = false
  for key in pairs(M.db.own) do
    if M.db.recipients[key] and not key:find(" ", 1, true) then
      local match, count = nil, 0
      for other in pairs(M.db.recipients) do
        if other:sub(1, #key + 1) == key .. " " then match, count = other, count + 1 end
      end
      if count == 1 and Merge(key, match) then merged = true end
    end
  end
  return merged
end

-- This character in the list as Main/alt from level 3 (once: taken off by hand, it stays off), under
-- its whole name; listed before under another name (its GUID tells), one entry again.
function M.AddOwn()
  local level = UnitLevel and UnitLevel("player")
  local name = ns:FullName("player")
  if type(name) ~= "string" then return false end
  local key = Key(name)
  if not key then return false end
  local guid = UnitGUID and UnitGUID("player")
  if type(guid) == "string" and not issecretvalue(guid) then
    local before = M.db.guids[guid]
    if before and before ~= key then Merge(before, key, name) end
    M.db.guids[guid] = key
  end
  local first = name:match("^(%S+)%s")
  if first then Merge(Key(first), key, name) end
  if M.db.recipients[key] then M.db.recipients[key].name = name end -- (the game's capitals)
  if type(level) ~= "number" or level < OWN_LEVEL or M.db.own[key] then return false end
  M.db.own[key] = true
  local r = Entry(name)
  if r then r.cats.mainalt = M.CategoryName("mainalt") and true or nil end
  return true
end
M.OWN_LEVEL = OWN_LEVEL

---------------------------------------------------------------------------
-- Export / import: the whole of it as one line of text (Profiles.lua's text form)
---------------------------------------------------------------------------
function M.Export()
  local d = M.db
  return EXPORT_PREFIX .. ns.Encode64(ns.Serialize({ v = 1, categories = d.categories, recipients = d.recipients,
    items = d.items, own = d.own, sort = d.sort, nextId = d.nextId }))
end

-- The data in a line of text, checked; nil and why when it is not one of ours.
function M.ReadExport(text)
  if type(text) ~= "string" then return nil, L.MAIL_IMPORT_BAD end
  text = text:gsub("%s", "")
  if #text > MAX_IMPORT or text:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then return nil, L.MAIL_IMPORT_BAD end
  local raw = ns.Decode64(text:sub(#EXPORT_PREFIX + 1))
  local t = raw and ns.Deserialize(raw)
  if type(t) ~= "table" or t.v ~= 1 or type(t.categories) ~= "table" then return nil, L.MAIL_IMPORT_BAD end
  return Clean(t)
end

-- Replaces this account's.
function M.Import(data)
  data.open = M.db.open
  ClaraMailDB = data
  M.db = ClaraMailDB
end

---------------------------------------------------------------------------
-- Events: the saved data, the mails sent, this character joining the list
---------------------------------------------------------------------------
local sending -- the name a mail is being sent to (SendMail), recorded once it went
local watch = CreateFrame("Frame")
watch:RegisterEvent("ADDON_LOADED")
watch:SetScript("OnEvent", function(self, event, arg)
  if event == "ADDON_LOADED" then
    if arg ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    M.Init()
    self:RegisterEvent("PLAYER_LOGIN")
  elseif event == "PLAYER_LOGIN" then
    self:UnregisterEvent("PLAYER_LOGIN")
    if not M.AddOwn() and UnitLevel and (UnitLevel("player") or 0) < OWN_LEVEL then
      self:RegisterEvent("PLAYER_LEVEL_UP") -- (once level 3, not watched any more)
    end
    self:RegisterEvent("MAIL_SHOW")
  elseif event == "PLAYER_LEVEL_UP" then
    if (tonumber(arg) or 0) >= OWN_LEVEL then
      self:UnregisterEvent("PLAYER_LEVEL_UP")
      if C_Timer and C_Timer.After then C_Timer.After(0, M.AddOwn) else M.AddOwn() end -- (UnitLevel up to date)
    end
  elseif event == "MAIL_SHOW" then
    self:RegisterEvent("MAIL_SEND_SUCCESS")
    self:RegisterEvent("MAIL_FAILED")
    self:RegisterEvent("MAIL_CLOSED")
    if M.OnShow then M.OnShow() end
  elseif event == "MAIL_CLOSED" then
    self:UnregisterEvent("MAIL_SEND_SUCCESS")
    self:UnregisterEvent("MAIL_FAILED")
    self:UnregisterEvent("MAIL_CLOSED")
    sending = nil
    if M.OnClose then M.OnClose() end
  elseif event == "MAIL_SEND_SUCCESS" then
    if sending then M.Record(sending) end
    sending = nil
    if M.Changed then M.Changed() end
  elseif event == "MAIL_FAILED" then
    sending = nil
  end
end)
if SendMail then hooksecurefunc("SendMail", function(name) sending = name end) end
