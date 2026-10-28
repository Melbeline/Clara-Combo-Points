local _, ClaraNS = ...
local E = ClaraNS.WST
if not E then return end -- (Clara Combo Points, QoL.lua: the module does not run)
setfenv(1, E.env) -- its globals are its own (Env.lua)
local addon_name, addon_data = "ClaraWST", E.data
local CL = ClaraNS.L

-- Clara Combo Points: the settings of the boxes over the target and focus frames (UnitBoxes.lua),
-- kept with the range's (the profile's range section), and their tab in the module's options:
--   the target's attack speed, a hunter's by default; its box pulsing orange the first seconds when
--   it is fast (1.2 s or less), flashing dark yellow when slow (over 2 s), against NPCs only;
--   the distance's box (the Range panel's box too);
--   a boss's swing timer: a mark across its name bar, its color and opacity, before or behind the
--   name.

local FAST, SLOW = 1.2, 2.0
local DEFAULTS = {
    speed_flash = true, speed_flash_time = 5,
    boss_swing = true, boss_swing_front = true,
    boss_swing_r = 1, boss_swing_g = 1, boss_swing_b = 1, boss_swing_a = 0.9,
}
for key, value in pairs(DEFAULTS) do addon_data.range.default_settings[key] = value end

local function Settings() return character_range_settings or {} end
local function Changed()
    if E.OnRangeBoxChanged then E.OnRangeBoxChanged() end
    if addon_data.frames and addon_data.frames.UpdatePanel then addon_data.frames.UpdatePanel() end
end

addon_data.frames = {}

-- The attack speed box: unticked nowhere, a hunter's by default (as the distance's)
E.SpeedBoxOn = function()
    local on = Settings().speed_box
    if on == nil then on = addon_data.utils.PlayerClass() == "HUNTER" end
    return on and true or false
end
E.SetSpeedBox = function(on)
    if not character_range_settings then return end
    character_range_settings.speed_box = on and true or false
    Changed()
end

-- Its pulse and flash: on, for how long; the speeds that start them
E.SpeedFlash = function()
    local s = Settings()
    return s.speed_flash ~= false, tonumber(s.speed_flash_time) or DEFAULTS.speed_flash_time
end
E.SPEED_FAST, E.SPEED_SLOW = FAST, SLOW

-- A boss's swing timer on its name bar: on, its color and opacity, before the name (or behind it)
E.BossSwing = function()
    local s = Settings()
    return s.boss_swing ~= false, s.boss_swing_r or 1, s.boss_swing_g or 1, s.boss_swing_b or 1,
        s.boss_swing_a or DEFAULTS.boss_swing_a, s.boss_swing_front ~= false
end
E.SetBossSwing = function(on)
    if not character_range_settings then return end
    character_range_settings.boss_swing = on and true or false
    Changed()
end

---------------------------------------------------------------------------
-- The tab: "Target and focus frames"
---------------------------------------------------------------------------
local function Header(panel, text, y)
    local header = addon_data.config.TextFactory(panel, text, 16)
    header:SetPoint("TOPLEFT", 10, y)
    header:SetTextColor(1, 0.82, 0, 1)
    return header
end

local function Check(panel, name, label, tip, y, onClick)
    local box = addon_data.config.CheckBoxFactory(name, panel, label, tip, onClick)
    box:SetPoint("TOPLEFT", 10, y)
    return box
end

addon_data.frames.UpdatePanel = function()
    local panel = addon_data.frames.panel
    local s = character_range_settings
    if not panel or not s then return end
    panel.speed_box:SetChecked(E.SpeedBoxOn())
    panel.speed_flash:SetChecked(s.speed_flash ~= false)
    panel.speed_flash_time:SetValue(tonumber(s.speed_flash_time) or DEFAULTS.speed_flash_time)
    panel.range_box:SetChecked(addon_data.range.FrameBoxOn())
    panel.boss_swing:SetChecked(s.boss_swing ~= false)
    panel.boss_front:SetChecked(s.boss_swing_front ~= false)
    panel.boss_alpha:SetValue(s.boss_swing_a or DEFAULTS.boss_swing_a)
    panel.boss_color.foreground:SetColorTexture(s.boss_swing_r or 1, s.boss_swing_g or 1, s.boss_swing_b or 1,
        s.boss_swing_a or DEFAULTS.boss_swing_a)
end

