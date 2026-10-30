"""Port ClassicUI Forever 0.36.0 into Clara Combo Points (Modules/ClassicUI), with two fixes and a
change asked for: the party frames' debuff glow on the portrait, and the Who list's menu.
Usage: cui_port.py <ClassicUIForever dir> <ClaraComboPoints dir>
Every file gets a guard (it does nothing unless the module runs: ClaraNS.ClassicUIRuns, set by
Modules/ClassicUI/Bootstrap.lua) and the module's own table instead of Clara's. Each edit must match
the exact count given, or the script stops. Bootstrap.lua and Glue.lua are Clara's own (kept).
Prints the files in the standalone's TOC order, for Clara's TOC."""
import os, re, shutil, sys

src, dst = sys.argv[1], sys.argv[2]
out = os.path.join(dst, "Modules", "ClassicUI")

GUARD = ("local _, ClaraNS = ... -- (Clara Combo Points: ClassicUI Forever built in, QoL.lua)\n"
         "if not (type(ClaraNS) == \"table\" and ClaraNS.ClassicUIRuns) then return end\n")
MEDIA_OLD = "Interface\\\\AddOns\\\\ClassicUIForever\\\\media\\\\"
MEDIA_NEW = "Interface\\\\AddOns\\\\ClaraComboPoints\\\\Modules\\\\ClassicUI\\\\media\\\\"
MEDIA_ADDON = '"Interface\\\\AddOns\\\\" .. ADDON .. "\\\\media\\\\'
MEDIA_FIXED = '"Interface\\\\AddOns\\\\ClaraComboPoints\\\\Modules\\\\ClassicUI\\\\media\\\\'
VERSION = "0.36.0"

def edit(text, old, new, count, where):
    n = text.count(old)
    if n != count:
        sys.exit(f"{where}: expected {count}, found {n}: {old[:90]!r}")
    return text.replace(old, new)

def read(path):
    with open(path, "rb") as f:
        return f.read().decode("utf-8-sig").replace("\r\n", "\n")

def write(path, text):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)

# a fresh copy (Clara's own files kept)
keep = {}
for own in ("Bootstrap.lua", "Glue.lua"):
    p = os.path.join(out, own)
    if os.path.exists(p):
        keep[own] = read(p)
if os.path.isdir(out):
    shutil.rmtree(out)
shutil.copytree(src, out, ignore=shutil.ignore_patterns("ClassicUIForever.toc", "CHANGELOG.md"))
for own, text in keep.items():
    write(os.path.join(out, own), text)

P = os.path.join
# Clara's own files in the module, written as its own are (`local _, ns = ...`), and the TOC line each follows
OWN = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cui_own")
OWN_AFTER = {P("Units", "PetIcons.lua"): "Units\\BuffsOnTop.lua", P("Windows", "ClaraMail.lua"): "Windows\\Panels.lua",
             P("Units", "ClaraUnitBoxes.lua"): "Units\\ThreatNumber.lua"}
for rel in OWN_AFTER:
    shutil.copyfile(os.path.join(OWN, rel), os.path.join(out, rel))
