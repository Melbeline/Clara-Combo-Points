-- Clara Combo Points - the classic quest log opened by the game's quest log key (each key bound to it: an override
-- binding, set out of combat) and by the quest log micro button (an unseen button over it takes its click), in place
-- of the map's quest panel. The world map's own key, the tracker's clicks and the map's quest panel stay the game's.

local ADDON, ns = ...
local Q = ns.QuestLogPrivate
if not Q then return end -- (the module is off: QuestLogCore.lua)

local TOGGLE_NAME = "ClaraQuestLogToggle" -- (clicked by name by the override binding)

-- A plain button the key clicks (our own window: nothing protected, it opens in combat too)
local toggle = CreateFrame("Button", TOGGLE_NAME, UIParent)
toggle:SetSize(1, 1)
toggle:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
toggle:EnableMouse(false)
toggle:RegisterForClicks("AnyUp")
toggle:SetScript("OnClick", function(_, _, down) if not down then Q.Toggle() end end) -- (the key's release, once)

-- The quest log key's keys, bound to ours (again only when they changed: the binding's own change is heard too)
local bound = ""
local function UpdateBinding()
  if InCombatLockdown() then return end
  local keys = {}
  for _, key in ipairs({ GetBindingKey("TOGGLEQUESTLOG") }) do
    if type(key) == "string" and key ~= "" then keys[#keys + 1] = key end
  end
  local now = table.concat(keys, "\001")
  if now == bound then return end
  ClearOverrideBindings(toggle)
  for _, key in ipairs(keys) do SetOverrideBindingClick(toggle, true, key, TOGGLE_NAME, "LeftButton") end
  bound = now
end
Q.UpdateBinding = UpdateBinding -- (for the tests)

-- The micro button's tooltip, written by us (its own OnEnter left to the game)
local function MicroEnter(pad)
  local button = QuestLogMicroButton
  local normal = button.GetNormalTexture and button:GetNormalTexture()
  if normal then normal:SetAlpha(0) end -- (the game's: its shadow is in its highlight)
  GameTooltip:SetOwner(pad, "ANCHOR_RIGHT")
  local text = button.tooltipText
  if type(text) ~= "string" or Q.IsSecret(text) then text = QUESTLOG_BUTTON or QUEST_LOG or "Quest Log" end
  if GameTooltip_SetTitle then GameTooltip_SetTitle(GameTooltip, text) else GameTooltip:SetText(text, 1, 1, 1) end
  GameTooltip:Show()
end
local function MicroLeave()
  local normal = QuestLogMicroButton.GetNormalTexture and QuestLogMicroButton:GetNormalTexture()
  if normal then normal:SetAlpha(1) end
  GameTooltip:Hide()
end

-- The pad stays away while the micro row is edited (Edit Mode) or keys are bound on it (quick keybind mode)
local function MicroWanted()
  if EditModeManagerFrame and EditModeManagerFrame:IsShown() then return false end
  if KeybindFrames_InQuickKeybindMode and KeybindFrames_InQuickKeybindMode() then return false end
  return true
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("UPDATE_BINDINGS")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" and QuestLogMicroButton then
    Q.microPad = Q.Pad(QuestLogMicroButton, { onClick = function() Q.Toggle() end, when = MicroWanted,
      enter = MicroEnter, leave = MicroLeave })
  end
  UpdateBinding()
end)
