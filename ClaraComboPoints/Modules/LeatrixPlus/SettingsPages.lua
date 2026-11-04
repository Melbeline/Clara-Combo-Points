-- Clara Combo Points - Leatrix Plus's options in the game's own options menu (Esc > Options > AddOns > Clara >
-- Interface > Leatrix Plus), with the game's controls: its check boxes, sliders and dropdowns, the same as the game's
-- own pages. A page per page of its window (Automation, Social, Chat, Text, Interface, Frames, System, Settings),
-- its headings as the game's section headers; under an option with a gear, the settings of its configuration panel
-- (greyed out while the option is off), then a button to that panel for what a page cannot show (lists, text,
-- positions). Each row works the option's own control in its window (Leatrix_Plus.lua keeps them: its mirror), so
-- every option does exactly what it does there. Its main page: its window, and the reload some options need.
local _, ClaraNS = ...
if not ClaraNS.LeatrixPlus then return end
local Leatrix_Plus = ClaraNS.LeatrixPlus

-- The pages of its window, in its order (Home and Media have no options)
local PAGES = { "Page1", "Page2", "Page3", "Page4", "Page5", "Page6", "Page7", "Page8" }
local PAGE_TITLES = { Page1 = "Automation", Page2 = "Social", Page3 = "Chat", Page4 = "Text", Page5 = "Interface",
  Page6 = "Frames", Page7 = "System", Page8 = "Settings" }

local function RelayoutVisible()
  local list = SettingsPanel and SettingsPanel.GetSettingsList and SettingsPanel:GetSettingsList()
  local box = list and list.ScrollBox
  if box and box.ForEachFrame then
    box:ForEachFrame(function(frame) if frame.EvaluateState then pcall(frame.EvaluateState, frame) end end)
  end
end