EDITS = {
    # its textures: in Clara's folder
    P("Art", "TextureData.lua"): [(MEDIA_OLD, MEDIA_NEW, 1)],
    P("Windows", "DamageMeter.lua"): [(MEDIA_OLD, MEDIA_NEW, 1)],
    P("Windows", "Chat.lua"): [(MEDIA_ADDON, MEDIA_FIXED, 1)],
    P("Core", "Core.lua"): [('"|TInterface\\\\AddOns\\\\" .. ADDON .. "\\\\media\\\\', '"|TInterface\\\\AddOns\\\\ClaraComboPoints\\\\Modules\\\\ClassicUI\\\\media\\\\', 1)],
    # its version (Clara's TOC gives Clara's)
    P("Options", "Status.lua"): [('''local function Version()
    local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local ok, version = pcall(get, ADDON, "Version")
    return ok and version or "?"
end''', f'''local function Version()
    return "{VERSION}" -- (Clara Combo Points: the version built in)
end''', 1)],
    # turned off: Clara's module switch, not the standalone's line in the AddOns list
    P("Options", "Layout.lua"): [
        ('''    local state = C_AddOns and C_AddOns.GetAddOnEnableState
    local me = AddonCharacter()
    if not (state and me) then return false end
    local ok, value = pcall(state, "ClassicUIForever", me)
    return ok and value == 0''',
         '''    -- (Clara Combo Points: its module turned off, or Clara itself turned off for this character)
    return ClaraNS:ClassicUITurningOff()''', 1),
        ('''    pcall(disable, "ClassicUIForever", me)''',
         '''    ClaraNS:SetQolEnabled("classicui", false) -- (Clara Combo Points: its module, from the next session)''', 1),
        ('Turn the addon off for this character? Your earlier layout and game settings come back.',
         'Turn it off (its module in Clara Combo Points, for every character)? Your earlier layout and game settings come back.', 1)],
    # fix: the game colours the party portrait's ring (PartyMemberOverlay.Status) by the debuff's type
    # and places it for its own portrait (TOPLEFT -1, -1 of the frame, the portrait at 7, -6); the
    # 1.x portrait sits 8 lower, so the ring is pinned to the portrait itself (and put back on restore)
    P("Units", "PartyPetFrames.lua"): [
        ('''local function SkinPartyMember(frame)''',
         '''-- The game's debuff ring round the portrait (green for a poison...): set for its portrait at 7, -6 (the ring at
-- -1, -1 of the frame); on ours, 8 lower, it rode above it. Pinned to the portrait, where the client set it.
local STATUS_X, STATUS_Y = -8, 5
local function PinStatus(frame)
    local status = ns.Path(frame, "PartyMemberOverlay", "Status")
    if status and frame.Portrait then ns.SetPointOnce(status, "TOPLEFT", frame.Portrait, "TOPLEFT", STATUS_X, STATUS_Y) end
end
local function UnpinStatus(frame)
    local status = ns.Path(frame, "PartyMemberOverlay", "Status")
    if status then ns.SetPointOnce(status, "TOPLEFT", frame, "TOPLEFT", -1, -1) end
end

local function SkinPartyMember(frame)''', 1),
        ('''    UF.DressGlow(frame.Flash, "partyFlash", PARTY_FLASH_LAYERED, frame)
end''', '''    UF.DressGlow(frame.Flash, "partyFlash", PARTY_FLASH_LAYERED, frame)
    PinStatus(frame)
end''', 1),
        ('''            UF.DressGlow(frame.Flash, "partyFlash", PARTY_FLASH, frame)
            DrainPartyTrim(frame)''', '''            UF.DressGlow(frame.Flash, "partyFlash", PARTY_FLASH, frame)
            PinStatus(frame)
            DrainPartyTrim(frame)''', 1),
        ('''        DrainPartyTrim(frame, true)
        HideHost(frame)''', '''        DrainPartyTrim(frame, true)
        UnpinStatus(frame)
        HideHost(frame)''', 1)],
    # a row with a submenu and a pick: the pick on a click, the submenu on hover (the Who menu)
    P("UI", "Menus.lua"): [
        ('''-- (gold tick when on), { text, radio = isOn, pick = fn }, { text, click = fn }, { divider = true }, { text, sub = entries or
-- a function }. A pick keeps the menu open and redraws the marks; a submenu opens beside its row on hover.''',
         '''-- (gold tick when on), { text, radio = isOn, pick = fn }, { text, click = fn }, { divider = true }, { text, sub = entries or
-- a function }. A pick keeps the menu open and redraws the marks; a submenu opens beside its row on hover. A row with both a
-- submenu and a pick: the pick on a click, the submenu on hover.''', 1),
        ('''    if entry.sub then
        OpenSub(row:GetParent(), row)
        return
    end''', '''    if entry.sub and not (entry.toggle or entry.pick or entry.click) then
        OpenSub(row:GetParent(), row)
        return
    end''', 1)],
    # the Who list's menu as 1.x had it: Class, Race and Zone sort at once (Race and Zone, and Guild, as the middle
    # column too), their filters on hover; Sort By stays; no Column submenu
    P("Social", "WhoList.lua"): [
        ('''-- The game's Who filters (class, race, zone, sort), then which field the second column shows.
local function FilterEntries(header)
    local entries = S.WhoFilterEntries()''',
         '''-- The game's Who filters (class, race, zone) under rows that sort at once: Class by class, Race, Zone and Guild by the
-- second column, which then shows that field; then Sort By.
local function FilterEntries(header)
    local function Column(key)
        for _, field in ipairs(WHO_FIELDS) do
            if field.key == key then
                ns.db.whoColumn = key
                if header.Text then header.Text:SetText(field.label) end
            end
        end
        sort.field, sort.reverse = "zone", false
        Refresh()
    end
    local function ColumnRadio(key) return function() return sort.field == "zone" and WhoField().key == key end end
    local entries = S.WhoFilterEntries()
    local class, race, zone = entries[1], entries[2], entries[3]
    class.radio = function() return sort.field == "class" end
    class.pick = function() sort.field, sort.reverse = "class", false Refresh() end
    race.radio, race.pick = ColumnRadio("race"), function() Column("race") end
    zone.radio, zone.pick = ColumnRadio("zone"), function() Column("zone") end
    entries[#entries + 1] = { GUILD or "Guild", radio = ColumnRadio("guild"), pick = function() Column("guild") end }''', 1),
        ('''    local columns = {}
    for _, field in ipairs(WHO_FIELDS) do
        columns[#columns + 1] = { field.label, radio = function() return WhoField() == field end, pick = function()
            ns.db.whoColumn = field.key
            if header.Text then header.Text:SetText(field.label) end
            sort.field, sort.reverse = "zone", false
            Refresh()
        end }
    end
    entries[#entries + 1] = { L["WHO_COLUMN"], sub = columns }
    return entries''', '''    return entries''', 1)],
    # the pet's loyalty with its rank: "Loyalty rank 5 - Faithful" (the client gives the name only)
    P("Character", "CharacterSheet.lua"): [
        ('''-- "Level 20 Gnome Mage", gold, under the name as 1.x wrote it; in the pet view "Level 20 Wolf" and its loyalty.
local function LevelLine(pet)''', '''-- The pet's loyalty with its rank, "Loyalty rank 5 - Faithful": the rank from the name the client gives (its six
-- names in order, PET_LOYALTY_LEVELS); a name not among them is shown as it is.
local function LoyaltyLine(name)
    local key = name:lower()
    local rank = 0
    for level in tostring(ns.L["PET_LOYALTY_LEVELS"] or ""):gmatch("[^|]+") do
        rank = rank + 1
        if level:lower() == key then return ns.L["PET_LOYALTY_RANK"]:format(rank, name) end
    end
    return name
end

-- "Level 20 Gnome Mage", gold, under the name as 1.x wrote it; in the pet view "Level 20 Wolf" and its loyalty.
local function LevelLine(pet)''', 1),
        ('''        return loyalty ~= "" and (line .. "\\n" .. loyalty) or line''',
         '''        return loyalty ~= "" and (line .. "\\n" .. LoyaltyLine(loyalty)) or line''', 1)],
    P("Locales", "enUS.lua"): [('L["WHO_COLUMN"] = "Column"\n', 'L["WHO_COLUMN"] = "Column"\n'
        '-- Character/CharacterSheet.lua: the pet\'s loyalty, its rank first; the client\'s six loyalty names, in order\n'
        'L["PET_LOYALTY_RANK"] = "Loyalty rank %d - %s"\n'
        'L["PET_LOYALTY_LEVELS"] = "Rebellious|Unruly|Submissive|Dependable|Faithful|Best Friend"\n', 1)],
    P("Locales", "frFR.lua"): [('L["WHO_COLUMN"] = "Colonne"\n', 'L["WHO_COLUMN"] = "Colonne"\n'
        'L["PET_LOYALTY_RANK"] = "Rang de loyauté %d - %s"\n'
        'L["PET_LOYALTY_LEVELS"] = "Rebelle|Indiscipliné|Soumis|Fiable|Fidèle|Meilleur ami"\n', 1)],
    P("Locales", "deDE.lua"): [('L["WHO_COLUMN"] = "Spalte"\n', 'L["WHO_COLUMN"] = "Spalte"\n'
        'L["PET_LOYALTY_RANK"] = "Treuerang %d - %s"\n'
        'L["PET_LOYALTY_LEVELS"] = "Rebellisch|Widerspenstig|Unterwürfig|Zuverlässig|Treu|Bester Freund"\n', 1)],
    P("Locales", "esES.lua"): [('L["WHO_COLUMN"] = "Columna"\n', 'L["WHO_COLUMN"] = "Columna"\n'
        'L["PET_LOYALTY_RANK"] = "Rango de lealtad %d - %s"\n'
        'L["PET_LOYALTY_LEVELS"] = "Rebelde|Revoltoso|Sumiso|Fiable|Fiel|Mejor amigo"\n', 1)],
    P("Locales", "itIT.lua"): [('L["WHO_COLUMN"] = "Colonna"\n', 'L["WHO_COLUMN"] = "Colonna"\n'
        'L["PET_LOYALTY_RANK"] = "Grado di lealtà %d - %s"\n', 1)],
    # fix: a reputation bar at 0 (0/6000) drew full, or past its border: its fill sized 0 wide, which a texture takes
    # as its file's own width; and a row dressed after the client's update kept a width from before (another tab)
    P("Character", "CharacterLists.lua"): [
        ('''local fillShare = setmetatable({}, { __mode = "k" })
local function FitFill(bar)
    local share = fillShare[bar]
    if share and bar.Fill then
        bar.Fill:SetWidth(math.max(0, share * (bar:GetWidth() - (bar.fcuiInset or 0))))
    end
end''', '''local fillShare = setmetatable({}, { __mode = "k" })
-- A texture sized 0 wide takes its file's own width (a full bar, or one past its border: a reputation at 0/6000), so an
-- empty fill is hidden instead; and none is wider than its bar.
local function SizeFill(bar, width)
    local room = math.max(0, bar:GetWidth() - (bar.fcuiInset or 0))
    width = math.min(type(width) == "number" and width or 0, room)
    if width < 0.5 then
        bar.Fill:Hide()
    else
        bar.Fill:SetWidth(width)
        bar.Fill:Show()
    end
end
local function FitFill(bar)
    local share = fillShare[bar]
    if share and bar.Fill then SizeFill(bar, share * (bar:GetWidth() - (bar.fcuiInset or 0))) end
end''', 1),
        ('''                self.Fill:SetWidth(math.max(0, math.min(width, self:GetWidth() - (self.fcuiInset or 0))))''',
         '''                SizeFill(self, width)''', 1),
        ('''        Take(fill, "art", "layer", "size", "points", "masks")''',
         '''        -- A row first dressed after the client's update: the share it gave, from the fill it cropped to it (0, p, 1, 0).
        if not skills and fillShare[bar] == nil then
            local left, top, _, _, right = fill:GetTexCoord()
            if left == 0 and top == 1 and type(right) == "number" and right >= 0 and right <= 1 then fillShare[bar] = right end
        end
        Take(fill, "art", "layer", "size", "points", "masks", "shown")''', 1),
        ('''        fill:SetWidth(math.max(0, math.min(fill:GetWidth(), bar:GetWidth() - bar.fcuiInset)))''',
         '''        if fillShare[bar] then FitFill(bar) else SizeFill(bar, fill:GetWidth()) end''', 1)],
}

