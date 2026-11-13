local _, ClaraNS = ... -- (Clara Combo Points: ClassicUI Forever built in, QoL.lua)
if not (type(ClaraNS) == "table" and ClaraNS.ClassicUIRuns) then return end
local ns = ClaraNS.ClassicUIPrivate

-- Old trainer window on the skill shell, inside the client's; its list, button and money stay under ours.

local active = false
local panel
local LIST_ROWS = 9
local lines, collapsed = {}, {}
local selected

local SkillList = ns.SkillList
local SetAlphaIf, SetScaleIf, SetLevelIf, SetPointIf = ns.SetAlphaIf, ns.SetScaleIf, ns.SetLevelIf, ns.SetPointIf
local IsSecret = ns.IsSecret

local KIND_COLOR = {
    available = { 0.1, 1, 0.1 },
    unavailable = { 1, 0.1, 0.1 },
    used = { 0.5, 0.5, 0.5 },
}

-- Client pieces ours stands in for
-- (not its training points: a pet trainer shows them in the money's place, the client's own, raised over ours as
-- its money is: Era's "Training Points: N" by Train)
local CLIENT_PIECES = { "FilterDropdown", "FilterInputHint", "TrainButton", "skillStepButton",
    "bottomInset", "BG", "Inset" }
local CLIENT_SHRUNK = { "ScrollBox", "ScrollBar" }
local CHANGED = { changed = true }
local FOOT_EDGE = { "TopEdge", "TopLeftCorner", "TopRightCorner" }
local TRAINER_EVENTS = { "TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_CLOSED", "TRAINER_DESCRIPTION_UPDATE",
    "TRAINER_SERVICE_INFO_NAME_UPDATE", "PLAYER_MONEY", "UNIT_PET_TRAINING_POINTS", "SPELLS_CHANGED" }

-- A rank's number in its line ("Rank 2", "Rang 2"); nil without one
local function RankOf(sub)
    if type(sub) ~= "string" or IsSecret(sub) then return nil end
    return tonumber(sub:match("(%d+)"))
end

-- A pet trainer: what the pet knows already, from its own spellbook. WoW Forever's pet trainer gives an ability the
-- pet has as "available" (green, Train on), Era's gave it as "used" (grey, Already Known). Each ability's highest
-- rank known (0: known, its rank not told); a rank at or under it is known.
local function PetKnows()
    local trainerType = C_Trainer and C_Trainer.GetTrainerType and C_Trainer.GetTrainerType()
    if not (Enum and Enum.TrainerType and trainerType == Enum.TrainerType.Pet) then return nil end
    local book = C_SpellBook
    if not (book and book.HasPetSpells and book.GetSpellBookItemName and Enum.SpellBookSpellBank) then return nil end
    local count = book.HasPetSpells()
    if type(count) ~= "number" or IsSecret(count) then return nil end
    local known = {}
    for slot = 1, count do
        local name, sub = book.GetSpellBookItemName(slot, Enum.SpellBookSpellBank.Pet)
        if type(name) == "string" and not IsSecret(name) then
            local rank = RankOf(sub) or 0
            if (known[name] or -1) < rank then known[name] = rank end
        end
    end
    return known
end

-- Known to the pet: its rank at or under the pet's (a line without a rank: the ability known at all)
local function PetHas(known, name, sub)
    local have = known and type(name) == "string" and not IsSecret(name) and known[name]
    if not have then return false end
    local rank = RankOf(sub)
    if rank then return have >= rank end
    return true
end

local function Services()
    local count = GetNumTrainerServices and GetNumTrainerServices() or 0
    local order, groups = {}, {}
    local petKnows = PetKnows()
    local showUsed = not GetTrainerServiceTypeFilter or GetTrainerServiceTypeFilter("used")
    for index = 1, count do
        local name, kind, texture, level, sub, category = GetTrainerServiceInfo(index)
        local hidden = false
        if name and petKnows and kind ~= "used" and PetHas(petKnows, name, sub) then
            kind = "used"
            hidden = not showUsed -- (Already Known unticked in the filter)
        end
        if name and not hidden then
            if not category or category == "" then category = OTHER or "Other" end
            if not groups[category] then
                groups[category] = {}
                order[#order + 1] = category
            end
            local group = groups[category]
            group[#group + 1] = { index = index, name = name, kind = kind, texture = texture, level = level, sub = sub }
        end
    end
    return order, groups
end

ns.TrainerServices = Services -- (for the tests)

local function Collect()
    wipe(lines)
    local order, groups = Services()
    for _, category in ipairs(order) do
        lines[#lines + 1] = { header = true, id = category, name = category }
        if not collapsed[category] then
            for _, service in ipairs(groups[category]) do lines[#lines + 1] = service end
        end
    end
end

local function ServiceByIndex(index)
    for _, line in ipairs(lines) do
        if not line.header and line.index == index then return line end
    end
end

local UpdateDetail

-- Scroll column only when the list overflows, as Era's
local function FitList()
    local over = math.max(0, #lines - LIST_ROWS)
    panel.bar:SetRange(over)
    panel.listBox:SetPoint("RIGHT", panel, "RIGHT", over > 0 and panel.listRight or 0, 0)
end

local function DrawItem(row, line)
    row.toggle:Hide()
    row.text:SetPoint("LEFT", row, "LEFT", 33, 0)
    local label = line.name
    if line.sub and line.sub ~= "" then label = label .. " (" .. line.sub .. ")" end
    row.text:SetText(label)
    local color = KIND_COLOR[line.kind] or KIND_COLOR.used
    if line.index == selected then
        row.selectedTex:SetVertexColor(unpack(color))
        row.selectedTex:Show()
        row.text:SetTextColor(1, 1, 1)
    else
        row.selectedTex:Hide()
        row.text:SetTextColor(unpack(color))
    end
end

local function UpdateRows()
    if not panel then return end
    SkillList.Draw(panel, lines, collapsed, DrawItem)
    SkillList.FoldIcon(panel, lines, collapsed)
end

-- BuyTrainerService is refused to addons: a pad clicks the client's row for our pick, then its Train.
local TRAIN_ROW, TRAIN_GO = "ClassicUIForeverTrainRow", "ClassicUIForeverTrainGo"
local TRAIN_MACRO = "/click " .. TRAIN_ROW .. "\n/click " .. TRAIN_GO
local trainProxies, listWrap

-- Rows exist only inside the client's 330-tall list: the press stretches it in its own secure run,
-- so the client builds our pick's row itself. Release or leave puts the height back.
local LIST_TALL = [[
    if not down then return nil, "back" end
    local list, tall = control:GetFrameRef("list"), control:GetAttribute("tall")
    if not (list and tall) or PlayerInCombat() then return end
    if not control:GetAttribute("listh") then control:SetAttribute("listh", list:GetHeight()) end
    list:SetHeight(tall)
    list:GetHeight() -- measured here, so the rows are built in this run
]]
local LIST_BACK = [[
    local list, h = control:GetFrameRef("list"), control:GetAttribute("listh")
    if not (list and h) or PlayerInCombat() then return end
    list:SetHeight(h)
    list:GetHeight()
    control:SetAttribute("listh", nil)
]]

local function ClientSelection()
    local frame = ClassTrainerFrame
    local shown = frame and frame.selectedService
    if not shown then return nil end
    local map = frame.displayIndexToSkillIndex
    return (map and map[shown]) or shown
end

local wantedRow, foundRow
-- Forever marks a row with its display index; retail's rows only carry the service's index as their ID.
local function MatchRow(row)
    if foundRow then return end
    if row.displayIndex ~= nil then
        if row.displayIndex == wantedRow and issecurevariable(row, "displayIndex") then foundRow = row end
    elseif row.GetID and row:GetID() == wantedRow then
        foundRow = row
    end
end

-- The client's row for our pick (its list is shrunk, not hidden, so rows stand)
local function ClientRow()
    local frame = ClassTrainerFrame
    local box = frame and frame.ScrollBox
    if not (selected and box and box.ForEachFrame) then return nil end
    -- A profession's next rank sits on the client's step button, not in its list.
    local step, stepIndex = frame.skillStepButton, _G.GetTrainerServiceStepIndex
    if step and stepIndex and stepIndex() == selected then
        if step:IsShown() and issecurevariable(step, "displayIndex") then return step end
        return nil
    end
    local map = frame.skillIndexToDisplayIndex
    wantedRow, foundRow = (map and map[selected]) or selected, nil
    box:ForEachFrame(MatchRow)
    return foundRow
end

-- The client's Train button and money: Forever keys them, retail only names them.
local function ClientTrain()
    return ClassTrainerFrame and (ClassTrainerFrame.TrainButton or _G.ClassTrainerTrainButton)
end
local function ClientMoney()
    return ClassTrainerFrame and (ClassTrainerFrame.money or _G.ClassTrainerFrameMoneyFrame)
end

local function TrainWanted()
    return active and selected ~= nil and panel ~= nil and panel.train:IsEnabled()
end

-- Room for every service and header at the client's row height.
local function TallHeight()
    return (2 * GetNumTrainerServices() + 1) * (_G.CLASS_TRAINER_SKILL_HEIGHT or 47)
end

-- Row, then Train. No clicks without the row; no pad unless our pick can train.
local function TrainMacro()
    if not TrainWanted() then return nil end
    local row, go = ClientRow(), ClientTrain()
    if not (row and go) then return "" end
    trainProxies = trainProxies or { ns.ClickProxy(TRAIN_ROW), ns.ClickProxy(TRAIN_GO) }
    ns.SetAttributeIf(trainProxies[1], "clickbutton", row)
    ns.SetAttributeIf(trainProxies[2], "clickbutton", go)
    return TRAIN_MACRO
end

-- Down: does this press need the tall list. Up: aim again, on the rows the down built.
local function Pad_PreClick(pad, _, down)
    if InCombatLockdown() then return end
    if down then
        listWrap:SetAttribute("tall", TrainWanted() and not ClientRow() and TallHeight() or false)
    else
        ns.SetAttributeIf(pad, "macrotext", TrainMacro() or "")
    end
end

-- Wrapped on its first look, out of combat: a pad made after a fight exists no sooner
local function PadMacro()
    local pad = ns.PadOf(panel.train)
    if pad and not listWrap then
        listWrap = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
        listWrap:SetFrameRef("list", ClassTrainerFrame.ScrollBox)
        SecureHandlerWrapScript(pad, "OnClick", listWrap, LIST_TALL, LIST_BACK)
        SecureHandlerWrapScript(pad, "OnLeave", listWrap, LIST_BACK)
        pad:SetScript("PreClick", Pad_PreClick)
    end
    return TrainMacro()
end

-- Read by the dev addon's train probe.
function ns.TrainerState()
    local tall = listWrap and listWrap:GetAttribute("tall")
    local held = listWrap and listWrap:GetAttribute("listh")
    return selected, ClientSelection(), ClientRow() ~= nil, panel and panel.train, tall, held
end

-- Public API (Core/API.lua): the window while built, and its row for a service (the game's index) brought into view.
function ns.TrainerPanel() return panel end
function ns.TrainerRowFor(index)
    if not (active and panel and panel:IsShown()) or type(index) ~= "number" or not GetTrainerServiceInfo then return nil end
    local category = select(6, GetTrainerServiceInfo(index))
    if not category or category == "" then category = OTHER or "Other" end
    if collapsed[category] then
        collapsed[category] = nil
        panel.refresh()
    end
    return SkillList.RowFor(panel, lines, function(line) return line.index == index end, UpdateRows)
end

local function TrainRefused()
    if InCombatLockdown() then ns.SayNotInCombat() end
end

local function NoOp() end

local function Select(index)
    selected = index
    if index and SelectTrainerService then pcall(SelectTrainerService, index) end
    UpdateRows()
    UpdateDetail()
end

local function Row_OnClick(self)
    local line = self.line
    if not line then return end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    if line.header then
        collapsed[line.id] = (not collapsed[line.id]) or nil
        -- Full refresh: a folded header can take the chosen service with it.
        panel.refresh()
    else
        Select(line.index)
    end
end

local function CreateRow(parent, index)
    return ns.SkillListRow(parent, index, Row_OnClick)
end

local function Coins(amount) return ns.CoinText(amount) end

local WHITE, RED = "|cffffffff", "|cffff2020"

-- The client's wording without its colors
local function Plain(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- White text, only an unmet number red ("Mining (50)", the 50 red)
local function AddNeed(parts, text, met)
    text = Plain(text)
    if not met then
        text = text:gsub("(%d+)", RED .. "%1|r" .. WHITE, 1)
    end
    parts[#parts + 1] = WHITE .. text .. "|r"
end

-- What a service needs, the unmet parts in red.
local function Requirements(line)
    local parts = {}
    if line.level and line.level > 1 then
        AddNeed(parts, string.format(TRAINER_REQ_LEVEL or "Level %d", line.level), (UnitLevel("player") or 0) >= line.level)
    end
    if GetTrainerServiceSkillReq then
        local ok, skill, rank, has = pcall(GetTrainerServiceSkillReq, line.index)
        if ok and skill and rank and rank > 0 then
            AddNeed(parts, string.format(TRAINER_REQ_SKILL_RANK or "%s (%d)", skill, rank), has and true or false)
        end
    end
    if GetTrainerServiceNumAbilityReq and GetTrainerServiceAbilityReq then
        local okCount, count = pcall(GetTrainerServiceNumAbilityReq, line.index)
        for i = 1, (okCount and count or 0) do
            local ok, ability, has = pcall(GetTrainerServiceAbilityReq, line.index, i)
            -- A needed spell has no number to mark: all of it.
            if ok and ability then
                parts[#parts + 1] = ((has and WHITE) or RED) .. Plain(ability) .. "|r"
            end
        end
    end
    return table.concat(parts, ", ")
end

UpdateDetail = function()
    if not panel then return end
    local detail = panel.detail
    local line = selected and ServiceByIndex(selected)
    local money = GetMoney and GetMoney() or 0
    if not line then
        detail.iconButton:Hide()
        detail.name:SetText("")
        detail.sub:SetText("")
        detail.requires:SetText("")
        detail.cost:SetText("")
        detail.text:SetText("")
        panel.train:Disable()
        return
    end
    detail.iconButton:Show()
    detail.icon:SetTexture(line.texture)
    detail.name:SetText(line.name)
    detail.sub:SetText((line.sub and line.sub ~= "") and ("(" .. line.sub .. ")") or "")
    local needs = Requirements(line)
    detail.requires:SetText(needs ~= "" and ((REQUIRES_LABEL or "Requires:") .. " " .. needs) or "")
    local cost, profession = 0, false
    if GetTrainerServiceCost then
        local ok, value, isProfession = pcall(GetTrainerServiceCost, line.index)
        if ok and type(value) == "number" then cost = value end
        profession = ok and isProfession and true or false
    end
    -- A pet trainer's cost is in training points (the client's own reading of it: Blizzard_TrainerUI)
    local pet = C_Trainer and C_Trainer.GetTrainerType and Enum and Enum.TrainerType
        and C_Trainer.GetTrainerType() == Enum.TrainerType.Pet
    local have = money
    if pet and C_PetInfo and C_PetInfo.GetPetTrainingPoints then
        local total, used = C_PetInfo.GetPetTrainingPoints()
        have = math.max((tonumber(total) or 0) - (tonumber(used) or 0), 0)
    end
    if cost > 0 then
        local shown = pet and (TRAINING_POINTS_ABBREV or "%s TP"):format(tostring(cost)) or Coins(cost)
        detail.cost:SetText((COSTS_LABEL or "Cost:") .. " " .. (cost > have and "|cffff2020" or "|cffffffff") .. shown .. "|r")
    else
        detail.cost:SetText("")
    end
    money = have
    local words = ""
    if GetTrainerServiceDescription then
        local ok, text = pcall(GetTrainerServiceDescription, line.index)
        if ok and type(text) == "string" then words = text end
    end
    detail.text:SetText(words)
    -- A new profession with both slots taken: Train grays out, as Era's and the game's own do.
    local noSlot = profession and GetProfessions and select(2, GetProfessions()) ~= nil
    panel.train:SetEnabled(line.kind == "available" and cost <= money and not noSlot)
end

local function Refresh()
    if not panel or not active then return end
    Collect()
    FitList()
    -- Keep the pick while listed; else the first learnable, as Era opens; else the first.
    if not (selected and ServiceByIndex(selected)) then
        selected = nil
        for _, line in ipairs(lines) do
            if not line.header and line.kind == "available" then selected = line.index break end
        end
        if not selected then
            for _, line in ipairs(lines) do
                if not line.header then selected = line.index break end
            end
        end
        if selected and SelectTrainerService then pcall(SelectTrainerService, selected) end
    end
    local greeting = GetTrainerGreetingText and GetTrainerGreetingText() or ""
    panel.greeting:SetText(greeting or "")
    UpdateRows()
    UpdateDetail()
end

local function SetWidthIf(region, width)
    local current = region:GetWidth()
    if not IsSecret(current) and not IsSecret(width) and current == width then return end
    region:SetWidth(width)
end

local moneyBg
local function HideClientPieces(hide)
    local host = ClassTrainerFrame
    if not host then return end
    local alpha = hide and 0 or 1
    ns.FadeKeys(host, CLIENT_PIECES, alpha, CHANGED)
    local go = ClientTrain()
    if go then SetAlphaIf(go, alpha) end
    -- The client's rank bar, by name only; the old window had none.
    if ClassTrainerStatusBar then SetAlphaIf(ClassTrainerStatusBar, alpha) end
    -- Our skin's inset floor read as an empty bar under the tab.
    local floor = host.fcui and host.fcui.insetFloor
    if floor then SetAlphaIf(floor, alpha) end
    -- The client's money oval stays, six higher, inside the foot border.
    moneyBg = moneyBg or _G["ClassTrainerFrameMoneyBg"]
    local oval = moneyBg
    if oval then
        SetPointIf(oval, "BOTTOMLEFT", host, "BOTTOMLEFT", hide and 4 or 5, hide and -3 or -9)
        SetAlphaIf(oval, alpha)
        if hide and panel and panel.oval then
            local width = panel.oval:GetWidth()
            if width and width > 0 then SetWidthIf(oval, width) end
        elseif not hide then
            SetWidthIf(oval, 148)
        end
    end
    -- The client's money over our page, which is drawn above it.
    local money = ClientMoney()
    if money and panel then
        SetLevelIf(money, panel:GetFrameLevel() + (hide and 8 or 0))
    end
    local points = host.trainingPoints
    if points and panel then
        SetLevelIf(points, panel:GetFrameLevel() + (hide and 8 or 0))
        SetAlphaIf(points, 1)
    end
    -- Client list and bar sit over ours and relayout on each update: shrink, not move.
    for _, key in ipairs(CLIENT_SHRUNK) do
        local piece = host[key]
        if piece and piece.SetScale then
            SetScaleIf(piece, hide and 0.01 or 1)
            SetAlphaIf(piece, alpha)
        end
    end
end

local function RehideTick()
    if active then HideClientPieces(true) end
end

local function Service_OnEnter(self)
    if not selected or not GameTooltip.SetTrainerService then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    pcall(GameTooltip.SetTrainerService, GameTooltip, selected)
    GameTooltip:Show()
end

local function Build()
    local host = ClassTrainerFrame
    if panel or not host then return panel end
    panel = ns.ShellPage("ClassicUIForeverTrainer", host)
    panel:EnableMouse(true)

    -- Greeting on its own frame: the stone cut off its second line.
    local words = ns.NewFrame("Frame", nil, panel)
    words:SetAllPoints(panel)
    words:SetFrameLevel(panel:GetFrameLevel() + 3)
    panel.greeting = words:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    panel.greeting:SetPoint("TOPLEFT", panel, "TOPLEFT", 72, -30)
    panel.greeting:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
    panel.greeting:SetHeight(36)
    panel.greeting:SetJustifyH("LEFT")
    panel.greeting:SetJustifyV("TOP")

    ns.OldSkillShell(panel, { rows = LIST_ROWS, createRow = CreateRow, onScroll = UpdateRows })
    -- Stone from the title band to the list: the darker backing read as a bar.
    local gap = ns.NewFrame("Frame", nil, panel)
    gap:SetFrameLevel(panel:GetFrameLevel() + 1)
    gap:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -50)
    gap:SetPoint("RIGHT", panel, "RIGHT", -4, 0)
    gap:SetPoint("BOTTOM", panel.listBox, "TOP", 0, -8)
    local gapStone = gap:CreateTexture(nil, "BACKGROUND")
    gapStone:SetAllPoints(gap)
    ns.TileTex(gapStone, "rockBg")
    panel.collapseAll:SetScript("OnClick", function()
        SkillList.FoldAll(lines, collapsed)
        panel.refresh()
    end)
    panel.filter:SetScript("OnClick", function(self)
        if not panel.filterList then
            local function Item(label, kind)
                return { label, function()
                    local on = GetTrainerServiceTypeFilter and GetTrainerServiceTypeFilter(kind)
                    if SetTrainerServiceTypeFilter then SetTrainerServiceTypeFilter(kind, not on) end
                    Refresh()
                end, function() return GetTrainerServiceTypeFilter and GetTrainerServiceTypeFilter(kind) and true or false end }
            end
            panel.filterList = ns.DropList({
                Item(AVAILABLE or "Available", "available"),
                Item(UNAVAILABLE or "Unavailable", "unavailable"),
                Item(USED or "Already Known", "used"),
            })
            panel.filterList:Follow(panel)
        end
        panel.filterList:Toggle(self)
    end)

    -- The chosen service.
    local detail = panel.detail
    detail.iconButton = ns.ShellDetailHeader(detail, Service_OnEnter)
    detail.sub = detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detail.sub:SetPoint("LEFT", detail.name, "RIGHT", 4, 0)
    detail.cost = detail:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    detail.cost:SetPoint("TOPLEFT", detail, "TOPLEFT", 21, -62)
    detail.cost:SetJustifyH("LEFT")
    detail.text = detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detail.text:SetPoint("TOPLEFT", detail.cost, "BOTTOMLEFT", 0, -6)
    detail.text:SetPoint("RIGHT", detail, "RIGHT", -16, 0)
    detail.text:SetJustifyH("LEFT")
    detail.text:SetJustifyV("TOP")

    -- The foot: money in its own thin border, Train, Exit.
    local exit = ns.ShellExitButton(panel, "ClassTrainerFrame", 84)
    local train = ns.PanelButton(panel, TRAIN or "Train", 84)
    train:SetPoint("RIGHT", exit, "LEFT", -3, 0)
    -- Reached only with no pad over it: the pad hides in a fight.
    train:SetScript("OnClick", TrainRefused)
    panel.train = train
    -- HIGH, a strata over the window: at the window's strata the button kept the mouse.
    ns.MapPad(train, "HIGH", NoOp, PadMacro, TrainWanted)
    -- The money's border, clear of its oval all the way round.
    local moneyBox = ns.SkillInsetBox(panel, 16, true)
    moneyBox:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 1, 4)
    moneyBox:SetPoint("RIGHT", train, "LEFT", 1, 0)
    moneyBox:SetHeight(32)
    -- Train and Exit in the same thin border, level with the money's.
    for _, button in ipairs({ train, exit }) do
        local box = ns.SkillInsetBox(panel, 16, true)
        box:SetPoint("TOP", moneyBox, "TOP", 0, 0)
        box:SetPoint("BOTTOM", moneyBox, "BOTTOM", 0, 0)
        box:SetPoint("LEFT", button, "LEFT", -4, 0)
        box:SetPoint("RIGHT", button, "RIGHT", 4, 0)
        box:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
    end
    -- Our own gold oval; the client's, dull under the silver, stays unseen for its money to hang from.
    local oval = panel:CreateTexture(nil, "ARTWORK")
    oval:SetTexture("Interface\\MoneyFrame\\UI-MoneyFrame-Border")
    oval:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 4, -3)
    oval:SetPoint("RIGHT", train, "LEFT", -5, 0)
    oval:SetHeight(34)
    panel.oval = oval
    -- Detail pane's bottom edge under the foot's top: side by side they read double.
    panel.detailBox:ClearAllPoints()
    panel.detailBox:SetPoint("TOPLEFT", panel.listBox, "BOTTOMLEFT", 0, 12)
    panel.detailBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 25)
    panel.footBox:ClearAllPoints()
    panel.footBox:SetPoint("TOPLEFT", panel.detailBox, "BOTTOMLEFT", 0, 11)
    panel.footBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 1, 2)
    panel.footBox:SetFrameLevel(panel.detailBox:GetFrameLevel() + 1)
    -- The foot keeps its sides and bottom; its top edge drew a double line.
    ns.FadeKeys(panel.footBox, FOOT_EDGE)

    panel.bar.hideWhenIdle = true
    panel.refresh = Refresh
    -- Client pieces appear after opening (the inset floor); never slept: the panel has regions.
    ns.Sched.OnFrame(panel, { name = "trainer.panel", every = 0.2, fn = RehideTick })
    panel:SetScript("OnShow", Refresh)
    return panel
end

local function Open()
    if not active or not ClassTrainerFrame then return end
    Build()
    HideClientPieces(true)
    -- A Show that makes the page visible has run Refresh through OnShow.
    local wasShown = panel:IsShown()
    panel:Show()
    if wasShown or not panel:IsVisible() then Refresh() end
end

-- Trainer events come in bursts: one Open in this frame's pass.
local openWanted = false
local function OpenNow()
    if not openWanted then return end
    openWanted = false
    Open()
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
    if not active then return end
    if event == "SPELLS_CHANGED" then -- (the pet's spellbook: what it knows now, at a pet trainer)
        if panel and panel:IsVisible() then Refresh() end
        return
    end
    if event == "TRAINER_CLOSED" or event == "PLAYER_MONEY" or event == "UNIT_PET_TRAINING_POINTS" then
        -- A pending Open lands first, as when it ran at once.
        OpenNow()
        if event == "TRAINER_CLOSED" then
            selected = nil
        elseif panel and panel:IsVisible() then
            UpdateDetail()
        end
        return
    end
    openWanted = true
    ns.Sched.Soon("trainer.open", OpenNow)
end)

local function Apply()
    active = true
    ns.RegisterEvents(events, TRAINER_EVENTS)
    if ClassTrainerFrame and ClassTrainerFrame:IsShown() then Open() end
end

local function Restore()
    active = false
    events:UnregisterAllEvents()
    if panel then panel:Hide() end
    HideClientPieces(false)
end

ns.RegisterModule("trainer", { apply = Apply, restore = Restore })
