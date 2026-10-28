-- Clara Combo Points - MinimapDrawer in the Improvements tab: its two switches (the drawer opening
-- when the level circle is hovered; a double middle-click on the portrait reloading the
-- interface), and its drawer for the rest (the delay, the padlock to move it).

local ADDON, ns = ...

local function Settings() return ns.MinimapDrawerSettings and ns.MinimapDrawerSettings() end

ns:SetQolSwitches("minimapdrawer", {
  { label = "MMD_SW_HOVER",
    get = function() local db = Settings() return db ~= nil and db.autoopen ~= false end,
    set = function(on)
      local db = Settings()
      if not db then return end
      db.autoopen = on and true or false
      if not on and ns.MinimapDrawerCancelHover then ns.MinimapDrawerCancelHover() end
    end },
  { label = "MMD_SW_PORTRAIT",
    get = function() local db = Settings() return db ~= nil and db.portraitReload ~= false end,
    set = function(on)
      local db = Settings()
      if db then db.portraitReload = on and true or false end
    end },
})
ns:SetQolOpener("minimapdrawer", function()
  if ns.MinimapDrawerToggle then ns.MinimapDrawerToggle() end
end)