# the hunter's pet icons (Units/PetIcons.lua, Clara's own): their two options, defaults and words
PET_WORDS = {
    "enUS": ('Pet feeding timer', 'Hunters: while your pet is fed, the Feed Pet Effect shows under the pet frame, with its time left.',
             "Move the pet's icons", 'Hunters: drag the happiness face and the Feed Pet icon by the pet frame to place them. Right-click one: back to its own spot. Untick to lock them.',
             'Drag to move. Right-click: back to its own spot.'),
    "frFR": ('Minuteur du repas du familier', "Chasseurs : pendant que votre familier mange, l'effet Nourrir le familier s'affiche sous le cadre du familier, avec son temps restant.",
             'Déplacer les icônes du familier', "Chasseurs : faites glisser le visage d'humeur et l'icône Nourrir le familier près du cadre du familier pour les placer. Clic droit sur l'une : retour à sa place. Décochez pour les verrouiller.",
             'Faites glisser pour déplacer. Clic droit : retour à sa place.'),
    "deDE": ('Fütterungstimer des Tiers', 'Jäger: Während das Tier gefüttert wird, erscheint der Effekt von Tier füttern unter dem Tierrahmen, mit seiner Restzeit.',
             'Symbole des Tiers verschieben', 'Jäger: Das Zufriedenheitsgesicht und das Symbol von Tier füttern am Tierrahmen ziehen, um sie zu platzieren. Rechtsklick auf eines: zurück an seinen Platz. Abwählen sperrt sie.',
             'Ziehen zum Verschieben. Rechtsklick: zurück an seinen Platz.'),
    "esES": ('Temporizador de alimentar mascota', 'Cazadores: mientras tu mascota come, el efecto de Alimentar mascota aparece bajo el marco de la mascota, con su tiempo restante.',
             'Mover los iconos de la mascota', 'Cazadores: arrastra la cara de felicidad y el icono de Alimentar mascota junto al marco de la mascota para colocarlos. Clic derecho en uno: vuelve a su sitio. Desmarca para bloquearlos.',
             'Arrastra para mover. Clic derecho: vuelve a su sitio.'),
    "itIT": ('Timer del pasto del famiglio', 'Cacciatori: mentre il famiglio mangia, l\'effetto di Nutri famiglio appare sotto il riquadro del famiglio, con il tempo rimasto.',
             'Sposta le icone del famiglio', 'Cacciatori: trascina la faccia dell\'umore e l\'icona di Nutri famiglio accanto al riquadro del famiglio per posizionarle. Clic destro su una: torna al suo posto. Deseleziona per bloccarle.',
             'Trascina per spostare. Clic destro: torna al suo posto.'),
}
def pet_words(lang):
    w = PET_WORDS[lang]
    q = lambda t: '"' + t.replace('\\', '\\\\').replace('"', '\\"') + '"'
    return ('L["OPT_petFeedIcon"] = ' + q(w[0]) + '\n' + 'L["OPT_petFeedIcon_TIP"] = ' + q(w[1]) + '\n'
            + 'L["OPT_petIconsUnlocked"] = ' + q(w[2]) + '\n' + 'L["OPT_petIconsUnlocked_TIP"] = ' + q(w[3]) + '\n'
            + 'L["PET_ICON_MOVE_TIP"] = ' + q(w[4]) + '\n')
