-- Clara Combo Points - Clique 5.1.5 (by Cladhaire), built in (QoL.lua): click-casting on the unit frames. The
-- first of the module's files: it tells the others whether they run and gives them their shared table. They run
-- only when the module does: in WoW Forever, not turned off, and the standalone Clique not enabled.
-- Its settings are saved in ClaraCliqueDB. The bindings already made with the standalone Clique (its CliqueDB3, in
-- the WTF folder) are carried over: while Clique itself runs (the first login with Clara, before Clara takes over
-- from it), its data is copied at login and logout; the first time whole, then only this character's own part
-- (its profile, its settings, the profiles new since), so that what was changed with the built-in one on another
-- character is kept. Clara's own addition: a binding can be kept off the target frame ("Not on the target frame"
-- in the binding's page: core/attributes.lua, config/EditPage.lua).

local ADDON, ns = ...

ns.CliqueRuns = ns:QolRuns("clique")
if ns.CliqueRuns then
  ns.CliquePrivate = {} -- (the standalone's own `...` table)
  ns.CliqueHost = ADDON  -- (the addon whose loading starts it: this one)
  local META = { Title = "Clique", Version = "v5.1.5-release", Author = "Cladhaire",
    Notes = "Simply powerful click-casting interface" }
  ns.CliqueMetadata = function(_, field) return META[field] end
elseif ns:QolState("clique") == "standalone" then
  local function Copy(t) return CopyTable and CopyTable(t) or t end
  local function Carry()
    local src = _G.CliqueDB3
    if type(src) ~= "table" then return end
    if type(ClaraCliqueDB) ~= "table" or next(ClaraCliqueDB) == nil then
      ClaraCliqueDB = Copy(src)
      return
    end
    local dst = ClaraCliqueDB
    dst.profileKeys, dst.profiles, dst.char = dst.profileKeys or {}, dst.profiles or {}, dst.char or {}
    -- (this character as AceDB names it: "First Surname" where names are unique by region, as on WoW Forever,
    -- else "First - Realm")
    local mine = { ("%s - %s"):format(UnitName("player") or "?", GetRealmName and GetRealmName() or "?") }
    if UnitNameUnmodified then
      local first, surname = UnitNameUnmodified("player")
      if type(first) == "string" then mine[#mine + 1] = surname and (first .. " " .. tostring(surname)) or first end
    end
    for _, me in ipairs(mine) do
      local profile = type(src.profileKeys) == "table" and src.profileKeys[me]
      if profile then
        dst.profileKeys[me] = profile
        if type(src.profiles) == "table" and type(src.profiles[profile]) == "table" then
          dst.profiles[profile] = Copy(src.profiles[profile])
        end
      end
      if type(src.char) == "table" and type(src.char[me]) == "table" then dst.char[me] = Copy(src.char[me]) end
    end
    for name, p in pairs(type(src.profiles) == "table" and src.profiles or {}) do
      if dst.profiles[name] == nil and type(p) == "table" then dst.profiles[name] = Copy(p) end
    end
  end
  ns.CliqueCarry = Carry -- (for the tests)
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:RegisterEvent("PLAYER_LOGOUT")
  f:SetScript("OnEvent", Carry)
end