addon_data.frames.CreateConfigPanel = function(parent_panel)
    local panel = CreateFrame("Frame", addon_name .. "FramesConfigPanel", parent_panel)
    addon_data.frames.panel = panel

    panel.title_text = addon_data.config.TextFactory(panel, CL.WST_TAB_FRAMES, 20)
    panel.title_text:SetPoint("TOPLEFT", 10, -10)
    panel.title_text:SetTextColor(1, 0.82, 0, 1)
    panel.intro = addon_data.config.TextFactory(panel, CL.WST_FRAMES_INTRO, 11)
    panel.intro:SetPoint("TOPLEFT", 10, -38)
    panel.intro:SetWidth(580)
    panel.intro:SetJustifyH("LEFT")

    -- the attack speed
    Header(panel, CL.WST_HEAD_SPEED, -70)
    panel.speed_box = Check(panel, "SpeedBoxCheckBox", CL.WST_SW_SPEED_BOX, CL.WST_SW_SPEED_BOX_TIP, -95, function(self)
        E.SetSpeedBox(self:GetChecked())
    end)
    panel.speed_flash = Check(panel, "SpeedFlashCheckBox", CL.WST_SPEED_FLASH, CL.WST_SPEED_FLASH_TIP, -120, function(self)
        character_range_settings.speed_flash = self:GetChecked() and true or false
        Changed()
    end)
    panel.speed_flash_time = addon_data.config.SliderFactory("SpeedFlashTimeSlider", panel, CL.WST_SPEED_FLASH_TIME,
        1, 30, 1, function(self)
            local value = addon_data.utils.SimpleRound(self:GetValue(), 1)
            if character_range_settings and character_range_settings.speed_flash_time ~= value then
                character_range_settings.speed_flash_time = value
                if E.OnRangeBoxChanged then E.OnRangeBoxChanged() end
            end
        end)
    panel.speed_flash_time:SetPoint("TOPLEFT", 22, -165)

    -- the distance (as in the Range panel)
    Header(panel, CL.WST_HEAD_RANGE, -205)
    panel.range_box = Check(panel, "FramesRangeBoxCheckBox", CL.WST_SW_RANGE_BOX, CL.WST_SW_RANGE_BOX_TIP, -230, function(self)
        addon_data.range.SetFrameBox(self:GetChecked())
        if addon_data.range.UpdateConfigPanelValues then addon_data.range.UpdateConfigPanelValues() end
    end)

    -- a boss's swing timer
    Header(panel, CL.WST_HEAD_BOSS, -270)
    panel.boss_swing = Check(panel, "BossSwingCheckBox", CL.WST_SW_BOSS_SWING, CL.WST_SW_BOSS_SWING_TIP, -295, function(self)
        E.SetBossSwing(self:GetChecked())
    end)
    panel.boss_front = Check(panel, "BossFrontCheckBox", CL.WST_BOSS_FRONT, CL.WST_BOSS_FRONT_TIP, -320, function(self)
        character_range_settings.boss_swing_front = self:GetChecked() and true or false
        Changed()
    end)
    panel.boss_color = addon_data.config.color_picker_factory("BossSwingColor", panel, 1, 1, 1, 0.9, CL.WST_BOSS_COLOR,
        function(self)
            addon_data.config.ShowColorPicker(character_range_settings, "boss_swing", self.foreground, Changed)
        end)
    panel.boss_color:SetPoint("TOPLEFT", 20, -355)
    panel.boss_alpha = addon_data.config.SliderFactory("BossSwingAlphaSlider", panel, CL.WST_BOSS_ALPHA, 0, 1, 0.05,
        function(self)
            local value = addon_data.utils.SimpleRound(self:GetValue(), 0.05)
            if character_range_settings and character_range_settings.boss_swing_a ~= value then
                character_range_settings.boss_swing_a = value
                local s = character_range_settings
                panel.boss_color.foreground:SetColorTexture(s.boss_swing_r or 1, s.boss_swing_g or 1, s.boss_swing_b or 1, value)
                if E.OnRangeBoxChanged then E.OnRangeBoxChanged() end
            end
        end)
    panel.boss_alpha:SetPoint("TOPLEFT", 230, -355)
    panel.boss_note = addon_data.config.TextFactory(panel, CL.WST_BOSS_NOTE, 11)
    panel.boss_note:SetPoint("TOPLEFT", 10, -395)
    panel.boss_note:SetWidth(580)
    panel.boss_note:SetJustifyH("LEFT")

    panel:SetSize(620, 440)
    panel:SetScript("OnShow", addon_data.frames.UpdatePanel)
    addon_data.frames.UpdatePanel()
    return panel
end