PET_ANCHOR = {"enUS": 'L["WHO_COLUMN"] = "Column"\n', "frFR": 'L["WHO_COLUMN"] = "Colonne"\n', "deDE": 'L["WHO_COLUMN"] = "Spalte"\n',
              "esES": 'L["WHO_COLUMN"] = "Columna"\n', "itIT": 'L["WHO_COLUMN"] = "Colonna"\n'}
EXTRA = {
    P("Options", "Toggles.lua"): [
        ('''    { "unitFrameParty", L["OPT_unitFrameParty"], L["OPT_unitFrameParty_TIP"], parent = "unitFrames", checks = "unitFrameList", drop = true },
''', '''    { "unitFrameParty", L["OPT_unitFrameParty"], L["OPT_unitFrameParty_TIP"], parent = "unitFrames", checks = "unitFrameList", drop = true },
    -- (Clara Combo Points: the hunter's pet icons, Units/PetIcons.lua)
    { "petFeedIcon", L["OPT_petFeedIcon"], L["OPT_petFeedIcon_TIP"], parent = "unitFrames", needs = "unitFramePet",
        search = "hunter pet feed food happiness timer buff" },
    { "petIconsUnlocked", L["OPT_petIconsUnlocked"], L["OPT_petIconsUnlocked_TIP"], parent = "unitFrames", needs = "unitFramePet",
        search = "hunter pet move drag happiness face feed icon lock" },
''', 1)],
    P("Core", "Defaults.lua"): [('''    unitFramePet = true,
''', '''    unitFramePet = true,
    petFeedIcon = true,
    petIconsUnlocked = false,
''', 1)],
}
# the side panel's arrow 5 further right: Leatrix Plus's durability button (its D) stands left of it
EXTRA[P("Character", "EquipmentPane.lua")] = [('local ARROW_X, ARROW_Y = 324, -416\n',
    'local ARROW_X, ARROW_Y = 329, -416 -- (Clara Combo Points: 5 right, Leatrix Plus\'s durability button left of it)\n', 1)]
