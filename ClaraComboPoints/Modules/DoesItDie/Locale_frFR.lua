-- DoesItDie: French (frFR) spell descriptions and names. Registers itself with Locale.lua.
-- Ported from PR #11 (gou-gouze). The French patterns only see descriptions the English and German ones didn't
-- read, and can't match their text (they need "points de dégâts", "points de vie", "Coup de grâce").
--
-- The wording is WoW: Forever's own French tooltips (Wowhead, data env Forever, locale fr), except the names
-- marked S below (standard Classic French, confirm in-game). Not verified on a French client yet. How it differs
-- from English:
--   * the school follows the amount, with varying case and connector: "40 points de dégâts d'Ombre en 12 sec",
--     "de Feu", "des Arcanes", "du Sacré"; no school is physical
--   * "sec" or plain "s" for seconds ("en 8 s" on Rupture)
--   * bleeds may be stated as health lost ("perd 15 points de vie en 9 sec", Pourfendre)

local _, ClaraNS = ... -- (Clara Combo Points: DoesItDie built in; its own shared table, Bootstrap.lua)
if not ClaraNS.DoesItDieRuns then return end
local ns = ClaraNS.DoesItDiePrivate

local PHYSICAL = 1

-- Lower-cases a string and drops French accents, so school words match whatever the case and accents
-- ("Sacré"/"sacre", straight ' vs curly ’). UTF-8 bytes: \195\137 is É, \226\128\153 is ’.
local ACCENTS = {
    ["\195\137"] = "e", ["\195\169"] = "e", ["\195\136"] = "e", ["\195\168"] = "e", -- É é È è
    ["\195\138"] = "e", ["\195\170"] = "e", ["\195\139"] = "e", ["\195\171"] = "e", -- Ê ê Ë ë
    ["\195\128"] = "a", ["\195\160"] = "a", ["\195\130"] = "a", ["\195\162"] = "a", -- À à Â â
    ["\195\142"] = "i", ["\195\174"] = "i", ["\195\143"] = "i", ["\195\175"] = "i", -- Î î Ï ï
    ["\195\148"] = "o", ["\195\180"] = "o",                                         -- Ô ô
    ["\195\155"] = "u", ["\195\187"] = "u", ["\195\153"] = "u", ["\195\185"] = "u", -- Û û Ù ù
    ["\195\135"] = "c", ["\195\167"] = "c",                                         -- Ç ç
}
local function strip(s)
    s = s:gsub("\226\128\153", "'")
    s = s:gsub("\195[\128-\191]", ACCENTS)
    return s:lower()
end

-- The French client writes a non-breaking space (U+00A0 \194\160, or narrow U+202F \226\128\175) between the
-- number and "points" -- "78\194\160points de dégâts ..." -- which %s doesn't match, so the amount patterns miss
-- it (seen in-game: Immolation and Plaie d'agonie logged NOT READ, while Corruption, which uses an ordinary
-- space, worked). Immolation also reorders to "points supplémentaires de dégâts". Fix both before matching.
local function normalize(desc)
    desc = desc:gsub("\194\160", " "):gsub("\226\128\175", " ")
    desc = desc:gsub("points supplémentaires de dégâts", "points de dégâts supplémentaires")
    return desc
end

-- Accent-free stems of the school words, combined schools first.
local SCHOOL_STEMS = {
    { "givrefeu", 4 + 16 }, { "ombre", 32 }, { "arcane", 64 }, { "givre", 16 }, { "feu", 4 }, { "nature", 8 },
    { "sacr", 2 }, { "physique", 1 },
}
local function schoolOf(fragment)
    local f = strip(fragment)
    for _, pair in ipairs(SCHOOL_STEMS) do
        if f:find(pair[1], 1, true) then return pair[2] end
    end
    return PHYSICAL
end

-- French names of the spells in DoesItDie.lua's name-keyed tables. F: Forever's French tooltip; S: standard
-- Classic French name, confirm in-game. Names the client reports by spell ID are added at load anyway
-- (Locale.lua), so these mostly matter for spells without a known ID (Frostfire Bolt) and for the tests.
local NAMES = {
    ["Insect Swarm"] = { "Nuée d'insectes" },           -- S
    ["Bane of Agony"] = { "Plaie d'agonie" },           -- F (spell 980)
    ["Curse of Agony"] = { "Malédiction d'agonie" },    -- S
    ["Fireball"] = { "Boule de feu" },                  -- F
    ["Holy Fire"] = { "Flammes sacrées" },              -- F
    ["Rip"] = { "Déchirure" },                          -- F
    ["Siphon Life"] = { "Siphon de vie" },              -- F
    ["Serpent Sting"] = { "Morsure de serpent" },       -- F
    ["Pyroblast"] = { "Explosion pyrotechnique" },      -- F
    ["Frostfire Bolt"] = { "Trait de givrefeu" },       -- S (Forever's own spell)
    ["Rain of Fire"] = { "Pluie de feu" },              -- F
    ["Hellfire"] = { "Flammes infernales" },            -- F
    ["Flamestrike"] = { "Choc de flammes" },            -- F
    ["Consecration"] = { "Consécration" },              -- F
    ["Hurricane"] = { "Ouragan" },                      -- F
    ["Volley"] = { "Salve" },                           -- F
    ["Drain Life"] = { "Drain de vie" },                -- F
    ["Drain Soul"] = { "Siphon d'âme" },                -- F
    ["Drain Mana"] = { "Drain de mana" },               -- F
    ["Health Funnel"] = { "Captation de vie" },         -- F
    ["Mind Flay"] = { "Fouet mental" },                 -- F
    ["Arcane Missiles"] = { "Projectiles des arcanes" }, -- F
    ["Starshards"] = { "Éclats stellaires" },           -- F
    ["Immolation Trap"] = { "Piège immolation" },       -- S
    ["Explosive Trap"] = { "Piège explosif" },          -- S
    ["Wyvern Sting"] = { "Piqûre de wyverne" },         -- S
}

local function isFinisher(desc)
    desc = normalize(desc)
    return desc:find("Coup de grâce") ~= nil
end

-- Builders: "Vous gagnez 1 point de combo."
local function comboPointsAwarded(desc)
    desc = normalize(desc)
    return tonumber(desc:match("[Vv]ous gagnez%s+(%d+)%s*points? de combo"))
end

-- Finishers list a DoT per combo point: "1 point : 44 points de dégâts en 12 sec." (Déchirure),
-- "1 point : 25 points de dégâts en 8 s" (Rupture).
local function parseFinisher(desc, comboPoints)
    local byPoints, highest = {}, 0
    for pts, amount, secs in desc:gmatch("(%d+)%s*points?%s*:%s*(%d+)%s*points de dégâts en%s+(%d+%.?%d*)") do
        local points = tonumber(pts)
        byPoints[points] = { total = tonumber(amount), duration = tonumber(secs) }
        highest = math.max(highest, points)
    end
    if highest == 0 then return nil end
    local entry = byPoints[math.max(1, math.min(comboPoints, highest))] or byPoints[highest]
    return entry.total, PHYSICAL, entry.duration
end

local function parseDot(desc, comboPoints)
    desc = normalize(desc)
    if isFinisher(desc) then return parseFinisher(desc, comboPoints or 5) end
    -- Weapon enchants (rogue poisons: "Enduit une arme...") are proc DoTs, not cast on the target.
    if desc:find("[Ee]nduit") then return nil end
    -- Heals over time ("Rend/Soigne/Restaure N points de vie ...").
    if desc:find("^Rend ") or desc:find("^Soigne") or desc:find("^Restaure") then return nil end

    -- The last "<n> points de dégâts <school> en <secs> sec" clause, so a direct hit first (Immolation, Éclat
    -- lunaire, Boule de feu) yields the periodic part. The middle can't hold digits or dots, so it can't reach
    -- across to another clause.
    local total, school, duration
    for amount, mid, secs in desc:gmatch("(%d+)%s*points de dégâts([^%d.]*)en%s+(%d+%.?%d*)%s*s") do
        total, school, duration = tonumber(amount), schoolOf(mid), tonumber(secs)
    end
    if total and duration and duration > 0 then return total, school, duration end

    -- A bleed stated as health lost: "... saigne et perd 15 points de vie en 9 sec" (Pourfendre).
    local amount, secs = desc:match("perd%s+(%d+)%s*points de vie en%s+(%d+%.?%d*)%s*s")
    if amount and secs then return tonumber(amount), PHYSICAL, tonumber(secs) end

    -- A drain stated as a rate: "Transfère 11 points de vie ... toutes les 3 s. Dure 30 sec" (Siphon de vie; its
    -- school comes from SCHOOL_BY_NAME).
    local hp, every = desc:match("Transfère%s+(%d+)%s*points de vie.-toutes les%s+(%d+%.?%d*)%s*s")
    local lasts = desc:match("[Dd]ure%s+(%d+%.?%d*)%s*s")
    if hp and every and lasts then
        every, lasts = tonumber(every), tonumber(lasts)
        if every > 0 and lasts > 0 then
            return tonumber(hp) * math.floor(lasts / every + 0.5), PHYSICAL, lasts, every
        end
    end
end

-- The options window in this language: English text -> translation (see T in Locale.lua). Untranslated text
-- stays English. Every key, ready to fill in: python tools/test_load.py --dump-strings strings.lua
local STRINGS = { -- (Clara Combo Points: the options' text in French)
    ["%d learned tick sizes"] = "%d tailles de tick apprises",
    ["%d, every %gs (%gs)"] = "%d, toutes les %g s (%g s)",
    ["(%d-%d shown; scroll for more)"] = "(%d-%d affichés ; fais défiler pour la suite)",
    ["/did - open the options window"] = "/did - ouvrir la fenêtre d'options",
    ["/did debug - toggle echoing the trace log (casts, ticks, estimates) to chat"] = "/did debug - afficher ou non le journal de suivi (lancers, ticks, estimations) dans le chat",
    ["/did exec [percent] - test showing when the target is below 20% (or the given percent); again to stop"] = "/did exec [pourcentage] - tester l'affichage quand la cible est sous 20 % (ou le pourcentage donné) ; à nouveau pour arrêter",
    ["/did line - toggle health bar markers on/off"] = "/did line - activer ou couper les marqueurs sur la barre de vie",
    ["/did plates - check what the addon can reach on visible nameplates (logged)"] = "/did plates - vérifier ce que l'addon atteint sur les barres de nom visibles (dans le journal)",
    ["/did reset - forget learned tick sizes"] = "/did reset - oublier les tailles de tick apprises",
    ["/did skull - show the kill icon for 5 seconds to check its position"] = "/did skull - afficher l'icône de mort 5 secondes pour vérifier sa position",
    ["/did ticks - show learned tick sizes"] = "/did ticks - afficher les tailles de tick apprises",
    ["1 learned tick size"] = "1 taille de tick apprise",
    ["A bright flare on the marker's edge when a DoT lands."] = "Un éclat lumineux au bord du marqueur quand un DoT est posé.",
    ["Above the health bar"] = "Au-dessus de la barre de vie",
    ["Advanced"] = "Avancé",
    ["Always (real ticks only)"] = "Toujours (vrais ticks seulement)",
    ["Animates the diagonal stripes fill."] = "Anime le remplissage à rayures diagonales.",
    ["Auto (game client)"] = "Auto (client du jeu)",
    ["Black"] = "Noir",
    ["Bonus"] = "Bonus",
    ["Boss skull"] = "Crâne de boss",
    ["By spell school"] = "Par école de magie",
    ["Centered on the bar"] = "Centré sur la barre",
    ["Classic"] = "Classique",
    ["Click where the kill icon should go (you may need to move this window). Right-click cancels."] = "Clique là où doit aller l'icône de mort (il faudra peut-être déplacer cette fenêtre). Clic droit pour annuler.",
    ["Click your target's health bar (you may need to move this window). Right-click cancels."] = "Clique sur la barre de vie de ta cible (il faudra peut-être déplacer cette fenêtre). Clic droit pour annuler.",
    ["Color"] = "Couleur",
    ["Combo"] = "Combo",
    ["Combo points"] = "Points de combo",
    ["Copy from Marker tab"] = "Copier depuis l'onglet Marqueur",
    ["Copy from Nameplates tab"] = "Copier depuis l'onglet Barres de nom",
    ["Cyan"] = "Cyan",
    ["Dash length"] = "Longueur des tirets",
    ["Dashed"] = "En tirets",
    ["Dashes (8px)"] = "Tirets (8 px)",
    ["Debug"] = "Débogage",
    ["Diagonal stripes"] = "Rayures diagonales",
    ["Different color per DoT"] = "Une couleur par DoT",
    ["Dividers between DoTs"] = "Séparations entre les DoTs",
    ["DoT colors"] = "Couleurs des DoTs",
    ["DoT damage"] = "Dégâts des DoTs",
    ["DoTs finish it: the kill icon shows"] = "Les DoTs l'achèvent : l'icône de mort s'affiche",
    ["Dots (2px)"] = "Points (2 px)",
    ["Draws a marker (and optionally the kill icon) on every enemy nameplate with your DoTs on it, in its own look below."] = "Dessine un marqueur (et, au choix, l'icône de mort) sur chaque barre de nom ennemie qui porte tes DoTs, avec sa propre apparence ci-dessous.",
    ["Draws the marker (and optionally the kill icon) on your focus's health bar, for your DoTs on it, in its own look below. /cast [@focus] macros put the DoT on your focus. For another addon's focus frame, see the Advanced tab."] = "Dessine le marqueur (et, au choix, l'icône de mort) sur la barre de vie de ton focus, pour tes DoTs sur lui, avec sa propre apparence ci-dessous. Les macros /cast [@focus] posent le DoT sur ton focus. Pour le cadre de focus d'un autre addon, vois l'onglet Avancé.",
    ["Echo trace log to chat"] = "Journal de suivi dans le chat",
    ["Effects"] = "Effets",
    ["English"] = "Anglais",
    ["English text"] = "Texte anglais",
    ["Estimate during casting"] = "Estimer pendant l'incantation",
    ["Fade in from left"] = "Apparition depuis la gauche",
    ["Fill color"] = "Couleur de remplissage",
    ["Fill opacity"] = "Opacité du remplissage",
    ["Fill style"] = "Style de remplissage",
    ["Fine dots (1px)"] = "Points fins (1 px)",
    ["Flash"] = "Éclair",
    ["Flash on new DoT"] = "Éclair à chaque nouveau DoT",
    ["Flat"] = "Uni",
    ["Focus"] = "Focus",
    ["Focus bar in use"] = "Barre du focus utilisée",
    ["Focus health bar"] = "Barre de vie du focus",
    ["For unit frame addons that replace Blizzard's focus frame. Focus something, click Pick, then click its health bar. Leave empty for Blizzard's, or EllesmereUI's when it shows its own focus frame."] = "Pour les addons de cadres d'unité qui remplacent le cadre de focus du jeu. Mets quelque chose en focus, clique sur Choisir, puis sur sa barre de vie. Laisse vide pour celui du jeu, ou celui d'EllesmereUI quand il affiche le sien.",
    ["For unit frame addons that replace Blizzard's target frame. Target something, click Pick, then click its health bar. Or type the frame's name (/fstack shows it). The bar must fill left to right. Leave empty for Blizzard's, or EllesmereUI's when it shows its own target frame."] = "Pour les addons de cadres d'unité qui remplacent le cadre de cible du jeu. Cible quelque chose, clique sur Choisir, puis sur sa barre de vie. Ou écris le nom du cadre (/fstack l'affiche). La barre doit se remplir de gauche à droite. Laisse vide pour celui du jeu, ou celui d'EllesmereUI quand il affiche le sien.",
    ["Forget all"] = "Tout oublier",
    ["Forget this tick size"] = "Oublier cette taille de tick",
    ["Full duration"] = "Durée entière",
    ["Gently pulses the icon while it's showing."] = "Fait doucement pulser l'icône tant qu'elle est affichée.",
    ["Glow"] = "Halo",
    ["Glow size"] = "Taille du halo",
    ["Gold"] = "Or",
    ["Green"] = "Vert",
    ["Green checkmark"] = "Coche verte",
    ["Health bar in use"] = "Barre de vie utilisée",
    ["Health bar texture"] = "Texture de la barre de vie",
    ["Horizontal offset"] = "Décalage horizontal",
    ["Icon"] = "Icône",
    ["Icon horizontal offset"] = "Décalage horizontal de l'icône",
    ["Icon vertical offset"] = "Décalage vertical de l'icône",
    ["In combat: the marker and kill icon are showing on your target. The preview resumes after combat."] = "En combat : le marqueur et l'icône de mort s'affichent sur ta cible. L'aperçu reprend après le combat.",
    ["Inside the bar, right end"] = "Dans la barre, à droite",
    ["Juicy"] = "Juteux",
    ["Kill icon"] = "Icône de mort",
    ["Kill icon in use"] = "Icône de mort utilisée",
    ["Kill icon position"] = "Position de l'icône de mort",
    ["Kill icon size"] = "Taille de l'icône de mort",
    ["Kill icon spot"] = "Emplacement de l'icône de mort",
    ["Learned from this spell's ticks on your targets; used instead of the tooltip's number, which leaves out spell power and attack power."] = "Apprise sur les ticks de ce sort sur tes cibles ; utilisée à la place du chiffre de l'infobulle, qui ne compte ni la puissance des sorts ni la puissance d'attaque.",
    ["Learned per tick"] = "Appris par tick",
    ["Learned tick sizes"] = "Tailles de tick apprises",
    ["Left of the bar"] = "À gauche de la barre",
    ["Left of the health bar"] = "À gauche de la barre de vie",
    ["Live preview"] = "Aperçu en direct",
    ["Long dashes (16px)"] = "Longs tirets (16 px)",
    ["Marker"] = "Marqueur",
    ["Marker and kill icon"] = "Marqueur et icône de mort",
    ["Marker only"] = "Marqueur seul",
    ["Marks the damage your DoTs still have to deal on the target's health bar. If the health ends inside it, the target dies."] = "Marque sur la barre de vie de la cible les dégâts que tes DoTs doivent encore faire. Si la vie s'arrête dedans, la cible meurt.",
    ["Minimal"] = "Minimal",
    ["Most nameplate addons' health bars are found automatically (Plater, EllesmereUI, Platynator, ...). If the marker doesn't show on yours, type the keys from Blizzard's nameplate to its bar, like unitFrame.healthBar. /did plates logs what each plate uses. Leave empty for automatic."] = "Les barres de vie de la plupart des addons de barres de nom sont trouvées toutes seules (Plater, EllesmereUI, Platynator…). Si le marqueur ne s'affiche pas sur la tienne, écris le chemin depuis la barre de nom du jeu jusqu'à sa barre, comme unitFrame.healthBar. /did plates note ce qu'utilise chaque barre. Laisse vide pour la recherche automatique.",
    ["Mottled Boar"] = "Sanglier tacheté",
    ["Nameplate"] = "Barre de nom",
    ["Nameplate bar in use"] = "Barre de nom utilisée",
    ["Nameplate health bar"] = "Barre de vie des barres de nom",
    ["Nameplates"] = "Barres de nom",
    ["Never (estimate straight away)"] = "Jamais (estimer tout de suite)",
    ["No DoTs on the target"] = "Aucun DoT sur la cible",
    ["None"] = "Aucun",
    ["Nothing learned yet. Tick sizes are learned as your DoTs tick on your targets."] = "Rien d'appris pour l'instant. Les tailles de tick s'apprennent quand tes DoTs font effet sur tes cibles.",
    ["Off"] = "Désactivé",
    ["One color (fill color)"] = "Une couleur (celle du remplissage)",
    ["One color, or one segment per DoT colored by spell school or with a different color each."] = "Une seule couleur, ou un segment par DoT coloré selon l'école de magie ou d'une couleur différente chacun.",
    ["Open DoesItDie options"] = "Ouvrir les options de DoesItDie",
    ["Orange"] = "Orange",
    ["Outline"] = "Contour",
    ["Outline color"] = "Couleur du contour",
    ["Outline opacity"] = "Opacité du contour",
    ["Outline thickness"] = "Épaisseur du contour",
    ["Per tick"] = "Par tick",
    ["Pick"] = "Choisir",
    ["Picked %s."] = "%s choisi.",
    ["Pink"] = "Rose",
    ["Pixels right (+) or left (-) of the chosen position."] = "Pixels à droite (+) ou à gauche (-) de la position choisie.",
    ["Pixels right (+) or left (-) of the portrait's center (or the custom spot's, see Advanced)."] = "Pixels à droite (+) ou à gauche (-) du centre du portrait (ou de l'emplacement choisi, voir Avancé).",
    ["Pixels up (+) or down (-) from the chosen position."] = "Pixels vers le haut (+) ou le bas (-) depuis la position choisie.",
    ["Pixels up (+) or down (-) from the portrait's center (or the custom spot's, see Advanced)."] = "Pixels vers le haut (+) ou le bas (-) depuis le centre du portrait (ou de l'emplacement choisi, voir Avancé).",
    ["Position"] = "Position",
    ["Presets"] = "Préréglages",
    ["Prints each DoT cast, matched tick and estimate to chat."] = "Écrit dans le chat chaque DoT lancé, chaque tick reconnu et chaque estimation.",
    ["Pulse"] = "Pulsation",
    ["Pulse outline"] = "Contour pulsant",
    ["Purple"] = "Violet",
    ["Raid bar texture"] = "Texture des barres de raid",
    ["Raid skull"] = "Crâne de raid",
    ["Red"] = "Rouge",
    ["Red X"] = "Croix rouge",
    ["Remaining DoT damage next to the health bar (a per-DoT breakdown with DoT colors)."] = "Les dégâts restants des DoTs à côté de la barre de vie (le détail par DoT, à leurs couleurs).",
    ["Remaining damage of two sample DoTs, in % of the target's max health."] = "Dégâts restants de deux DoTs d'exemple, en % de la vie maximale de la cible.",
    ["Reset"] = "Réinitialiser",
    ["Reset this tab"] = "Réinitialiser cet onglet",
    ["Right of the health bar"] = "À droite de la barre de vie",
    ["Scroll stripes"] = "Rayures défilantes",
    ["Settings have their own window with a live preview. You can also type /did."] = "Les réglages ont leur propre fenêtre avec un aperçu en direct. Tu peux aussi taper /did.",
    ["Shift-click to link it in chat."] = "Maj-clic pour le mettre en lien dans le chat.",
    ["Shine every"] = "Reflet toutes les",
    ["Shine sweep"] = "Reflet balayant",
    ["Short dashes (4px)"] = "Tirets courts (4 px)",
    ["Show damage marker"] = "Afficher le marqueur de dégâts",
    ["Show damage text"] = "Afficher le texte des dégâts",
    ["Show icon on portrait"] = "Afficher l'icône sur le portrait",
    ["Show on focus frame"] = "Afficher sur le cadre du focus",
    ["Show on nameplates"] = "Afficher sur les barres de nom",
    ["Shows a DoT with a cast time while you're still casting it. Once the cast lands the normal estimate takes over; an interrupted or failed cast removes it."] = "Compte un DoT à temps d'incantation pendant que tu l'incantes encore. Une fois l'incantation finie, l'estimation normale prend le relais ; une incantation interrompue ou ratée le retire.",
    ["Shows an icon over the target's portrait when your DoTs on it will kill it."] = "Affiche une icône sur le portrait de la cible quand tes DoTs vont la tuer.",
    ["Simulate fight"] = "Simuler un combat",
    ["Size"] = "Taille",
    ["Smooth motion"] = "Mouvement fluide",
    ["Soft halo in the outline color."] = "Un halo doux de la couleur du contour.",
    ["Solid"] = "Plein",
    ["Spark"] = "Étincelle",
    ["Spell"] = "Sort",
    ["Stop"] = "Arrêter",
    ["Sunglasses"] = "Lunettes de soleil",
    ["Survives by %d%% of its health"] = "Survit avec %d%% de sa vie",
    ["Target health"] = "Vie de la cible",
    ["Target health bar"] = "Barre de vie de la cible",
    ["Test"] = "Test",
    ["Text"] = "Texte",
    ["The kill icon on the target's portrait means your DoTs will kill it."] = "L'icône de mort sur le portrait de la cible veut dire que tes DoTs vont la tuer.",
    ["The language of this window and the addon's messages. Auto follows your game client. Changes apply after /reload."] = "La langue de cette fenêtre et des messages de l'addon. Auto suit ton client de jeu. Le changement s'applique après un /reload.",
    ["The marker grows in when it appears and glides to new values instead of jumping."] = "Le marqueur grandit en apparaissant et glisse vers ses nouvelles valeurs au lieu de sauter.",
    ["The next cast starts from the tooltip again and learns it anew."] = "Le prochain lancer repart de l'infobulle et la réapprend.",
    ["The window language changes after a /reload."] = "La langue de la fenêtre change après un /reload.",
    ["Ticks"] = "Ticks",
    ["Tooltip"] = "Infobulle",
    ["Tooltip per tick"] = "Infobulle par tick",
    ["Total"] = "Total",
    ["Used when DoT colors is set to one color."] = "Utilisée quand Couleurs des DoTs est sur une seule couleur.",
    ["Vertical offset"] = "Décalage vertical",
    ["View"] = "Voir",
    ["Wait for first tick"] = "Attendre le premier tick",
    ["What each DoT really ticks for, learned from your casts and used instead of its tooltip. Tooltips leave out spell power and attack power: Bonus is how much more yours do. Hover a spell for details, shift-click to link it."] = "Ce que chaque DoT inflige vraiment par tick, appris sur tes lancers et utilisé à la place de son infobulle. Les infobulles ne comptent ni la puissance des sorts ni la puissance d'attaque : Bonus est ce que les tiens font en plus. Survole un sort pour le détail, Maj-clic pour le mettre en lien.",
    ["What each of your DoTs really ticks for, learned from earlier casts, next to what its tooltip says. Reset forgets them all."] = "Ce que chacun de tes DoTs inflige vraiment par tick, appris sur tes lancers précédents, à côté de ce que dit son infobulle. Réinitialiser les oublie tous.",
    ["When unsure"] = "En cas de doute",
    ["Where the kill icon is centered (e.g. the custom frame's portrait). Empty: Blizzard's portrait, or EllesmereUI's when its target frame shows one; else the health bar in use. Fine-tune with the offsets on the Kill icon tab."] = "Où l'icône de mort est centrée (par exemple le portrait du cadre choisi). Vide : le portrait du jeu, ou celui d'EllesmereUI quand son cadre de cible en a un ; sinon la barre de vie utilisée. Ajuste avec les décalages de l'onglet Icône de mort.",
    ["Whether a new DoT counts before its first tick lands. \"When unsure\" waits for finishers with unknown combo points and spells the addon hasn't seen tick yet."] = "Si un nouveau DoT compte avant son premier tick. \"En cas de doute\" attend pour les coups de grâce aux points de combo inconnus et les sorts dont l'addon n'a pas encore vu un tick.",
    ["While this window is open, the marker and kill icon are drawn here instead of on your target."] = "Tant que cette fenêtre est ouverte, le marqueur et l'icône de mort sont dessinés ici au lieu de sur ta cible.",
    ["White"] = "Blanc",
    ["Window language"] = "Langue de la fenêtre",
    ["%s preset applied."] = "Préréglage %s appliqué.",
    ["Couldn't create the options panel; slash commands still work (/did help)."] = "Impossible de créer le panneau d'options ; les commandes marchent toujours (/did help).",
    ["Debug OFF."] = "Débogage DÉSACTIVÉ.",
    ["Debug ON."] = "Débogage ACTIVÉ.",
    ["Frame pick cancelled."] = "Choix du cadre annulé.",
    ["Health bar markers OFF."] = "Marqueurs sur la barre de vie DÉSACTIVÉS.",
    ["Health bar markers ON."] = "Marqueurs sur la barre de vie ACTIVÉS.",
    ["Kill icon test for 5 seconds: one icon ON the portrait (the real one) and one ABOVE it (plain test)."] = "Test de l'icône de mort pendant 5 secondes : une icône SUR le portrait (la vraie) et une AU-DESSUS (simple test).",
    ["Learned tick sizes cleared."] = "Tailles de tick apprises effacées.",
    ["Nothing to pick there."] = "Rien à choisir ici.",
    ["Target frame health bar not found; health bar markers unavailable."] = "Barre de vie du cadre de cible introuvable ; marqueurs sur la barre de vie indisponibles.",
    ["Target portrait not found; kill icon shown beside the target frame."] = "Portrait de la cible introuvable ; l'icône de mort s'affiche à côté du cadre de cible.",
    ["That frame has no name to save, so it can't be found again after a reload. Try the frame around it, or type a path."] = "Ce cadre n'a pas de nom à enregistrer : il serait introuvable après un /reload. Essaie le cadre qui l'entoure, ou écris un chemin.",
    ["Default (the game's look)"] = "Par défaut (l'apparence du jeu)",
    ["Apply"] = "Appliquer",
    ["Open the window"] = "Ouvrir la fenêtre",
    ["Set in the window"] = "Régler dans la fenêtre",
}

ns.locale.register({
    tag = "frFR",
    label = "Français",
    strings = STRINGS,
    parseDot = parseDot,
    isFinisher = isFinisher,
    comboPointsAwarded = comboPointsAwarded,
    names = NAMES,
})