function Leatrix_Plus.BuildSettingsPages()
  local m = Leatrix_Plus.mirror
  local parentCategory = ClaraNS:QolCategory("leatrix")
  if not (m and parentCategory and Settings and Settings.RegisterVerticalLayoutSubcategory and Settings.RegisterProxySetting
    and Settings.CreateCheckbox and Settings.CreateSlider and Settings.CreateDropdown) then return nil end
  local LC, CB, L = m.LC, m.CB, m.L
  local CL = ClaraNS.L
  local function Text(key) local t = key and L[key]; return (type(t) == "string" and t ~= "") and t or key end

  -- which page or panel a control is on
  local pageOf = {}
  for _, page in ipairs(PAGES) do if LC[page] then pageOf[LC[page]] = page end end
  local function Owner(frame)
    for _ = 1, 8 do
      if not frame then return nil end
      if pageOf[frame] or m.panels[frame] then return frame end
      frame = frame.GetParent and frame:GetParent() or nil
    end
  end
  local byOwner = {}
  for _, c in ipairs(m.controls) do
    local owner = Owner(c.parent)
    if owner then
      byOwner[owner] = byOwner[owner] or {}
      table.insert(byOwner[owner], c)
    end
  end
  -- a configuration panel's option: the main check box of the same caption
  local panelsOf = {}
  for _, panel in ipairs(m.panelList) do
    local title = m.panels[panel].title
    if title then
      panelsOf[title] = panelsOf[title] or {}
      table.insert(panelsOf[title], panel)
    end
  end

  local main, mainLayout = Settings.RegisterVerticalLayoutSubcategory(parentCategory, Text("Leatrix Plus"))
  local function Button(layout, label, text, onClick, tooltip)
    if CreateSettingsButtonInitializer and layout and layout.AddInitializer then
      layout:AddInitializer(CreateSettingsButtonInitializer(label, text, onClick, tooltip, false))
    end
  end
  local function Header(layout, text)
    if CreateSettingsListSectionHeaderInitializer and layout and layout.AddInitializer then
      layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end
  end
  local function Reload() if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end end
  Button(mainLayout, Text("Leatrix Plus"), CL.LEAPLUS_OPEN_WINDOW, function()
    if SettingsPanel and SettingsPanel:IsShown() then pcall(HideUIPanel, SettingsPanel) end
    if Leatrix_Plus.Open then Leatrix_Plus.Open() end
  end, CL.LEAPLUS_OPEN_WINDOW_TIP)
  Button(mainLayout, "", CL.RELOAD_UI, Reload, CL.LEAPLUS_RELOAD_TIP)

  local made = { pages = {}, rows = 0 }
  Leatrix_Plus.settingsPages = made

  local registered = {}
  local function Register(category, c, kind, default, set)
    if registered[c.field] then return nil end -- (one row per option, where it first shows)
    registered[c.field] = true
    return Settings.RegisterProxySetting(category, "ClaraLeaPlus_" .. c.field, kind, c.label, default,
      function()
        local v = LC[c.field]
        if kind == Settings.VarType.Boolean then return v == "On" end
        if v == nil then return default end
        return v
      end,
      function(v)
        set(v)
        RelayoutVisible()
      end)
  end

  local function Check(category, c, tooltip)
    local default = m.defaults[c.field] == "On"
    local setting = Register(category, c, Settings.VarType.Boolean, default, function(v)
      local box = CB[c.field]
      if box and box.SetChecked and box.GetScript then
        box:SetChecked(v and true or false)
        local click = box:GetScript("OnClick")
        if click then click(box, "LeftButton") else LC[c.field] = v and "On" or "Off" end
      else
        LC[c.field] = v and "On" or "Off"
      end
    end)
    if not setting then return nil end
    made.rows = made.rows + 1
    return Settings.CreateCheckbox(category, setting, tooltip)
  end

  local function Slider(category, c, tooltip)
    local default = tonumber(m.defaults[c.field]) or tonumber(LC[c.field]) or c.low
    local setting = Register(category, c, Settings.VarType.Number, default, function(v)
      local slider = CB[c.field]
      if slider and slider.SetValue then slider:SetValue(v) else LC[c.field] = v end
    end)
    local options = Settings.CreateSliderOptions(c.low, c.high, c.step)
    local label = MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label
    if options.SetLabelFormatter and label and label.Right then
      options:SetLabelFormatter(label.Right, function(v)
        local ok, s = pcall(string.format, c.form or "%.0f", v)
        return ok and s or tostring(v)
      end)
    end
    if not setting then return nil end
    made.rows = made.rows + 1
    return Settings.CreateSlider(category, setting, options, tooltip)
  end

  local function Dropdown(category, c)
    local items = c.items or {}
    local first = items[1] and items[1][2]
    local kind = type(first) == "number" and Settings.VarType.Number or Settings.VarType.String
    local default = m.defaults[c.field] or LC[c.field] or first
    local setting = Register(category, c, kind, default, function(v)
      LC[c.field] = v
      local dropdown = CB[c.field]
      if dropdown then
        if dropdown.SignalUpdate then pcall(dropdown.SignalUpdate, dropdown) end
        if dropdown.TriggerEvent and DropdownButtonMixin and DropdownButtonMixin.Event then
          pcall(dropdown.TriggerEvent, dropdown, DropdownButtonMixin.Event.OnMenuClose, dropdown)
        end
      end
    end)
    local function Options()
      local container = Settings.CreateControlTextContainer()
      for _, item in ipairs(items) do container:Add(item[2], tostring(item[1])) end
      return container:GetData()
    end
    if not setting then return nil end
    made.rows = made.rows + 1
    return Settings.CreateDropdown(category, setting, Options)
  end

  local function Parent(init, parentInit, field)
    if not init then return end
    local function on() return LC[field] == "On" end
    if parentInit and init.SetParentInitializer then
      init:SetParentInitializer(parentInit, on)
    elseif init.AddModifyPredicate then
      init:AddModifyPredicate(on)
    end
  end

  -- a configuration panel's own settings, under its option
  local function PanelRows(category, layout, panel, optionInit, optionField)
    local lastHeading
    for _, c in ipairs(byOwner[panel] or {}) do
      if c.kind == "heading" then
        lastHeading = Text(c.caption)
      elseif c.kind == "check" and c.field then
        c.label = Text(c.caption)
        Parent(Check(category, c, c.tip and Text(c.tip) or nil), optionInit, optionField)
      elseif c.kind == "slider" and c.field and CB[c.field] then
        c.label = lastHeading or Text(c.tip)
        Parent(Slider(category, c, c.tip and Text(c.tip) or nil), optionInit, optionField)
      elseif c.kind == "dropdown" and c.field then
        c.label = Text(c.caption)
        Parent(Dropdown(category, c), optionInit, optionField)
      end
    end
  end

  for _, page in ipairs(PAGES) do
    local frame = LC[page]
    local controls = frame and byOwner[frame]
    if controls and #controls > 0 then
      local category, layout = Settings.RegisterVerticalLayoutSubcategory(main, Text(PAGE_TITLES[page]))
      made.pages[#made.pages + 1] = { page = page, category = category, layout = layout }
      for _, c in ipairs(controls) do
        if c.kind == "heading" then
          Header(layout, Text(c.caption))
        elseif c.kind == "check" and c.field then
          c.label = Text(c.caption) .. (c.reload and "*" or "")
          local tip = c.tip and Text(c.tip) or ""
          if c.reload then tip = tip .. "|n|n* " .. Text("Requires UI reload.") end
          local init = Check(category, c, tip)
          local box = CB[c.field]
          if init and init.AddModifyPredicate and box and box.IsEnabled then
            init:AddModifyPredicate(function() return box:IsEnabled() and true or false end) -- (as its window locks it)
          end
          -- its configuration panel: its settings here, then a button to the panel itself
          local gear = box and m.gears[box]
          if gear and panelsOf[c.caption] then -- (its panel is made once the option is on: after the reload it asks)
            for _, panel in ipairs(panelsOf[c.caption] or {}) do PanelRows(category, layout, panel, init, c.field) end
            Button(layout, "", CL.LEAPLUS_MORE, function()
              local button = CB[gear]
              local click = button and button.GetScript and button:GetScript("OnClick")
              if click then click(button, "LeftButton") end
            end, CL.LEAPLUS_MORE_TIP)
          end
        end
      end
      Button(layout, "", CL.RELOAD_UI, Reload, CL.LEAPLUS_RELOAD_TIP)
    end
  end
  return main
end