# the side panel's stat sections dragged by their heads into an order of the player's, per class (a preview while
# dragged, kept as dropped); by default Spell under Attributes for mages, warlocks and priests, Ranged for hunters
EXTRA[P("Character", "StatPanes.lua")] = [
    ('''local folded = {}
local list
''', '''local folded = {}
local list
-- (Clara Combo Points) The sections' order, per class (db.statListOrder[class]: their keys), dragged by their heads:
-- while dragged, the list shows it where it would land; dropped, that order is kept. By default the client's, with
-- Spell under Attributes for mages, warlocks and priests and Ranged for hunters.
local CLASS_FIRST = { MAGE = "section4", WARLOCK = "section4", PRIEST = "section4", HUNTER = "section7" }
local DRAG_ALPHA, DRAG_SCROLL = 0.6, 240   -- the dragged box's alpha; the view's run past its ends, per second
local preview                              -- the boxes in the order shown while one is dragged
function ns.StatListState() return list end -- (for the tests)
''', 1),
    ('''    for _, box in ipairs(list.boxes) do
        local open = not folded[box.section.key]''', '''    for _, box in ipairs(preview or list.boxes) do
        local open = not folded[box.section.key]''', 1),
    ('''local function ListBox(section)''', '''local function ClassKey()
    local _, class = UnitClass("player")
    return class or "?"
end

-- The client's order, the class's own section moved under Attributes.
local function DefaultKeys()
    local keys = {}
    for _, box in ipairs(list.all) do keys[#keys + 1] = box.section.key end
    local first = CLASS_FIRST[ClassKey()]
    if not first then return keys end
    for i, key in ipairs(keys) do
        if key == first then
            table.remove(keys, i)
            break
        end
    end
    for i, key in ipairs(keys) do
        if key == "section2" then
            table.insert(keys, i + 1, first)
            return keys
        end
    end
    keys[#keys + 1] = first
    return keys
end

-- The boxes in the saved order (else the default); one the order does not name keeps the end.
local function Arrange()
    local byKey, order, placed = {}, {}, {}
    for _, box in ipairs(list.all) do byKey[box.section.key] = box end
    local saved = ns.db and type(ns.db.statListOrder) == "table" and ns.db.statListOrder[ClassKey()]
    for _, key in ipairs(type(saved) == "table" and saved or DefaultKeys()) do
        local box = byKey[key]
        if box and not placed[box] then
            order[#order + 1] = box
            placed[box] = true
        end
    end
    for _, box in ipairs(list.all) do
        if not placed[box] then order[#order + 1] = box end
    end
    list.boxes = order
end

-- The cursor's depth under the list's top, in its units.
local function CursorDepth()
    local top = list.child:GetTop()
    if not top then return nil end
    local _, y = GetCursorPosition()
    return top - y / list.child:GetEffectiveScale()
end

-- While a box is dragged: the view runs past its ends, and the list shows the box where it would land (before the first
-- other box whose middle is under the cursor).
local function DragUpdate(_, elapsed)
    local dragged = list.dragging
    local depth = dragged and CursorDepth()
    if not depth then return end
    local scroll = list.scroll
    local view, height = scroll:GetVerticalScroll(), scroll:GetHeight() or 0
    local step = (depth < view and -1) or (depth > view + height and 1) or 0
    if step ~= 0 then
        local over = math.max(0, list.child:GetHeight() - height)
        scroll:SetVerticalScroll(math.max(0, math.min(over, view + step * DRAG_SCROLL * elapsed)))
    end
    local order, y, placed = {}, 0, false
    for _, box in ipairs(list.boxes) do
        if box ~= dragged then
            local tall = box:GetHeight() or 0
            if not placed and depth < y + tall / 2 then
                order[#order + 1] = dragged
                placed = true
            end
            order[#order + 1] = box
            y = y + tall + LIST_GAP
        end
    end
    if not placed then order[#order + 1] = dragged end
    local same = preview ~= nil and #preview == #order
    for i = 1, same and #order or 0 do
        if preview[i] ~= order[i] then same = false end
    end
    if not same then
        preview = order
        LayoutList()
    end
end

local function StartDrag(box)
    if list.dragging then return end
    list.dragging = box
    preview = nil
    box:SetAlpha(DRAG_ALPHA)
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    list.dragger:SetScript("OnUpdate", DragUpdate)
end

-- Dropped: the order shown is the order, kept for the class.
local function StopDrag()
    local box = list.dragging
    if not box then return end
    list.dragging = nil
    list.dragger:SetScript("OnUpdate", nil)
    box:SetAlpha(1)
    if preview then list.boxes = preview end
    preview = nil
    if ns.db then
        local keys = {}
        for _, each in ipairs(list.boxes) do keys[#keys + 1] = each.section.key end
        ns.db.statListOrder = type(ns.db.statListOrder) == "table" and ns.db.statListOrder or {}
        ns.db.statListOrder[ClassKey()] = keys
    end
    list.justDragged = true
    C_Timer.After(0, function() list.justDragged = nil end)
    LayoutList()
end

local function ListBox(section)''', 1),
    ('''    head:SetScript("OnClick", function()
        folded[section.key] = not folded[section.key] or nil''', '''    head:SetScript("OnClick", function()
        if list.justDragged then return end
        folded[section.key] = not folded[section.key] or nil''', 1),
    ('''    box.head, box.section, box.rows = head, section, {}
''', '''    box.head, box.section, box.rows = head, section, {}
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() StartDrag(box) end)
    head:SetScript("OnDragStop", StopDrag)
''', 1),
    ('''    list = { frame = frame, scroll = scroll, child = child, boxes = {} }
    for _, section in ipairs(Sections()) do
        if not section.resistances then list.boxes[#list.boxes + 1] = ListBox(section) end
    end
''', '''    list = { frame = frame, scroll = scroll, child = child, boxes = {}, all = {}, dragger = ns.NewFrame("Frame", nil, frame) }
    for _, section in ipairs(Sections()) do
        if not section.resistances then list.all[#list.all + 1] = ListBox(section) end
    end
    Arrange()
    frame:SetScript("OnHide", StopDrag)
''', 1)]
# the Who list's menu shut once Class, Race, Zone or Guild is picked (the list sorted by it): a row's close
EXTRA[P("UI", "Menus.lua")] = [
    ('''-- submenu and a pick: the pick on a click, the submenu on hover.''', '''-- submenu and a pick: the pick on a click, the submenu on hover. close = true: the menu shuts once it is picked.''', 1),
    ('''    local act = entry.toggle or entry.pick or entry.click
    if act then act() end
    Redraw(row:GetParent().root)''', '''    local act = entry.toggle or entry.pick or entry.click
    if act then act() end
    if entry.close then
        row:GetParent().root:Hide() -- (Clara Combo Points: picked, the menu shut, its submenus with it)
        return
    end
    Redraw(row:GetParent().root)''', 1)]
EXTRA[P("Social", "WhoList.lua")] = [
    ('''    entries[#entries + 1] = { GUILD or "Guild", radio = ColumnRadio("guild"), pick = function() Column("guild") end }
''', '''    entries[#entries + 1] = { GUILD or "Guild", radio = ColumnRadio("guild"), pick = function() Column("guild") end,
        close = true }
    class.close, race.close, zone.close = true, true, true -- (Clara Combo Points: the list sorted, the menu shut)
''', 1)]
# the druid's mana bar in forms: the character sheet open, current / max, as the game's own bars then
EXTRA[P("Units", "DruidMana.lua")] = [
    ('''        Update()
    end)
    bar:Hide()
end
''', '''        Update()
    end)
    -- (Clara Combo Points: the character sheet opened or shut, its numbers in or out)
    if CharacterFrame then
        ns.HookScriptOnce(CharacterFrame, "OnShow", function() Update() end, "druidMana")
        ns.HookScriptOnce(CharacterFrame, "OnHide", function() Update() end, "druidMana")
    end
    bar:Hide()
end
''', 1),
    ('''-- The Status Text setting: numeric, percent, both''', '''-- The character sheet open: the game's player bars in numbers, current / max, whatever the Status Text setting or the
-- hover (its showNumeric on them); ours as they are (Clara Combo Points).
local function SheetNumbers()
    local game = _G.PlayerFrame_GetManaBar and _G.PlayerFrame_GetManaBar()
    return type(game) == "table" and game.showNumeric == true
end

-- The Status Text setting: numeric, percent, both''', 1),
    ('''    if hovered and ns.db.hoverBothNumbers ~= false and (mode == "NUMERIC" or mode == "PERCENT") then mode = "BOTH" end
''', '''    if hovered and ns.db.hoverBothNumbers ~= false and (mode == "NUMERIC" or mode == "PERCENT") then mode = "BOTH" end
    if SheetNumbers() then mode = "NUMERIC" end -- (Clara Combo Points)
''', 1)]
# the nameplates' aura rings: only the plates whose auras changed are walked
EXTRA[P("Units", "NamePlateAuras.lua")] = [('local function TintAll()\n    ns.NP.EachPlate(TintPlate)\nend\n\nns.EventFrame(RING_EVENTS, function(_, _, unit)\n    if type(unit) == "string" and unit:find("^nameplate") then ns.Sched.NextFrame("namePlates.auraRings", TintAll) end\nend)\n',
    'local function TintAll()\n    ns.NP.EachPlate(TintPlate)\nend\n\n-- (Clara Combo Points: only the plates whose auras changed, not every plate on screen at each aura event of one; all of\n-- them on a client without the lookup by unit)\nlocal changed, unknown = {}, false\n\nlocal function TintChanged()\n    if unknown then\n        unknown = false\n        wipe(changed)\n        return TintAll()\n    end\n    for unit in pairs(changed) do\n        changed[unit] = nil\n        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)\n        local unitFrame = ok and plate and plate.UnitFrame\n        if unitFrame and not ns.IsForbidden(unitFrame) then TintPlate(unitFrame) end\n    end\nend\n\nns.EventFrame(RING_EVENTS, function(_, _, unit)\n    if (issecretvalue and issecretvalue(unit)) or type(unit) ~= "string" or not unit:find("^nameplate") then return end\n    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then\n        unknown = true\n    else\n        changed[unit] = true\n    end\n    ns.Sched.NextFrame("namePlates.auraRings", TintChanged)\nend)\n', 1)]
# the health bar ClassicUI draws over a unit frame's, for Clara's DoesItDie (its marker and kill icon on it)
EXTRA[P("Units", "UnitFrameCore.lua")] = [("-- The name's top off the host: in its box, or over the frame when the health bar takes the box.\n",
    "-- (Clara Combo Points: the health bar drawn over a unit frame's, for Clara's modules that mark it: DoesItDie)\nfunction ClaraNS.ClassicUIHealthBar(frame)\n    local lay = frame and lays[frame]\n    return lay and lay.health or nil\nend\n\n-- The name's top off the host: in its box, or over the frame when the health bar takes the box.\n", 1)]
# the threat percent's box and place, for Clara's distance box beside it (Units/ClaraUnitBoxes.lua)
EXTRA[P("Units", "ThreatNumber.lua")] = [('''function UF.ThreatShown(unit) return shown[unit] == true end
''', '''function UF.ThreatShown(unit) return shown[unit] == true end
-- (Clara Combo Points: Units/ClaraUnitBoxes.lua sets the box beside its distance box, the two over the name box)
UF.THREAT_BOX_X, UF.THREAT_BOX_Y = BOX_X, BOX_Y
function UF.ThreatBox(unit) return boxes[unit] end
''', 1)]
# Reverse Engineering (Clara's Modules/Crafting/CraftClassic.lua): the list's search (by reagent, "Name" in quotes) and
# materials filter, the chests on the reagents, its panel under them in the recipe's pane, its filter menu's entries
EXTRA[P("Skills", "TradeSkill.lua")] = [
    ('''        local named = query == "" or (info and type(info.name) == "string" and info.name:lower():find(query, 1, true) ~= nil)
''', '''        local named
        if ClaraNS.CraftMatch then -- (Clara Combo Points: its search, reagents too, and its materials filter)
            named = info ~= nil and ClaraNS.CraftMatch(id, info, query) and ClaraNS.CraftShown(id)
        else
            named = query == "" or (info and type(info.name) == "string" and info.name:lower():find(query, 1, true) ~= nil)
        end
''', 1),
    ('''    local room = scroll:GetHeight() or 0
    local height = math.max(room, bottom + 4)
''', '''    if ClaraNS.CraftClassicPlace then bottom = ClaraNS.CraftClassicPlace(detail, bottom) end -- (Clara Combo Points)
    local room = scroll:GetHeight() or 0
    local height = math.max(room, bottom + 4)
''', 1),
    ('''    detail.shownReagents = shown
''', '''    detail.shownReagents = shown
    if ClaraNS.CraftClassicDetail then ClaraNS.CraftClassicDetail(detail, info) end -- (Clara Combo Points)
''', 1),
    ('''    R.Changed = Refresh
''', '''    R.Changed = Refresh
    ClaraNS.ClassicTradeRefresh = Refresh -- (Clara Combo Points: its filter and options draw the window again)
''', 1)]
EXTRA[P("Skills", "TradeSkillExtras.lua")] = [
    ('''                toggle = function() R.ToggleType(itemType) end }
        end
    end
    return entries
''', '''                toggle = function() R.ToggleType(itemType) end }
        end
    end
    -- (Clara Combo Points: Reverse Engineering's materials filter)
    for _, entry in ipairs(ClaraNS.CraftFilterEntries and ClaraNS.CraftFilterEntries() or {}) do entries[#entries + 1] = entry end
    return entries
''', 1)]
for lang, anchor_text in PET_ANCHOR.items():
    EXTRA[P("Locales", lang + ".lua")] = [(anchor_text, anchor_text + pet_words(lang), 1)]
for rel, more in EXTRA.items():
    EDITS[rel] = EDITS.get(rel, []) + more

done = set()
lua = 0
for root, _, files in os.walk(out):
    for name in files:
        rel = os.path.relpath(os.path.join(root, name), out)
        if not name.endswith(".lua") or rel in ("Bootstrap.lua", "Glue.lua"):
            continue
        path = os.path.join(out, rel)
        text = read(path)
        # its saved settings: Clara's own copies
        text = text.replace("ForeverClassicUICharDB", "ClaraClassicUICharDB").replace("ForeverClassicUIDB", "ClaraClassicUIDB")
        # its own table (Clara's is the one `...` gives); ADDON stays Clara's name (its ADDON_LOADED)
        plain = len(re.findall(r"^local _, ns = \.\.\.$", text, re.M))
        named = len(re.findall(r"^local ADDON, ns = \.\.\.$", text, re.M))
        if plain + named != 1:
            sys.exit(f"{rel}: {plain + named} `local _, ns = ...` lines")
        text = re.sub(r"^local _, ns = \.\.\.$", "local ns = ClaraNS.ClassicUIPrivate", text, flags=re.M)
        text = re.sub(r"^local ADDON, ns = \.\.\.$", "local ADDON, ns = (...), ClaraNS.ClassicUIPrivate", text, flags=re.M)
        for old, new, count in EDITS.get(rel, []):
            text = edit(text, old, new, count, rel)
            done.add(rel)
        if re.search(r'AddOns\\\\ClassicUIForever', text):
            sys.exit(f"{rel}: the standalone's folder or name left")
        write(path, GUARD + text)
        lua += 1

missing = set(EDITS) - done
if missing:
    sys.exit(f"files not found: {sorted(missing)}")
toc = [l.strip() for l in read(os.path.join(src, "ClassicUIForever.toc")).split("\n") if l.strip() and not l.startswith("#")]
for rel, after in OWN_AFTER.items():
    toc.insert(toc.index(after) + 1, rel.replace(os.sep, "\\"))
with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "cui_toc.txt"), "w") as f:
    f.write("\n".join("Modules\\ClassicUI\\" + l for l in toc) + "\n")
print("ok", out, lua, "files;", len(toc), "TOC lines")
