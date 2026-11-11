--[[
    MinimapDrawer
    Rassemble les boutons d'addons de la minimap dans un menu contextuel.

    - Survol du cercle du niveau pendant N secondes (réglable) : ouvre le menu
      (/mmd autoopen ou /mmd ao : active / désactive cette ouverture au survol, le clic reste actif)
    - Clic sur le cercle du niveau : ouvre / ferme le menu
    - Bouton X en haut à droite du menu : ferme le menu
    - Double clic molette sur le cadre du joueur (portrait, nom, barres de vie et de mana) : /reload
      (/mmd portrait : on / off)
    - Cadenas à gauche du X : fermé = verrouillé, ouvert = déverrouillé ; un clic bascule
      (même fonction que /mmd lock, qui alterne aussi)
    - Les icônes se remplissent de droite à gauche, puis s'empilent vers le haut
    - /mmd unlock : le cercle rouge et le menu se déplacent INDÉPENDAMMENT. Tant que
      l'addon est déverrouillé, le menu est recouvert d'un voile rouge « Move me! »
      (texte dans la langue du client). /mmd lock verrouille et enregistre.

    - Glisser-déposer natif (sans réglage) : une icône du menu qu'on lâche en dehors du menu
      est détachée et se place librement à l'écran (position mémorisée). Inversement, une
      icône libre lâchée sur le menu ouvert est rattachée au menu.
    - En mode /mmd lock, une icône libre qui ne bouge pas pendant 5 s est verrouillée ;
      /mmd unlock ou /mmd lock la libère à nouveau. Maj + clic gauche maintenu sur une icône
      verrouillée contourne le verrou (puis 5 s de délai de grâce avant de se reverrouiller).

    - Réarrangement : on glisse une icône (du menu ou libre) sur le menu ouvert ; après 200 ms
      au-dessus d'un emplacement, les autres icônes se décalent pour lui laisser la place (aperçu
      en direct, suit le curseur). Au dépôt, l'icône prend cet emplacement et l'ordre est mémorisé
      (DB.order). Les nouvelles icônes sont ajoutées en fin de liste. /mmd reset remet l'ordre
      alphabétique.

    /mmd pour la liste des commandes.
    /rl : raccourci pour /reload (toujours actif, sans option).
]]

local _, ClaraNS = ... -- (Clara Combo Points: MinimapDrawer built in, QoL.lua)
if not (type(ClaraNS) == "table" and ClaraNS.MinimapDrawerRuns) then return end
local ADDON_NAME = "ClaraComboPoints" -- (its settings load with Clara's: ClaraMinimapDrawerDB)

---------------------------------------------------------------------
-- Constantes
---------------------------------------------------------------------
local ICON_SIZE            = 31     -- taille visée pour chaque bouton
local STEP                 = 38     -- pas entre deux icônes
local PAD_X                = 9      -- marge gauche / droite
local PAD_BOTTOM           = 8      -- marge en bas
local HEADER_H             = 30     -- hauteur de l'en-tête (slider, champ, X)
local MIN_WIDTH            = 170    -- largeur minimale (= largeur de l'en-tête)
local DOUBLE_CLICK_WINDOW  = 0.4
local MAX_DELAY            = 5
local DEFAULT_HOTSPOT_SIZE = 30

local DEFAULTS = {
    delay   = 1.0,  -- délai de survol avant ouverture (secondes)
    columns = 4,    -- icônes par ligne
    autoopen = true, -- ouverture automatique du menu au survol de la zone d'activation
    portraitReload = true, -- double clic molette sur le portrait du personnage = /reload
    -- Décalage initial du coin bas-droit du menu par rapport au centre de la zone.
    -- Utilisé une seule fois (premier lancement / migration d'une ancienne version) :
    -- ensuite le menu a sa propre position absolue (DB.menuPos), indépendante de la zone.
    menuX   = 232,
    menuY   = 66,
}

-- Voile rouge affiché sur le menu en mode déplacement (opacité 0.40 - 0.50)
local OVERLAY_ALPHA = 0.45
local OVERLAY_INSET = 5   -- = insets du backdrop tooltip : le voile reste dans le cadre

-- Textes affichés au joueur, selon la langue du client WoW (repli : anglais pour toute clé absente)
local LOCALES = {}

LOCALES.enUS = {
    move_me = "Move me!",
    empty = "No minimap button detected",
    slider_tip = "Hover delay before the menu opens\n(in seconds, 2 decimals)",
    edit_tip = "Hover delay before the menu opens\n(in seconds, e.g. 1.55)",
    hint = "Drag me · wheel = size · /mmd lock",
    lock_on_tip = "Unlocked: click to lock and save",
    lock_off_tip = "Locked: click to unlock and move",
    icon_locked = "icon locked: Shift + drag to move it (or /mmd unlock, /mmd lock).",
    msg_locked = "positions saved (locked).",
    msg_unlocked = "move mode enabled (unlocked). /mmd lock or the padlock to confirm.",
    msg_unlock_cmd = "move mode enabled. /mmd lock to confirm.",
    msg_autoopen = "automatic opening on hover: %s",
    msg_portrait = "double middle-click on the player frame = /reload: %s",
    msg_delay = "hover delay: %s s",
    usage_delay = "usage: /mmd delay 1.55",
    msg_cols = "icons per row: %d",
    usage_cols = "usage: /mmd cols 4",
    list_none = "no button captured.",
    list_count = "%d button(s) captured:",
    tag_free_locked = "(free, locked)",
    tag_free = "(free on screen)",
    tag_hidden = "(hidden by its addon)",
    no_name = "(unnamed)",
    dbg_title = "drag-and-drop diagnostics for captured buttons:",
    dbg_line = "  %s | %s | drag=%s | movable=%s | lock=%s",
    dbg_free = "free", dbg_menu = "menu", dbg_ok = "ok", dbg_over = "overwritten", dbg_yes = "yes", dbg_no = "no",
    ignore_msg = "%s will stay on the minimap after /reload.",
    unignore_msg = "%s will be captured again after /reload.",
    reset_msg = "settings reset. Place the red zone and the menu again, then /mmd lock.",
    first1 = "first launch! Drag the red zone onto your character's level circle",
    first2 = "(wheel = size). The menu (red veil) moves separately. Then type /mmd lock.",
    help_title = "commands:",
    h_unlock1 = "  /mmd unlock  - move mode: drag the red zone onto the level circle (wheel = size)",
    h_unlock2 = "                 and drag the menu (red veil) separately",
    h_lock = "  /mmd lock  - toggles locked / unlocked (like the menu padlock) and saves positions",
    h_toggle = "  /mmd toggle  - opens / closes the menu",
    h_autoopen = "  /mmd autoopen (or /mmd ao)  - open the menu on hover: toggle on / off (clicking still works)",
    h_portrait = "  /mmd portrait  - double middle-click on the player frame (portrait, name, health, mana) = /reload: toggle on / off",
    h_delay = "  /mmd delay <seconds>  - hover delay (e.g. 1.55)",
    h_cols = "  /mmd cols <2-12>  - icons per row (default 4)",
    h_list = "  /mmd list  - lists captured buttons",
    h_debug = "  /mmd debug  - drag-and-drop diagnostics for each button",
    h_reorder = "  (drag an icon onto the menu to reorder it: preview after 200 ms, order is saved)",
    h_free1 = "  (drag an icon out of the menu to free it; drop it on the open menu to put it back.",
    h_free2 = "   In lock mode, a free icon left still for 5 s gets locked: Shift + drag, /mmd unlock or /mmd lock releases it)",
    h_ignore = "  /mmd ignore <name>  /  unignore <name>  - exclude a button (after /reload)",
    h_reset = "  /mmd reset  - restore all defaults",
    h_rl = "  /rl  - reloads the UI (shortcut for /reload)",
}

LOCALES.frFR = {
    move_me = "Déplace-moi !",
    empty = "Aucun bouton de minimap détecté",
    slider_tip = "Délai de survol avant l'ouverture du menu\n(en secondes, 2 décimales)",
    edit_tip = "Délai de survol avant l'ouverture du menu\n(en secondes, ex : 1.55)",
    hint = "Glisse-moi · molette = taille · /mmd lock",
    lock_on_tip = "Déverrouillé : clique pour verrouiller et enregistrer",
    lock_off_tip = "Verrouillé : clique pour déverrouiller et déplacer",
    icon_locked = "icône verrouillée : Maj + glisser pour la déplacer (ou /mmd unlock, /mmd lock).",
    msg_locked = "positions enregistrées (verrouillé).",
    msg_unlocked = "mode déplacement activé (déverrouillé). /mmd lock ou le verrou pour valider.",
    msg_unlock_cmd = "mode déplacement activé. /mmd lock pour valider.",
    msg_autoopen = "ouverture automatique au survol : %s",
    msg_portrait = "double clic molette sur le cadre du joueur = /reload : %s",
    msg_delay = "délai de survol : %s s",
    usage_delay = "usage : /mmd delay 1.55",
    msg_cols = "icônes par ligne : %d",
    usage_cols = "usage : /mmd cols 4",
    list_none = "aucun bouton capturé.",
    list_count = "%d bouton(s) capturé(s) :",
    tag_free_locked = "(libre, verrouillée)",
    tag_free = "(libre sur l'écran)",
    tag_hidden = "(masqué par son addon)",
    no_name = "(sans nom)",
    dbg_title = "diagnostic des boutons capturés :",
    dbg_line = "  %s | %s | glisser=%s | déplaçable=%s | verrou=%s",
    dbg_free = "libre", dbg_menu = "menu", dbg_ok = "ok", dbg_over = "écrasé", dbg_yes = "oui", dbg_no = "non",
    ignore_msg = "%s sera laissé sur la minimap après /reload.",
    unignore_msg = "%s sera de nouveau capturé après /reload.",
    reset_msg = "réglages réinitialisés. Replace la zone rouge et le menu puis /mmd lock.",
    first1 = "premier lancement ! Glisse la zone rouge sur le cercle du niveau de ton personnage",
    first2 = "(molette = taille). Le menu (voile rouge) se déplace séparément. Puis tape /mmd lock.",
    help_title = "commandes :",
    h_unlock1 = "  /mmd unlock  - mode déplacement : glisse la zone rouge sur le cercle du niveau (molette = taille)",
    h_unlock2 = "                 et glisse le menu (voile rouge) séparément",
    h_lock = "  /mmd lock  - alterne verrouillé / déverrouillé (comme le cadenas du menu) et enregistre les positions",
    h_toggle = "  /mmd toggle  - ouvre / ferme le menu",
    h_autoopen = "  /mmd autoopen (ou /mmd ao)  - ouverture du menu au survol de la zone : bascule on / off (le clic reste actif)",
    h_portrait = "  /mmd portrait  - double clic molette sur le cadre du joueur (portrait, nom, vie, mana) = /reload : bascule on / off",
    h_delay = "  /mmd delay <secondes>  - délai de survol (ex : 1.55)",
    h_cols = "  /mmd cols <2-12>  - icônes par ligne (défaut 4)",
    h_list = "  /mmd list  - liste les boutons capturés",
    h_debug = "  /mmd debug  - diagnostic du glisser-déposer pour chaque bouton",
    h_reorder = "  (glisse une icône sur le menu pour la réordonner : aperçu après 200 ms, ordre mémorisé)",
    h_free1 = "  (glisse une icône hors du menu pour la libérer ; lâche-la sur le menu ouvert pour la remettre.",
    h_free2 = "   En mode lock, une icône libre immobile 5 s est verrouillée : Maj + glisser, /mmd unlock ou /mmd lock la libère)",
    h_ignore = "  /mmd ignore <nom>  /  unignore <nom>  - exclure un bouton (après /reload)",
    h_reset = "  /mmd reset  - remet tout par défaut",
    h_rl = "  /rl  - recharge l'interface (raccourci de /reload)",
}

LOCALES.deDE = {
    move_me = "Verschieb mich!",
    empty = "Keine Minimap-Schaltfläche gefunden",
    slider_tip = "Verzögerung beim Überfahren, bevor sich das Menü öffnet\n(in Sekunden, 2 Dezimalstellen)",
    edit_tip = "Verzögerung beim Überfahren, bevor sich das Menü öffnet\n(in Sekunden, z. B. 1.55)",
    hint = "Zieh mich · Mausrad = Größe · /mmd lock",
    lock_on_tip = "Entsperrt: Klicken zum Sperren und Speichern",
    lock_off_tip = "Gesperrt: Klicken zum Entsperren und Verschieben",
    icon_locked = "Symbol gesperrt: Umschalt + Ziehen zum Verschieben (oder /mmd unlock, /mmd lock).",
    msg_locked = "Positionen gespeichert (gesperrt).",
    msg_unlocked = "Verschiebemodus aktiv (entsperrt). /mmd lock oder das Schloss zum Bestätigen.",
    msg_unlock_cmd = "Verschiebemodus aktiv. /mmd lock zum Bestätigen.",
    msg_autoopen = "automatisches Öffnen beim Überfahren: %s",
    msg_portrait = "Doppelklick mit dem Mausrad auf den Spielerrahmen = /reload: %s",
    msg_delay = "Überfahr-Verzögerung: %s s",
    usage_delay = "Verwendung: /mmd delay 1.55",
    msg_cols = "Symbole pro Zeile: %d",
    usage_cols = "Verwendung: /mmd cols 4",
    list_none = "keine Schaltfläche erfasst.",
    list_count = "%d Schaltfläche(n) erfasst:",
    tag_free_locked = "(frei, gesperrt)",
    tag_free = "(frei auf dem Bildschirm)",
    tag_hidden = "(von seinem Addon ausgeblendet)",
    no_name = "(ohne Namen)",
    dbg_title = "Drag-and-drop-Diagnose der erfassten Schaltflächen:",
    dbg_line = "  %s | %s | Ziehen=%s | verschiebbar=%s | Sperre=%s",
    dbg_free = "frei", dbg_menu = "Menü", dbg_ok = "ok", dbg_over = "überschrieben", dbg_yes = "ja", dbg_no = "nein",
    ignore_msg = "%s bleibt nach /reload auf der Minimap.",
    unignore_msg = "%s wird nach /reload wieder erfasst.",
    reset_msg = "Einstellungen zurückgesetzt. Platziere die rote Zone und das Menü neu, dann /mmd lock.",
    first1 = "erster Start! Zieh die rote Zone auf den Stufenkreis deines Charakters",
    first2 = "(Mausrad = Größe). Das Menü (roter Schleier) wird separat verschoben. Dann /mmd lock eingeben.",
    help_title = "Befehle:",
    h_unlock1 = "  /mmd unlock  - Verschiebemodus: rote Zone auf den Stufenkreis ziehen (Mausrad = Größe)",
    h_unlock2 = "                 und das Menü (roter Schleier) getrennt verschieben",
    h_lock = "  /mmd lock  - wechselt gesperrt / entsperrt (wie das Schloss im Menü) und speichert die Positionen",
    h_toggle = "  /mmd toggle  - öffnet / schließt das Menü",
    h_autoopen = "  /mmd autoopen (oder /mmd ao)  - Menü beim Überfahren öffnen: an / aus (Klicken funktioniert weiter)",
    h_portrait = "  /mmd portrait  - Mausrad-Doppelklick auf den Spielerrahmen (Porträt, Name, Leben, Mana) = /reload: an / aus",
    h_delay = "  /mmd delay <Sekunden>  - Überfahr-Verzögerung (z. B. 1.55)",
    h_cols = "  /mmd cols <2-12>  - Symbole pro Zeile (Standard 4)",
    h_list = "  /mmd list  - listet erfasste Schaltflächen auf",
    h_debug = "  /mmd debug  - Drag-and-drop-Diagnose für jede Schaltfläche",
    h_reorder = "  (Symbol auf das Menü ziehen, um es umzusortieren: Vorschau nach 200 ms, Reihenfolge wird gespeichert)",
    h_free1 = "  (Symbol aus dem Menü ziehen, um es zu lösen; auf das offene Menü ziehen, um es zurückzulegen.",
    h_free2 = "   Im Sperrmodus wird ein freies Symbol nach 5 s Ruhe gesperrt: Umschalt + Ziehen, /mmd unlock oder /mmd lock löst es)",
    h_ignore = "  /mmd ignore <Name>  /  unignore <Name>  - Schaltfläche ausschließen (nach /reload)",
    h_reset = "  /mmd reset  - alles auf Standard zurücksetzen",
    h_rl = "  /rl  - lädt die Oberfläche neu (Kürzel für /reload)",
}

LOCALES.esES = {
    move_me = "¡Muéveme!",
    empty = "No se detectó ningún botón del minimapa",
    slider_tip = "Retardo al pasar el ratón antes de abrir el menú\n(en segundos, 2 decimales)",
    edit_tip = "Retardo al pasar el ratón antes de abrir el menú\n(en segundos, p. ej. 1.55)",
    hint = "Arrástrame · rueda = tamaño · /mmd lock",
    lock_on_tip = "Desbloqueado: haz clic para bloquear y guardar",
    lock_off_tip = "Bloqueado: haz clic para desbloquear y mover",
    icon_locked = "icono bloqueado: Mayús + arrastrar para moverlo (o /mmd unlock, /mmd lock).",
    msg_locked = "posiciones guardadas (bloqueado).",
    msg_unlocked = "modo de movimiento activado (desbloqueado). /mmd lock o el candado para confirmar.",
    msg_unlock_cmd = "modo de movimiento activado. /mmd lock para confirmar.",
    msg_autoopen = "apertura automática al pasar el ratón: %s",
    msg_portrait = "doble clic de rueda en el marco del jugador = /reload: %s",
    msg_delay = "retardo: %s s",
    usage_delay = "uso: /mmd delay 1.55",
    msg_cols = "iconos por fila: %d",
    usage_cols = "uso: /mmd cols 4",
    list_none = "ningún botón capturado.",
    list_count = "%d botón(es) capturado(s):",
    tag_free_locked = "(libre, bloqueado)",
    tag_free = "(libre en pantalla)",
    tag_hidden = "(oculto por su addon)",
    no_name = "(sin nombre)",
    dbg_title = "diagnóstico de arrastrar y soltar de los botones capturados:",
    dbg_line = "  %s | %s | arrastrar=%s | movible=%s | bloqueo=%s",
    dbg_free = "libre", dbg_menu = "menú", dbg_ok = "ok", dbg_over = "sobrescrito", dbg_yes = "sí", dbg_no = "no",
    ignore_msg = "%s se quedará en el minimapa tras /reload.",
    unignore_msg = "%s volverá a capturarse tras /reload.",
    reset_msg = "ajustes restablecidos. Coloca de nuevo la zona roja y el menú, luego /mmd lock.",
    first1 = "¡primer inicio! Arrastra la zona roja sobre el círculo de nivel de tu personaje",
    first2 = "(rueda = tamaño). El menú (velo rojo) se mueve por separado. Luego escribe /mmd lock.",
    help_title = "comandos:",
    h_unlock1 = "  /mmd unlock  - modo de movimiento: arrastra la zona roja sobre el círculo de nivel (rueda = tamaño)",
    h_unlock2 = "                 y arrastra el menú (velo rojo) por separado",
    h_lock = "  /mmd lock  - alterna bloqueado / desbloqueado (como el candado del menú) y guarda las posiciones",
    h_toggle = "  /mmd toggle  - abre / cierra el menú",
    h_autoopen = "  /mmd autoopen (o /mmd ao)  - abrir el menú al pasar el ratón: activar / desactivar (el clic sigue funcionando)",
    h_portrait = "  /mmd portrait  - doble clic de rueda en el marco del jugador (retrato, nombre, vida, maná) = /reload: activar / desactivar",
    h_delay = "  /mmd delay <segundos>  - retardo al pasar el ratón (p. ej. 1.55)",
    h_cols = "  /mmd cols <2-12>  - iconos por fila (por defecto 4)",
    h_list = "  /mmd list  - lista los botones capturados",
    h_debug = "  /mmd debug  - diagnóstico de arrastrar y soltar para cada botón",
    h_reorder = "  (arrastra un icono sobre el menú para reordenarlo: vista previa tras 200 ms, el orden se guarda)",
    h_free1 = "  (arrastra un icono fuera del menú para liberarlo; suéltalo sobre el menú abierto para devolverlo.",
    h_free2 = "   En modo bloqueado, un icono libre inmóvil 5 s se bloquea: Mayús + arrastrar, /mmd unlock o /mmd lock lo libera)",
    h_ignore = "  /mmd ignore <nombre>  /  unignore <nombre>  - excluir un botón (tras /reload)",
    h_reset = "  /mmd reset  - restablece todo por defecto",
    h_rl = "  /rl  - recarga la interfaz (atajo de /reload)",
}

LOCALES.itIT = {
    move_me = "Spostami!",
    empty = "Nessun pulsante della minimappa rilevato",
    slider_tip = "Ritardo al passaggio del mouse prima dell'apertura del menu\n(in secondi, 2 decimali)",
    edit_tip = "Ritardo al passaggio del mouse prima dell'apertura del menu\n(in secondi, es. 1.55)",
    hint = "Trascinami · rotellina = dimensione · /mmd lock",
    lock_on_tip = "Sbloccato: clic per bloccare e salvare",
    lock_off_tip = "Bloccato: clic per sbloccare e spostare",
    icon_locked = "icona bloccata: Maiusc + trascina per spostarla (o /mmd unlock, /mmd lock).",
    msg_locked = "posizioni salvate (bloccato).",
    msg_unlocked = "modalità spostamento attiva (sbloccato). /mmd lock o il lucchetto per confermare.",
    msg_unlock_cmd = "modalità spostamento attiva. /mmd lock per confermare.",
    msg_autoopen = "apertura automatica al passaggio del mouse: %s",
    msg_portrait = "doppio clic della rotellina sul riquadro del giocatore = /reload: %s",
    msg_delay = "ritardo: %s s",
    usage_delay = "uso: /mmd delay 1.55",
    msg_cols = "icone per riga: %d",
    usage_cols = "uso: /mmd cols 4",
    list_none = "nessun pulsante catturato.",
    list_count = "%d pulsante/i catturato/i:",
    tag_free_locked = "(libera, bloccata)",
    tag_free = "(libera sullo schermo)",
    tag_hidden = "(nascosto dal suo addon)",
    no_name = "(senza nome)",
    dbg_title = "diagnostica del trascinamento dei pulsanti catturati:",
    dbg_line = "  %s | %s | trascina=%s | spostabile=%s | blocco=%s",
    dbg_free = "libera", dbg_menu = "menu", dbg_ok = "ok", dbg_over = "sovrascritto", dbg_yes = "sì", dbg_no = "no",
    ignore_msg = "%s resterà sulla minimappa dopo /reload.",
    unignore_msg = "%s verrà catturato di nuovo dopo /reload.",
    reset_msg = "impostazioni ripristinate. Riposiziona la zona rossa e il menu, poi /mmd lock.",
    first1 = "primo avvio! Trascina la zona rossa sul cerchio del livello del tuo personaggio",
    first2 = "(rotellina = dimensione). Il menu (velo rosso) si sposta separatamente. Poi digita /mmd lock.",
    help_title = "comandi:",
    h_unlock1 = "  /mmd unlock  - modalità spostamento: trascina la zona rossa sul cerchio del livello (rotellina = dimensione)",
    h_unlock2 = "                 e trascina il menu (velo rosso) separatamente",
    h_lock = "  /mmd lock  - alterna bloccato / sbloccato (come il lucchetto del menu) e salva le posizioni",
    h_toggle = "  /mmd toggle  - apre / chiude il menu",
    h_autoopen = "  /mmd autoopen (o /mmd ao)  - apri il menu al passaggio del mouse: attiva / disattiva (il clic funziona comunque)",
    h_portrait = "  /mmd portrait  - doppio clic della rotellina sul riquadro del giocatore (ritratto, nome, vita, mana) = /reload: attiva / disattiva",
    h_delay = "  /mmd delay <secondi>  - ritardo al passaggio del mouse (es. 1.55)",
    h_cols = "  /mmd cols <2-12>  - icone per riga (predefinito 4)",
    h_list = "  /mmd list  - elenca i pulsanti catturati",
    h_debug = "  /mmd debug  - diagnostica del trascinamento per ogni pulsante",
    h_reorder = "  (trascina un'icona sul menu per riordinarla: anteprima dopo 200 ms, l'ordine viene salvato)",
    h_free1 = "  (trascina un'icona fuori dal menu per liberarla; rilasciala sul menu aperto per rimetterla.",
    h_free2 = "   In modalità lock, un'icona libera ferma per 5 s viene bloccata: Maiusc + trascina, /mmd unlock o /mmd lock la libera)",
    h_ignore = "  /mmd ignore <nome>  /  unignore <nome>  - escludi un pulsante (dopo /reload)",
    h_reset = "  /mmd reset  - ripristina tutto",
    h_rl = "  /rl  - ricarica l'interfaccia (scorciatoia di /reload)",
}

LOCALES.ptBR = {
    move_me = "Mova-me!",
    empty = "Nenhum botão do minimapa detectado",
    slider_tip = "Atraso ao passar o mouse antes de abrir o menu\n(em segundos, 2 casas decimais)",
    edit_tip = "Atraso ao passar o mouse antes de abrir o menu\n(em segundos, ex.: 1.55)",
    hint = "Arraste-me · roda = tamanho · /mmd lock",
    lock_on_tip = "Desbloqueado: clique para bloquear e salvar",
    lock_off_tip = "Bloqueado: clique para desbloquear e mover",
    icon_locked = "ícone bloqueado: Shift + arrastar para movê-lo (ou /mmd unlock, /mmd lock).",
    msg_locked = "posições salvas (bloqueado).",
    msg_unlocked = "modo de movimento ativado (desbloqueado). /mmd lock ou o cadeado para confirmar.",
    msg_unlock_cmd = "modo de movimento ativado. /mmd lock para confirmar.",
    msg_autoopen = "abertura automática ao passar o mouse: %s",
    msg_portrait = "clique duplo da roda na moldura do jogador = /reload: %s",
    msg_delay = "atraso: %s s",
    usage_delay = "uso: /mmd delay 1.55",
    msg_cols = "ícones por linha: %d",
    usage_cols = "uso: /mmd cols 4",
    list_none = "nenhum botão capturado.",
    list_count = "%d botão(ões) capturado(s):",
    tag_free_locked = "(livre, bloqueado)",
    tag_free = "(livre na tela)",
    tag_hidden = "(oculto pelo seu addon)",
    no_name = "(sem nome)",
    dbg_title = "diagnóstico de arrastar e soltar dos botões capturados:",
    dbg_line = "  %s | %s | arrastar=%s | móvel=%s | bloqueio=%s",
    dbg_free = "livre", dbg_menu = "menu", dbg_ok = "ok", dbg_over = "sobrescrito", dbg_yes = "sim", dbg_no = "não",
    ignore_msg = "%s ficará no minimapa após /reload.",
    unignore_msg = "%s será capturado novamente após /reload.",
    reset_msg = "configurações redefinidas. Reposicione a zona vermelha e o menu, depois /mmd lock.",
    first1 = "primeira execução! Arraste a zona vermelha para o círculo de nível do seu personagem",
    first2 = "(roda = tamanho). O menu (véu vermelho) se move separadamente. Depois digite /mmd lock.",
    help_title = "comandos:",
    h_unlock1 = "  /mmd unlock  - modo de movimento: arraste a zona vermelha para o círculo de nível (roda = tamanho)",
    h_unlock2 = "                 e arraste o menu (véu vermelho) separadamente",
    h_lock = "  /mmd lock  - alterna bloqueado / desbloqueado (como o cadeado do menu) e salva as posições",
    h_toggle = "  /mmd toggle  - abre / fecha o menu",
    h_autoopen = "  /mmd autoopen (ou /mmd ao)  - abrir o menu ao passar o mouse: ativar / desativar (o clique continua funcionando)",
    h_portrait = "  /mmd portrait  - clique duplo da roda na moldura do jogador (retrato, nome, vida, mana) = /reload: ativar / desativar",
    h_delay = "  /mmd delay <segundos>  - atraso ao passar o mouse (ex.: 1.55)",
    h_cols = "  /mmd cols <2-12>  - ícones por linha (padrão 4)",
    h_list = "  /mmd list  - lista os botões capturados",
    h_debug = "  /mmd debug  - diagnóstico de arrastar e soltar para cada botão",
    h_reorder = "  (arraste um ícone para o menu para reordená-lo: prévia após 200 ms, a ordem é salva)",
    h_free1 = "  (arraste um ícone para fora do menu para liberá-lo; solte-o no menu aberto para devolvê-lo.",
    h_free2 = "   No modo lock, um ícone livre parado por 5 s é bloqueado: Shift + arrastar, /mmd unlock ou /mmd lock o libera)",
    h_ignore = "  /mmd ignore <nome>  /  unignore <nome>  - excluir um botão (após /reload)",
    h_reset = "  /mmd reset  - restaura tudo ao padrão",
    h_rl = "  /rl  - recarrega a interface (atalho de /reload)",
}

LOCALES.ruRU = {
    move_me = "Перемести меня!",
    empty = "Кнопки у миникарты не найдены",
    slider_tip = "Задержка наведения перед открытием меню\n(в секундах, 2 знака после запятой)",
    edit_tip = "Задержка наведения перед открытием меню\n(в секундах, например 1.55)",
    hint = "Перетащи меня · колесо = размер · /mmd lock",
    lock_on_tip = "Разблокировано: нажмите, чтобы заблокировать и сохранить",
    lock_off_tip = "Заблокировано: нажмите, чтобы разблокировать и переместить",
    icon_locked = "значок заблокирован: Shift + перетаскивание, чтобы переместить (или /mmd unlock, /mmd lock).",
    msg_locked = "позиции сохранены (заблокировано).",
    msg_unlocked = "режим перемещения включён (разблокировано). /mmd lock или замок для подтверждения.",
    msg_unlock_cmd = "режим перемещения включён. /mmd lock для подтверждения.",
    msg_autoopen = "автоматическое открытие при наведении: %s",
    msg_portrait = "двойной щелчок колесом по рамке игрока = /reload: %s",
    msg_delay = "задержка наведения: %s с",
    usage_delay = "использование: /mmd delay 1.55",
    msg_cols = "значков в строке: %d",
    usage_cols = "использование: /mmd cols 4",
    list_none = "кнопки не захвачены.",
    list_count = "захвачено кнопок: %d",
    tag_free_locked = "(свободна, заблокирована)",
    tag_free = "(свободна на экране)",
    tag_hidden = "(скрыта своим аддоном)",
    no_name = "(без имени)",
    dbg_title = "диагностика перетаскивания захваченных кнопок:",
    dbg_line = "  %s | %s | перетаскивание=%s | перемещаема=%s | блокировка=%s",
    dbg_free = "свободна", dbg_menu = "меню", dbg_ok = "ок", dbg_over = "перезаписано", dbg_yes = "да", dbg_no = "нет",
    ignore_msg = "%s останется у миникарты после /reload.",
    unignore_msg = "%s снова будет захвачена после /reload.",
    reset_msg = "настройки сброшены. Снова разместите красную зону и меню, затем /mmd lock.",
    first1 = "первый запуск! Перетащите красную зону на круг уровня вашего персонажа",
    first2 = "(колесо = размер). Меню (красная вуаль) перемещается отдельно. Затем введите /mmd lock.",
    help_title = "команды:",
    h_unlock1 = "  /mmd unlock  - режим перемещения: перетащите красную зону на круг уровня (колесо = размер)",
    h_unlock2 = "                 и отдельно перетащите меню (красная вуаль)",
    h_lock = "  /mmd lock  - переключает заблокировано / разблокировано (как замок в меню) и сохраняет позиции",
    h_toggle = "  /mmd toggle  - открывает / закрывает меню",
    h_autoopen = "  /mmd autoopen (или /mmd ao)  - открытие меню при наведении: вкл / выкл (щелчок работает всегда)",
    h_portrait = "  /mmd portrait  - двойной щелчок колесом по рамке игрока (портрет, имя, здоровье, мана) = /reload: вкл / выкл",
    h_delay = "  /mmd delay <секунды>  - задержка наведения (например 1.55)",
    h_cols = "  /mmd cols <2-12>  - значков в строке (по умолчанию 4)",
    h_list = "  /mmd list  - список захваченных кнопок",
    h_debug = "  /mmd debug  - диагностика перетаскивания для каждой кнопки",
    h_reorder = "  (перетащите значок на меню, чтобы изменить порядок: предпросмотр через 200 мс, порядок сохраняется)",
    h_free1 = "  (перетащите значок за пределы меню, чтобы освободить его; бросьте на открытое меню, чтобы вернуть.",
    h_free2 = "   В режиме lock неподвижный свободный значок блокируется через 5 с: Shift + перетаскивание, /mmd unlock или /mmd lock снимает блокировку)",
    h_ignore = "  /mmd ignore <имя>  /  unignore <имя>  - исключить кнопку (после /reload)",
    h_reset = "  /mmd reset  - сбросить всё по умолчанию",
    h_rl = "  /rl  - перезагружает интерфейс (сокращение /reload)",
}

LOCALES.koKR = {
    move_me = "나를 움직여 주세요!",
    empty = "미니맵 버튼이 감지되지 않았습니다",
    slider_tip = "메뉴가 열리기 전 마우스 오버 지연 시간\n(초 단위, 소수점 2자리)",
    edit_tip = "메뉴가 열리기 전 마우스 오버 지연 시간\n(초 단위, 예: 1.55)",
    hint = "드래그하세요 · 휠 = 크기 · /mmd lock",
    lock_on_tip = "잠금 해제됨: 클릭하여 잠그고 저장",
    lock_off_tip = "잠김: 클릭하여 잠금 해제 후 이동",
    icon_locked = "아이콘이 잠겼습니다: Shift + 드래그로 이동 (또는 /mmd unlock, /mmd lock).",
    msg_locked = "위치가 저장되었습니다 (잠김).",
    msg_unlocked = "이동 모드가 켜졌습니다 (잠금 해제). 확인하려면 /mmd lock 또는 자물쇠를 누르세요.",
    msg_unlock_cmd = "이동 모드가 켜졌습니다. 확인하려면 /mmd lock.",
    msg_autoopen = "마우스 오버 시 자동 열기: %s",
    msg_portrait = "플레이어 프레임 휠 더블클릭 = /reload: %s",
    msg_delay = "마우스 오버 지연: %s초",
    usage_delay = "사용법: /mmd delay 1.55",
    msg_cols = "줄당 아이콘 수: %d",
    usage_cols = "사용법: /mmd cols 4",
    list_none = "수집된 버튼이 없습니다.",
    list_count = "수집된 버튼 %d개:",
    tag_free_locked = "(분리됨, 잠김)",
    tag_free = "(화면에 분리됨)",
    tag_hidden = "(해당 애드온이 숨김)",
    no_name = "(이름 없음)",
    dbg_title = "수집된 버튼의 드래그 앤 드롭 진단:",
    dbg_line = "  %s | %s | 드래그=%s | 이동 가능=%s | 잠금=%s",
    dbg_free = "분리됨", dbg_menu = "메뉴", dbg_ok = "정상", dbg_over = "덮어씀", dbg_yes = "예", dbg_no = "아니오",
    ignore_msg = "%s은(는) /reload 후에도 미니맵에 남습니다.",
    unignore_msg = "%s은(는) /reload 후 다시 수집됩니다.",
    reset_msg = "설정이 초기화되었습니다. 빨간 영역과 메뉴를 다시 배치한 뒤 /mmd lock.",
    first1 = "처음 실행입니다! 빨간 영역을 캐릭터의 레벨 원 위로 드래그하세요",
    first2 = "(휠 = 크기). 메뉴(빨간 막)는 따로 이동합니다. 그런 다음 /mmd lock 을 입력하세요.",
    help_title = "명령어:",
    h_unlock1 = "  /mmd unlock  - 이동 모드: 빨간 영역을 레벨 원 위로 드래그 (휠 = 크기)",
    h_unlock2 = "                 메뉴(빨간 막)는 따로 드래그",
    h_lock = "  /mmd lock  - 잠금 / 잠금 해제 전환 (메뉴의 자물쇠와 동일), 위치 저장",
    h_toggle = "  /mmd toggle  - 메뉴 열기 / 닫기",
    h_autoopen = "  /mmd autoopen (또는 /mmd ao)  - 마우스 오버 시 메뉴 열기: 켜기 / 끄기 (클릭은 계속 작동)",
    h_portrait = "  /mmd portrait  - 플레이어 프레임(초상화, 이름, 체력, 마나) 휠 더블클릭 = /reload: 켜기 / 끄기",
    h_delay = "  /mmd delay <초>  - 마우스 오버 지연 (예: 1.55)",
    h_cols = "  /mmd cols <2-12>  - 줄당 아이콘 수 (기본 4)",
    h_list = "  /mmd list  - 수집된 버튼 목록",
    h_debug = "  /mmd debug  - 각 버튼의 드래그 앤 드롭 진단",
    h_reorder = "  (아이콘을 메뉴 위로 드래그해 순서 변경: 200ms 후 미리보기, 순서 저장됨)",
    h_free1 = "  (아이콘을 메뉴 밖으로 드래그하면 분리됩니다. 열린 메뉴에 놓으면 다시 들어갑니다.",
    h_free2 = "   lock 모드에서 5초간 움직이지 않은 분리 아이콘은 잠깁니다: Shift + 드래그, /mmd unlock 또는 /mmd lock 으로 해제)",
    h_ignore = "  /mmd ignore <이름>  /  unignore <이름>  - 버튼 제외 (/reload 후)",
    h_reset = "  /mmd reset  - 모두 기본값으로 복원",
    h_rl = "  /rl  - 인터페이스 다시 불러오기 (/reload 단축 명령)",
}

LOCALES.zhCN = {
    move_me = "拖动我！",
    empty = "未检测到小地图按钮",
    slider_tip = "鼠标悬停多久后打开菜单\n（单位：秒，保留 2 位小数）",
    edit_tip = "鼠标悬停多久后打开菜单\n（单位：秒，例如 1.55）",
    hint = "拖动我 · 滚轮 = 大小 · /mmd lock",
    lock_on_tip = "已解锁：点击以锁定并保存",
    lock_off_tip = "已锁定：点击以解锁并移动",
    icon_locked = "图标已锁定：按住 Shift 拖动可移动（或 /mmd unlock、/mmd lock）。",
    msg_locked = "位置已保存（已锁定）。",
    msg_unlocked = "移动模式已开启（已解锁）。使用 /mmd lock 或点击锁来确认。",
    msg_unlock_cmd = "移动模式已开启。使用 /mmd lock 确认。",
    msg_autoopen = "悬停自动打开：%s",
    msg_portrait = "在玩家头像框上双击滚轮 = /reload：%s",
    msg_delay = "悬停延迟：%s 秒",
    usage_delay = "用法：/mmd delay 1.55",
    msg_cols = "每行图标数：%d",
    usage_cols = "用法：/mmd cols 4",
    list_none = "未捕获任何按钮。",
    list_count = "已捕获 %d 个按钮：",
    tag_free_locked = "（已脱离，已锁定）",
    tag_free = "（已脱离，位于屏幕上）",
    tag_hidden = "（被其插件隐藏）",
    no_name = "（无名称）",
    dbg_title = "已捕获按钮的拖放诊断：",
    dbg_line = "  %s | %s | 拖动=%s | 可移动=%s | 锁定=%s",
    dbg_free = "脱离", dbg_menu = "菜单", dbg_ok = "正常", dbg_over = "被覆盖", dbg_yes = "是", dbg_no = "否",
    ignore_msg = "%s 在 /reload 后将保留在小地图上。",
    unignore_msg = "%s 在 /reload 后将重新被捕获。",
    reset_msg = "设置已重置。请重新放置红色区域和菜单，然后输入 /mmd lock。",
    first1 = "首次启动！请将红色区域拖到角色的等级圆圈上",
    first2 = "（滚轮 = 大小）。菜单（红色遮罩）需单独移动。然后输入 /mmd lock。",
    help_title = "命令：",
    h_unlock1 = "  /mmd unlock  - 移动模式：将红色区域拖到等级圆圈上（滚轮 = 大小）",
    h_unlock2 = "                 并单独拖动菜单（红色遮罩）",
    h_lock = "  /mmd lock  - 在锁定 / 解锁之间切换（与菜单中的锁相同）并保存位置",
    h_toggle = "  /mmd toggle  - 打开 / 关闭菜单",
    h_autoopen = "  /mmd autoopen（或 /mmd ao）  - 悬停时打开菜单：开 / 关（点击仍然有效）",
    h_portrait = "  /mmd portrait  - 在玩家头像框（头像、名字、生命、法力）上双击滚轮 = /reload：开 / 关",
    h_delay = "  /mmd delay <秒>  - 悬停延迟（例如 1.55）",
    h_cols = "  /mmd cols <2-12>  - 每行图标数（默认 4）",
    h_list = "  /mmd list  - 列出已捕获的按钮",
    h_debug = "  /mmd debug  - 每个按钮的拖放诊断",
    h_reorder = "  （将图标拖到菜单上可重新排序：200 毫秒后预览，顺序会被保存）",
    h_free1 = "  （将图标拖出菜单可使其脱离；放到已打开的菜单上可放回。",
    h_free2 = "   在锁定模式下，脱离的图标静止 5 秒后会被锁定：Shift + 拖动、/mmd unlock 或 /mmd lock 可解除）",
    h_ignore = "  /mmd ignore <名称>  /  unignore <名称>  - 排除某个按钮（/reload 后生效）",
    h_reset = "  /mmd reset  - 全部恢复默认",
    h_rl = "  /rl  - 重新加载界面（/reload 的快捷方式）",
}

LOCALES.zhTW = {
    move_me = "拖曳我！",
    empty = "未偵測到小地圖按鈕",
    slider_tip = "滑鼠懸停多久後開啟選單\n（單位：秒，保留 2 位小數）",
    edit_tip = "滑鼠懸停多久後開啟選單\n（單位：秒，例如 1.55）",
    hint = "拖曳我 · 滾輪 = 大小 · /mmd lock",
    lock_on_tip = "已解鎖：點擊以鎖定並儲存",
    lock_off_tip = "已鎖定：點擊以解鎖並移動",
    icon_locked = "圖示已鎖定：按住 Shift 拖曳可移動（或 /mmd unlock、/mmd lock）。",
    msg_locked = "位置已儲存（已鎖定）。",
    msg_unlocked = "移動模式已開啟（已解鎖）。使用 /mmd lock 或點擊鎖來確認。",
    msg_unlock_cmd = "移動模式已開啟。使用 /mmd lock 確認。",
    msg_autoopen = "懸停自動開啟：%s",
    msg_portrait = "在玩家頭像框上雙擊滾輪 = /reload：%s",
    msg_delay = "懸停延遲：%s 秒",
    usage_delay = "用法：/mmd delay 1.55",
    msg_cols = "每行圖示數：%d",
    usage_cols = "用法：/mmd cols 4",
    list_none = "未擷取任何按鈕。",
    list_count = "已擷取 %d 個按鈕：",
    tag_free_locked = "（已脫離，已鎖定）",
    tag_free = "（已脫離，位於畫面上）",
    tag_hidden = "（被其插件隱藏）",
    no_name = "（無名稱）",
    dbg_title = "已擷取按鈕的拖放診斷：",
    dbg_line = "  %s | %s | 拖曳=%s | 可移動=%s | 鎖定=%s",
    dbg_free = "脫離", dbg_menu = "選單", dbg_ok = "正常", dbg_over = "被覆蓋", dbg_yes = "是", dbg_no = "否",
    ignore_msg = "%s 在 /reload 後將保留在小地圖上。",
    unignore_msg = "%s 在 /reload 後將重新被擷取。",
    reset_msg = "設定已重置。請重新放置紅色區域和選單，然後輸入 /mmd lock。",
    first1 = "首次啟動！請將紅色區域拖到角色的等級圓圈上",
    first2 = "（滾輪 = 大小）。選單（紅色遮罩）需單獨移動。然後輸入 /mmd lock。",
    help_title = "指令：",
    h_unlock1 = "  /mmd unlock  - 移動模式：將紅色區域拖到等級圓圈上（滾輪 = 大小）",
    h_unlock2 = "                 並單獨拖曳選單（紅色遮罩）",
    h_lock = "  /mmd lock  - 在鎖定 / 解鎖之間切換（與選單中的鎖相同）並儲存位置",
    h_toggle = "  /mmd toggle  - 開啟 / 關閉選單",
    h_autoopen = "  /mmd autoopen（或 /mmd ao）  - 懸停時開啟選單：開 / 關（點擊仍然有效）",
    h_portrait = "  /mmd portrait  - 在玩家頭像框（頭像、名字、生命、法力）上雙擊滾輪 = /reload：開 / 關",
    h_delay = "  /mmd delay <秒>  - 懸停延遲（例如 1.55）",
    h_cols = "  /mmd cols <2-12>  - 每行圖示數（預設 4）",
    h_list = "  /mmd list  - 列出已擷取的按鈕",
    h_debug = "  /mmd debug  - 每個按鈕的拖放診斷",
    h_reorder = "  （將圖示拖到選單上可重新排序：200 毫秒後預覽，順序會被儲存）",
    h_free1 = "  （將圖示拖出選單可使其脫離；放到已開啟的選單上可放回。",
    h_free2 = "   在鎖定模式下，脫離的圖示靜止 5 秒後會被鎖定：Shift + 拖曳、/mmd unlock 或 /mmd lock 可解除）",
    h_ignore = "  /mmd ignore <名稱>  /  unignore <名稱>  - 排除某個按鈕（/reload 後生效）",
    h_reset = "  /mmd reset  - 全部恢復預設",
    h_rl = "  /rl  - 重新載入介面（/reload 的快捷方式）",
}

LOCALES.enGB = LOCALES.enUS
LOCALES.esMX = LOCALES.esES
LOCALES.ptPT = LOCALES.ptBR

local ACTIVE_LOCALE = LOCALES[GetLocale()] or LOCALES.enUS

-- L("clé") : texte dans la langue du client ; L("clé", a, b) applique string.format
local function L(key, ...)
    local text = ACTIVE_LOCALE[key] or LOCALES.enUS[key] or key
    if select("#", ...) > 0 then return string.format(text, ...) end
    return text
end

-- Frames Blizzard qu'on ne touche jamais
local BLACKLIST = {
    MinimapBackdrop = true, MinimapCompassTexture = true, MinimapNorthTag = true,
    MinimapZoneTextButton = true, MinimapZoneText = true, MinimapZoomIn = true,
    MinimapZoomOut = true, MinimapCluster = true, MiniMapPing = true, MinimapPing = true,
    MiniMapTracking = true, MiniMapTrackingButton = true, MiniMapTrackingFrame = true,
    MiniMapMailFrame = true, MiniMapMailIcon = true, MiniMapBattlefieldFrame = true,
    MiniMapLFGFrame = true, MiniMapWorldMapButton = true, MiniMapInstanceDifficulty = true,
    GuildInstanceDifficulty = true, MiniMapChallengeMode = true, MiniMapVoiceChatFrame = true,
    MiniMapRecordingButton = true, GameTimeFrame = true, TimeManagerClockButton = true,
    QueueStatusMinimapButton = true, QueueStatusButton = true,
    GarrisonLandingPageMinimapButton = true, ExpansionLandingPageMinimapButton = true,
    AddonCompartmentFrame = true, HelpOpenTicketButton = true, HelpOpenWebTicketButton = true,
}

-- Marqueurs de carte (pins) à ne pas confondre avec des boutons
local BLACKLIST_PATTERNS = { "^HandyNotes", "^Questie", "^GatherMate", "^HBD", "^TomTom", "Pin%d*$" }

---------------------------------------------------------------------
-- Utilitaires
---------------------------------------------------------------------
local PREFIX = "|cff33ff99MinimapDrawer|r : "
local function Print(msg) print(PREFIX .. msg) end

local function Round2(v) return math.floor(v * 100 + 0.5) / 100 end
local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- 1.50 -> "1.5", 1.00 -> "1", 1.55 -> "1.55"
local function FormatDelay(v)
    local s = string.format("%.2f", v)
    s = s:gsub("0+$", ""):gsub("%.$", "")
    return s
end

local function Noop() end

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
local FLAT_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

---------------------------------------------------------------------
-- Habillage : même cadre que les tooltips Blizzard + bouton fermer de la fenêtre personnage
---------------------------------------------------------------------
-- Backdrop de repli (textures "Tooltip" standard du client)
local TOOLTIP_BACKDROP_FALLBACK = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
}

-- Backdrop du slider : celui de l'OptionsSliderTemplate Blizzard
local SLIDER_BACKDROP = {
    bgFile   = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 },
}

-- Reprend le style exact de la "Tooltip" du client : même backdrop que GameTooltip,
-- mêmes couleurs par défaut (fond bleu nuit, bordure grise).
local function ApplyTooltipSkin(frame)
    local info
    local gt = _G.GameTooltip
    if gt and gt.GetBackdrop then
        local ok, b = pcall(gt.GetBackdrop, gt)
        if ok and type(b) == "table" and (b.edgeFile or b.bgFile) then info = b end
    end
    info = info or TOOLTIP_BACKDROP_FALLBACK

    local function ColorOf(color, r, g, b, a)
        if type(color) == "table" and color.r then
            return color.r, color.g, color.b, color.a or 1
        end
        return r, g, b, a
    end
    local br, bg, bb, ba = ColorOf(_G.TOOLTIP_DEFAULT_BACKGROUND_COLOR, 0.09, 0.09, 0.19, 1)
    local er, eg, eb, ea = ColorOf(_G.TOOLTIP_DEFAULT_COLOR, 1, 1, 1, 1)

    frame:SetBackdrop(info)
    frame:SetBackdropColor(br, bg, bb, ba)
    frame:SetBackdropBorderColor(er, eg, eb, ea)
end

-- Bouton fermer identique à celui de la fenêtre personnage (UIPanelCloseButton)
local function CreateCloseButton(parent)
    local ok, btn = pcall(CreateFrame, "Button", nil, parent, "UIPanelCloseButton")
    if ok and btn then return btn end

    -- Repli : carré rouge-brun, X doré, bordure dorée
    btn = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
    btn:SetSize(22, 22)
    btn:SetBackdrop(FLAT_BACKDROP)
    btn:SetBackdropColor(0.40, 0.11, 0.05, 1)
    btn:SetBackdropBorderColor(0.85, 0.66, 0.20, 1)
    local x = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    x:SetPoint("CENTER", 0, 0)
    x:SetText("X")
    btn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 0.92, 0.45, 1) end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.85, 0.66, 0.20, 1) end)
    return btn
end

-- Boîte de saisie identique à celles du client (InputBoxTemplate : capuchons biseautés,
-- bordure beige, fond noir), comme la boîte « 100 % » des sliders Blizzard.
local function CreateInputBox(name, parent)
    local ok, box = pcall(CreateFrame, "EditBox", name, parent, "InputBoxTemplate")
    if ok and box then return box end

    -- Repli : cadre biseauté maison (bordure beige, fond noir)
    box = CreateFrame("EditBox", name, parent, BACKDROP_TEMPLATE)
    box:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = TOOLTIP_BACKDROP_FALLBACK.edgeFile,
        edgeSize = 10,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    box:SetBackdropColor(0, 0, 0, 1)
    box:SetBackdropBorderColor(0.80, 0.74, 0.62, 1)
    return box
end

-- Méthodes "brutes" (les boutons capturés ont SetPoint / ClearAllPoints neutralisés)
local FrameProbe = CreateFrame("Frame") -- (Clara Combo Points: its methods, as the metatable's)
local rawSetPoint, rawClearAllPoints = FrameProbe.SetPoint, FrameProbe.ClearAllPoints

---------------------------------------------------------------------
-- État
---------------------------------------------------------------------
local DB
local menu, hotspot, slider, editBox, emptyText, ring, hint, overlay
local unlocked = false
local hoverTimer
local lastSig
local buttons, captured, info = {}, {}, {}
local blizzChild = {}
local Callbacks = {}
local activeDrag -- icône en cours de glisser : aucune remise en page tant qu'elle n'est pas lâchée
local Layout -- déclaré ici, défini plus bas (utilisé par le glisser-déposer)
local ComputeSlot, MoveInOrder -- idem : emplacement visé sous le curseur / mémorisation de l'ordre
local slotMarker              -- carré translucide qui marque l'emplacement libre pendant l'aperçu
local orderList               -- ordre personnalisé des icônes du menu (liste de clés)
local previewSlot             -- emplacement (1..n+1) actuellement réservé dans le menu pendant un glisser
local pendingSlot, pendingSince -- emplacement visé par le curseur et depuis quand (délai de 200 ms)
local PREVIEW_DELAY = 0.2

local function InitDB()
    ClaraMinimapDrawerDB = ClaraMinimapDrawerDB or {}
    DB = ClaraMinimapDrawerDB
    for k, v in pairs(DEFAULTS) do
        if DB[k] == nil then DB[k] = v end
    end
    DB.ignore  = DB.ignore or {}
    DB.free    = DB.free or {}   -- icônes détachées du menu : [nom] = { x, y }
    DB.order   = DB.order or {}  -- ordre personnalisé des icônes du menu (clés, voir SortKey)
    DB.delay   = Clamp(Round2(tonumber(DB.delay) or DEFAULTS.delay), 0, MAX_DELAY)
    DB.columns = Clamp(math.floor(tonumber(DB.columns) or DEFAULTS.columns), 2, 12)
    DB.autoopen = (DB.autoopen ~= false)
    DB.portraitReload = (DB.portraitReload ~= false)
end

---------------------------------------------------------------------
-- Détection / capture des boutons de la minimap
---------------------------------------------------------------------
local function HasClickHandler(f)
    for _, script in ipairs({ "OnClick", "OnMouseUp", "OnMouseDown" }) do
        if f:HasScript(script) and f:GetScript(script) then return true end
    end
    return false
end

local function BuildBlizzIndex(parent)
    if not parent then return end
    for _, v in pairs(parent) do
        if type(v) == "table" and type(v.GetObjectType) == "function" then
            blizzChild[v] = true
        end
    end
end

local function IsCandidate(f)
    if captured[f] or blizzChild[f] then return false end
    if f.IsForbidden and f:IsForbidden() then return false end
    if f.IsProtected and f:IsProtected() then return false end

    local name = f:GetName()
    if name then
        if BLACKLIST[name] or DB.ignore[name] then return false end
        for _, pattern in ipairs(BLACKLIST_PATTERNS) do
            if name:find(pattern) then return false end
        end
    end

    local otype = f:GetObjectType()
    if otype ~= "Button" and otype ~= "Frame" and otype ~= "CheckButton" then return false end
    if not f:IsMouseEnabled() then return false end

    local w, h = f:GetSize()
    local m = math.max(w or 0, h or 0)
    if m < 14 or m > 64 then return false end

    return HasClickHandler(f)
end

local function PlaceButton(btn, x, y)
    local s = info[btn].scale
    rawClearAllPoints(btn)
    rawSetPoint(btn, "CENTER", menu, "BOTTOMRIGHT", x / s, y / s)
end

---------------------------------------------------------------------
-- Glisser-déposer : détacher une icône du menu / la rattacher
---------------------------------------------------------------------
local DRAG_STRATA = "FULLSCREEN_DIALOG"  -- au-dessus de tout pendant le glisser
-- icône libre posée sur l'écran : la strate de la minicarte (au-dessus d'elle par son niveau), sous les fenêtres (sacs,
-- personnage, quêtes...) ; en HIGH, l'icône d'AtlasLoot passait par-dessus les sacs
local FREE_STRATA = "LOW"

local function CursorOverMenu()
    if not menu:IsShown() then return false end
    local cx, cy = GetCursorPosition()
    local s = menu:GetEffectiveScale()
    if not s or s == 0 then return false end
    cx, cy = cx / s, cy / s
    local l, r, b, t = menu:GetLeft(), menu:GetRight(), menu:GetBottom(), menu:GetTop()
    if not (l and r and b and t) then return false end
    return cx >= l and cx <= r and cy >= b and cy <= t
end

local function SaveFree(btn)
    local name = btn:GetName()
    if not name then return end -- sans nom : position non mémorisable (reste libre jusqu'au /reload)
    local x, y = btn:GetCenter()
    if x and y then DB.free[name] = { x = Round2(x), y = Round2(y) } end
end

-- Détache l'icône du menu : elle devient indépendante et se pose en (x, y) sur l'écran
local function SetFree(btn, x, y)
    if not x or not y then x, y = btn:GetCenter() end
    if not x or not y then x, y = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2 end
    info[btn].free = true
    info[btn].locked = false
    info[btn].idleSince = GetTime()
    btn:SetParent(UIParent)
    btn:SetFrameStrata(FREE_STRATA)
    btn:SetFrameLevel(10)
    rawClearAllPoints(btn)
    rawSetPoint(btn, "CENTER", UIParent, "BOTTOMLEFT", x, y)
    lastSig = nil
end

-- Rattache l'icône au menu (la mise en page la replace ensuite)
local function SetAttached(btn)
    info[btn].free = false
    local name = btn:GetName()
    if name then DB.free[name] = nil end
    btn:SetParent(menu)
    btn:SetFrameStrata("DIALOG")
    btn:SetFrameLevel(menu:GetFrameLevel() + 5)
    rawClearAllPoints(btn)
    rawSetPoint(btn, "CENTER", menu, "CENTER", 0, 0)
    lastSig = nil
end

-- Verrouillage automatique des icônes libres : en mode /mmd lock, une icône posée hors du
-- menu qui ne bouge plus pendant IDLE_LOCK_DELAY secondes est verrouillée, jusqu'à ce qu'on
-- tape /mmd unlock ou /mmd lock.
local IDLE_LOCK_DELAY = 5
local lockHintAt = -100

local function ReleaseFreeLocks()
    local now = GetTime()
    for _, btn in ipairs(buttons) do
        local i = info[btn]
        if i.free then i.locked = false; i.idleSince = now end
    end
end

local function BeginIconDrag(btn, manual)
    local i = info[btn]
    if not i or i.dragging then return end
    if i.free and i.locked then
        if IsShiftKeyDown and IsShiftKeyDown() then
            -- Maj + clic gauche maintenu : contourne le verrou ; le délai de grâce de 5 s
            -- repart à partir de maintenant puis du dépôt
            i.locked = false
            i.idleSince = GetTime()
        else
            local now = GetTime()
            if now - lockHintAt > 3 then
                lockHintAt = now
                Print(L("icon_locked"))
            end
            return
        end
    end
    if GameTooltip then GameTooltip:Hide() end
    if not i.free then
        local x, y = btn:GetCenter()
        SetFree(btn, x, y)
        -- pas de Layout() ici : les autres icônes ne bougent qu'une fois l'icône lâchée
    end
    btn:SetFrameStrata(DRAG_STRATA)
    if btn.SetMovable then btn:SetMovable(true) end -- un addon a pu le désactiver
    activeDrag = btn
    previewSlot, pendingSlot, pendingSince = nil, nil, 0
    i.dragging = true
    i.manual = manual and true or false
    btn:StartMoving()
end

local function EndIconDrag(btn)
    local i = info[btn]
    if not i or not i.dragging then return end
    i.dragging = false
    i.manual = false
    i.blockUntil = GetTime() + 0.3 -- le relâchement du clic ne doit pas être pris pour un clic sur l'addon
    if activeDrag == btn then activeDrag = nil end
    btn:StopMovingOrSizing()
    if CursorOverMenu() then
        -- l'icône prend la place visée par le curseur, et l'ordre est mémorisé
        MoveInOrder(btn, ComputeSlot())
        SetAttached(btn)
    else
        local x, y = btn:GetCenter()
        SetFree(btn, x, y)
        SaveFree(btn)
    end
    previewSlot, pendingSlot = nil, nil
    Layout() -- c'est maintenant, une fois l'icône lâchée, que les autres se réorganisent
end

local function OnIconDragStart(btn) BeginIconDrag(btn, false) end
local function OnIconDragStop(btn) EndIconDrag(btn) end

-- Les boutons LibDBIcon (Questie, DBM, Leatrix, AtlasLoot...) réassignent leurs scripts de
-- glisser (Lock / Unlock / Refresh) : on remet les nôtres dès qu'ils y touchent, et par
-- sécurité à chaque scan.
-- Un glisser-déposer ne doit pas ouvrir l'addon : les scripts OnClick / OnMouseUp du bouton sont
-- enveloppés et ignorés pendant le glisser et 0,3 s après le dépôt. Un simple clic (sans glisser)
-- passe normalement.
local CLICK_SCRIPTS = { "OnClick", "OnMouseUp" }

local function ClickBlocked(btn)
    local i = info[btn]
    return i and (i.dragging or (i.blockUntil and GetTime() < i.blockUntil))
end

local function WrapClickScripts(btn)
    local i = info[btn]
    i.wrap = i.wrap or {}
    for _, name in ipairs(CLICK_SCRIPTS) do
        if btn:HasScript(name) then
            local cur = btn:GetScript(name)
            local w = i.wrap[name]
            if cur and not (w and cur == w.wrapper) then
                local orig = cur
                local function wrapper(self, ...)
                    if ClickBlocked(btn) then return end
                    return orig(self, ...)
                end
                i.wrap[name] = { orig = orig, wrapper = wrapper }
                btn:SetScript(name, wrapper)
            end
        end
    end
end

local enforcing = false
local function EnforceDrag(btn)
    if enforcing then return end
    local i = info[btn]
    if not i or i.dragging then return end
    enforcing = true
    pcall(function()
        if btn.SetMovable then btn:SetMovable(true) end
        if btn.RegisterForDrag then btn:RegisterForDrag("LeftButton") end
        if btn:GetScript("OnDragStart") ~= OnIconDragStart then btn:SetScript("OnDragStart", OnIconDragStart) end
        if btn:GetScript("OnDragStop") ~= OnIconDragStop then btn:SetScript("OnDragStop", OnIconDragStop) end
        WrapClickScripts(btn)
    end)
    enforcing = false
end

local function HookDragGuards(btn)
    if not hooksecurefunc then return end
    local function guard(self) EnforceDrag(self) end
    pcall(hooksecurefunc, btn, "SetScript", function(self, name)
        if name == "OnDragStart" or name == "OnDragStop" or name == "OnClick" or name == "OnMouseUp" then
            EnforceDrag(self)
        end
    end)
    pcall(hooksecurefunc, btn, "RegisterForDrag", guard)
    pcall(hooksecurefunc, btn, "SetMovable", guard)
end

-- Surveillant (une frame pour tout l'addon) :
--  1) filet de sécurité du glisser : si le moteur n'a pas déclenché OnDragStart (script écrasé
--     par un addon), on démarre le déplacement nous-mêmes dès que la souris bouge de 8 px ;
--  2) verrouillage automatique des icônes libres immobiles.
local watcher = CreateFrame("Frame", "MinimapDrawerWatcher", UIParent)
local lockAcc, pressBtn, pressX, pressY, pressSeen = 0, nil, 0, 0, false

local function CapturedUnderMouse()
    local f
    if GetMouseFocus then
        f = GetMouseFocus()
    elseif GetMouseFoci then
        local t = GetMouseFoci()
        f = t and t[1]
    end
    local depth = 0
    while f and depth < 4 do
        -- (a frame the game forbids to addons, such as its secure trade or mail confirmation: never touched)
        if f.IsForbidden and f:IsForbidden() then return nil end
        if captured[f] then return f end
        f = f.GetParent and f:GetParent() or nil
        depth = depth + 1
    end
    return nil
end

watcher:SetScript("OnUpdate", function(_, elapsed)
    if IsMouseButtonDown and IsMouseButtonDown("LeftButton") then
        if not pressSeen then
            pressSeen = true
            pressBtn = CapturedUnderMouse()
            if pressBtn then pressX, pressY = GetCursorPosition() end
        elseif pressBtn then
            local i = info[pressBtn]
            if i and not i.dragging then
                local x, y = GetCursorPosition()
                local dx, dy = x - pressX, y - pressY
                if dx * dx + dy * dy > 64 then BeginIconDrag(pressBtn, true) end
            end
        end
    else
        if pressBtn then
            local i = info[pressBtn]
            if i and i.dragging and i.manual then EndIconDrag(pressBtn) end
        end
        if activeDrag then EndIconDrag(activeDrag) end -- relâchement manqué : on ne reste pas bloqué
        pressBtn, pressSeen = nil, false
    end

    -- Aperçu du glisser : si le curseur reste ~200 ms au-dessus d'un même emplacement du menu,
    -- les icônes se réarrangent pour laisser une place vide à cet endroit.
    if activeDrag then
        local target = CursorOverMenu() and ComputeSlot() or nil
        local now = GetTime()
        if target ~= pendingSlot then pendingSlot, pendingSince = target, now end
        if pendingSlot ~= previewSlot and now - pendingSince >= PREVIEW_DELAY then
            previewSlot = pendingSlot
            Layout()
        end
    end

    lockAcc = lockAcc + (elapsed or 0)
    if lockAcc >= 0.25 then
        lockAcc = 0
        if not unlocked then
            local now = GetTime()
            for _, btn in ipairs(buttons) do
                local i = info[btn]
                if i.free and not i.locked and not i.dragging and i.idleSince
                   and now - i.idleSince >= IDLE_LOCK_DELAY then
                    i.locked = true
                end
            end
        end
    end
end)

local function Capture(btn)
    if not btn or captured[btn] then return end
    local name = btn:GetName()
    if name and DB.ignore[name] then return end

    captured[btn] = true
    buttons[#buttons + 1] = btn

    local w, h = btn:GetSize()
    local m = math.max(w or 0, h or 0)
    local scale = 1
    if m > 0 then scale = Clamp(ICON_SIZE / m, 0.4, 1.6) end
    info[btn] = { scale = scale, order = #buttons, free = false }

    btn:SetParent(menu)
    -- LibDBIcon fige la strate / le niveau : on lève ça pour passer au-dessus du menu
    if btn.SetFixedFrameStrata then btn:SetFixedFrameStrata(false) end
    if btn.SetFixedFrameLevel then btn:SetFixedFrameLevel(false) end
    btn:SetFrameStrata("DIALOG")
    btn:SetFrameLevel(menu:GetFrameLevel() + 5)
    btn:SetScale(scale)
    btn:EnableMouse(true)
    -- Glisser-déposer : remplace le glisser « autour de la minimap » des addons
    if btn.SetClampedToScreen then btn:SetClampedToScreen(true) end
    EnforceDrag(btn)
    HookDragGuards(btn)

    rawClearAllPoints(btn)
    rawSetPoint(btn, "CENTER", menu, "CENTER", 0, 0)
    -- Les addons ne peuvent plus repositionner le bouton (LibDBIcon le fait régulièrement)
    btn.SetPoint = Noop
    btn.ClearAllPoints = Noop

    -- Icône qui avait été détachée du menu lors d'une session précédente : on la repose
    local saved = name and DB.free[name]
    if saved and saved.x and saved.y then SetFree(btn, saved.x, saved.y) end

    lastSig = nil -- force une remise en page
end

local function ScanLibDBIcon()
    local LibStub = _G.LibStub
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if not lib or not lib.objects then return end
    for _, btn in pairs(lib.objects) do
        pcall(Capture, btn)
    end
end

local function ScanParent(parent)
    if not parent then return end
    local kids = { parent:GetChildren() }
    for _, child in ipairs(kids) do
        local ok, candidate = pcall(IsCandidate, child)
        if ok and candidate then pcall(Capture, child) end
    end
end

local function Scan()
    if not DB then return end
    ScanLibDBIcon()
    ScanParent(_G.Minimap)
    ScanParent(_G.MinimapBackdrop)
    for _, btn in ipairs(buttons) do EnforceDrag(btn) end
end

local function HookLibDBIcon()
    local LibStub = _G.LibStub
    local lib = LibStub and LibStub("LibDBIcon-1.0", true)
    if lib and lib.RegisterCallback then
        lib.RegisterCallback(Callbacks, "LibDBIcon_IconCreated", function(_, button)
            pcall(Capture, button)
        end)
    end
end

---------------------------------------------------------------------
-- Mise en page : remplissage de droite à gauche, puis vers le haut
---------------------------------------------------------------------
local function SortKey(btn)
    local name = btn:GetName()
    if name then
        return name:gsub("^LibDBIcon10_", ""):lower()
    end
    return "~" .. string.format("%04d", info[btn].order)
end

local function Signature()
    local t = {}
    for i, btn in ipairs(buttons) do
        t[i] = info[btn].free and "f" or (btn:IsShown() and "1" or "0")
    end
    return #buttons .. ":" .. table.concat(t) .. ":" .. DB.columns
end

-- Ordre personnalisé : liste de clés mémorisée dans DB.order (les icônes sans nom ne sont
-- retenues que pour la session). Une icône jamais vue est ajoutée en fin de liste, par ordre
-- alphabétique ; tant que tu ne réarranges rien, l'ordre reste donc alphabétique comme avant.
local function GetOrder()
    if not orderList then
        orderList = {}
        for _, k in ipairs(DB.order or {}) do orderList[#orderList + 1] = k end
    end
    return orderList
end

local function SaveOrder()
    local t = {}
    for _, k in ipairs(GetOrder()) do
        if k:sub(1, 1) ~= "~" then t[#t + 1] = k end
    end
    DB.order = t
end

-- Icônes visibles et rattachées au menu, dans l'ordre d'affichage
local function SortedItems()
    local items = {}
    for _, btn in ipairs(buttons) do
        if btn:IsShown() and not info[btn].free then items[#items + 1] = btn end
    end

    local order = GetOrder()
    local idx = {}
    for i, k in ipairs(order) do
        if not idx[k] then idx[k] = i end
    end

    local fresh = {}
    for _, btn in ipairs(items) do
        if not idx[SortKey(btn)] then fresh[#fresh + 1] = btn end
    end
    if #fresh > 0 then
        table.sort(fresh, function(a, b)
            local ka, kb = SortKey(a), SortKey(b)
            if ka ~= kb then return ka < kb end
            return info[a].order < info[b].order
        end)
        for _, btn in ipairs(fresh) do
            local k = SortKey(btn)
            if not idx[k] then
                order[#order + 1] = k
                idx[k] = #order
            end
        end
        SaveOrder()
    end

    table.sort(items, function(a, b)
        local ia, ib = idx[SortKey(a)], idx[SortKey(b)]
        if ia ~= ib then return ia < ib end
        return info[a].order < info[b].order
    end)
    return items
end

-- Emplacement (1..n+1) visé par le curseur, d'après la grille du menu :
-- colonnes comptées depuis la droite, lignes depuis le bas, comme dans Layout().
function ComputeSlot()
    local total = #SortedItems() + 1 -- les icônes du menu + celle qu'on glisse
    local s = menu:GetEffectiveScale()
    local r, b = menu:GetRight(), menu:GetBottom()
    if not s or s == 0 or not r or not b then return total end
    local cx, cy = GetCursorPosition()
    cx, cy = cx / s, cy / s

    local cols = DB.columns
    local usedCols = math.min(total, cols)
    local rows = math.ceil(total / cols)
    local col = Clamp(math.floor((r - cx - PAD_X) / STEP), 0, usedCols - 1)
    local row = Clamp(math.floor((cy - b - PAD_BOTTOM) / STEP), 0, rows - 1)
    return Clamp(row * cols + col + 1, 1, total)
end

-- Place `btn` à l'emplacement `slot` de l'ordre mémorisé (btn doit être hors menu à cet instant)
function MoveInOrder(btn, slot)
    local items = SortedItems()
    local order = GetOrder()
    local key = SortKey(btn)
    for i = #order, 1, -1 do
        if order[i] == key then table.remove(order, i) end
    end

    local pos
    local after = items[slot]
    if after then
        local ak = SortKey(after)
        for i, k in ipairs(order) do
            if k == ak then pos = i; break end
        end
    elseif items[#items] then
        local lk = SortKey(items[#items])
        for i, k in ipairs(order) do
            if k == lk then pos = i + 1; break end
        end
    end
    table.insert(order, pos or (#order + 1), key)
    SaveOrder()
end

function Layout()
    local items = SortedItems()
    local n = #items

    -- Pendant un glisser : on réserve un emplacement vide à l'endroit visé
    local gap = previewSlot and Clamp(previewSlot, 1, n + 1) or nil
    local total = n + (gap and 1 or 0)

    local cols = DB.columns
    local usedCols = math.max(1, math.min(total, cols))
    local rows = math.max(1, math.ceil(total / cols))

    -- Coin bas-droit fixe : le cadre grandit vers la gauche (jusqu'à `cols`), puis vers le haut
    local width  = math.max(MIN_WIDTH, PAD_X * 2 + usedCols * STEP)
    local height = HEADER_H + PAD_BOTTOM + rows * STEP
    menu:SetSize(width, height)

    local function SlotXY(p)
        local col = (p - 1) % cols
        local row = math.floor((p - 1) / cols)
        return -(PAD_X + STEP / 2 + col * STEP), PAD_BOTTOM + STEP / 2 + row * STEP
    end

    local level = menu:GetFrameLevel() + 5
    for k, btn in ipairs(items) do
        local p = k
        if gap and k >= gap then p = k + 1 end
        local x, y = SlotXY(p)
        btn:SetFrameStrata("DIALOG")
        btn:SetFrameLevel(level)
        PlaceButton(btn, x, y)
    end

    if slotMarker then
        if gap then
            local x, y = SlotXY(gap)
            slotMarker:ClearAllPoints()
            slotMarker:SetPoint("CENTER", menu, "BOTTOMRIGHT", x, y)
            slotMarker:Show()
        else
            slotMarker:Hide()
        end
    end

    emptyText:SetShown(total == 0)
    lastSig = Signature()
end

---------------------------------------------------------------------
-- Menu contextuel
---------------------------------------------------------------------
menu = CreateFrame("Frame", "MinimapDrawerMenu", UIParent, BACKDROP_TEMPLATE)
menu:SetFrameStrata("DIALOG")
menu:SetClampedToScreen(true)
menu:SetMovable(true)
menu:EnableMouse(true)
menu:RegisterForDrag("LeftButton")
menu:SetSize(MIN_WIDTH, 120)
menu:SetFrameLevel(20)
ApplyTooltipSkin(menu)
menu:Hide()

-- Marqueur d'emplacement : disque grisé, un peu plus grand qu'une icône (36 px) mais
-- toujours plus petit que le pas de la grille (38 px) pour ne jamais toucher les voisines.
local MARKER_SIZE = 36
slotMarker = menu:CreateTexture(nil, "ARTWORK")
slotMarker:SetSize(MARKER_SIZE, MARKER_SIZE)
slotMarker:SetColorTexture(1, 1, 1, 0.14)
if menu.CreateMaskTexture then
    local markerMask = menu:CreateMaskTexture()
    markerMask:SetAllPoints(slotMarker)
    markerMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    slotMarker:AddMaskTexture(markerMask)
end
slotMarker:Hide()

emptyText = menu:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
emptyText:SetPoint("BOTTOM", menu, "BOTTOM", 0, PAD_BOTTOM + 14)
emptyText:SetWidth(MIN_WIDTH - 20)
emptyText:SetText(L("empty"))
emptyText:Hide()

local function AttachTooltip(frame, text)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Bouton fermer (X), même modèle que la fenêtre personnage
local HEADER_CENTER_Y = -(HEADER_H / 2 + 1)
local closeBtn = CreateCloseButton(menu)
closeBtn:ClearAllPoints()
closeBtn:SetPoint("RIGHT", menu, "TOPRIGHT", -8, HEADER_CENTER_Y)
closeBtn:SetScript("OnClick", function() menu:Hide() end)

-- Bouton verrou (même fonction que /mmd lock) : cadenas fermé = addon verrouillé,
-- ouvert = déverrouillé (déplacement actif). Mêmes icônes que l'interface Blizzard.
local LOCK_TEX   = "Interface\\Buttons\\LockButton-Locked-Up"
local UNLOCK_TEX = "Interface\\Buttons\\LockButton-Unlocked-Up"
-- La texture Blizzard contient déjà le bouton (disque rouge + cadenas) : on l'affiche seule, sans
-- cadre ajouté. Le bouton a la taille du X ; la texture, plus grande (marges transparentes
-- intégrées), est calée pour que sa partie visible ait la même taille que celle du X.
local lockBtn = CreateFrame("Button", "MinimapDrawerLockButton", menu)
local closeW, closeH = closeBtn:GetSize()
if not closeW or closeW < 1 then closeW, closeH = 32, 32 end
local iconK = closeBtn:GetNormalTexture() and 1.5 or 1.9 -- gabarit Blizzard : marges transparentes autour du X
lockBtn:SetSize(closeW, closeH)
lockBtn:SetPoint("RIGHT", closeBtn, "LEFT", 2, 0)
lockBtn:SetFrameLevel(menu:GetFrameLevel() + 60) -- au-dessus du voile rouge : reste cliquable en mode déplacement
local lockIcon = lockBtn:CreateTexture(nil, "ARTWORK")
lockIcon:SetSize(closeW * iconK, closeH * iconK)
lockIcon:SetPoint("CENTER", 0, 0)
lockIcon:SetTexture(LOCK_TEX)
-- Survol : même effet lumineux additif que le bouton fermer
lockBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
local lockHl = lockBtn:GetHighlightTexture()
if lockHl then
    lockHl:ClearAllPoints()
    lockHl:SetPoint("CENTER", 0, 0)
    lockHl:SetSize(closeW * 0.95, closeH * 0.95)
end
lockBtn:SetScript("OnMouseDown", function() lockIcon:SetPoint("CENTER", 1, -1) end)
lockBtn:SetScript("OnMouseUp", function() lockIcon:SetPoint("CENTER", 0, 0) end)

local function UpdateLockIcon()
    lockIcon:SetTexture(unlocked and UNLOCK_TEX or LOCK_TEX)
end

lockBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(unlocked and L("lock_on_tip") or L("lock_off_tip"), 1, 1, 1, 1, true)
    GameTooltip:Show()
end)
lockBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- "s" + champ de saisie
local secLabel = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
secLabel:SetPoint("RIGHT", lockBtn, "LEFT", -4, 0)
secLabel:SetText("s")

editBox = CreateInputBox("MinimapDrawerDelayBox", menu)
editBox:SetSize(36, 20)  -- 20 de haut = hauteur native des textures du gabarit
editBox:SetPoint("RIGHT", secLabel, "LEFT", -3, 0)
editBox:SetAutoFocus(false)
editBox:SetFontObject("GameFontHighlight")
editBox:SetJustifyH("CENTER")
editBox:SetTextInsets(0, 5, 0, 0) -- le capuchon gauche déborde de 5 px : on recentre le texte
editBox:SetMaxLetters(5)

-- Slider
slider = CreateFrame("Slider", "MinimapDrawerDelaySlider", menu, BACKDROP_TEMPLATE)
slider:SetOrientation("HORIZONTAL")
slider:SetHeight(17)
slider:SetPoint("LEFT", menu, "TOPLEFT", 12, HEADER_CENTER_Y)
slider:SetPoint("RIGHT", editBox, "LEFT", -10, 0)
slider:SetMinMaxValues(0, MAX_DELAY)
slider:SetValueStep(0.01)
slider:SetObeyStepOnDrag(true)
slider:SetHitRectInsets(0, 0, -10, -10)
slider:SetBackdrop(SLIDER_BACKDROP)
slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
slider:GetThumbTexture():SetSize(32, 32)

local function SetDelay(value, source)
    value = Clamp(Round2(value), 0, MAX_DELAY)
    DB.delay = value
    if source ~= "slider" then slider:SetValue(value) end
    editBox:SetText(FormatDelay(value))
    return value
end

local function CommitEdit(self)
    -- accepte "1,55" comme "1.55"
    local text = (self:GetText() or ""):gsub(",", ".")
    local v = tonumber(text)
    if v then
        SetDelay(v, "edit")
    else
        self:SetText(FormatDelay(DB.delay))
    end
end

slider:SetScript("OnValueChanged", function(_, value, userInput)
    if userInput then SetDelay(value, "slider") end
end)
editBox:SetScript("OnEnterPressed", function(self) CommitEdit(self); self:ClearFocus() end)
editBox:SetScript("OnEscapePressed", function(self) self:SetText(FormatDelay(DB.delay)); self:ClearFocus() end)
editBox:SetScript("OnEditFocusLost", function(self) CommitEdit(self) end)
editBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

AttachTooltip(slider, L("slider_tip"))
AttachTooltip(editBox, L("edit_tip"))

UpdateLockIcon()

-- Rafraîchissement automatique quand un bouton apparaît / disparaît
local acc = 0
menu:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.5 then return end
    acc = 0
    Scan()
    if not activeDrag and Signature() ~= lastSig then Layout() end
end)
menu:SetScript("OnShow", function() acc = 0; Scan(); Layout() end)
menu:SetScript("OnHide", function() editBox:ClearFocus() end)

---------------------------------------------------------------------
-- Zone sensible (cercle du niveau)
---------------------------------------------------------------------
-- (Clara Combo Points: in the windows' strata at UIParent's own level, so under every window (bags, character, quests:
-- all a level above it) and over the whole low strata (minimap, player frame, chat), however high a click raises them;
-- in HIGH it lay over the bags, and a click on a bag's close button there opened the drawer)
local HOTSPOT_STRATA = "MEDIUM"
local function HotspotLevel() return UIParent:GetFrameLevel() end
hotspot = CreateFrame("Button", "MinimapDrawerHotspot", UIParent)
hotspot:SetFrameStrata(HOTSPOT_STRATA)
hotspot:SetFrameLevel(HotspotLevel())
hotspot:SetSize(DEFAULT_HOTSPOT_SIZE, DEFAULT_HOTSPOT_SIZE)
hotspot:SetMovable(true)
hotspot:SetClampedToScreen(true)
hotspot:EnableMouse(true)
hotspot:RegisterForClicks("LeftButtonUp")
hotspot:RegisterForDrag("LeftButton")
-- (Clara Combo Points: over the player frame's level, a right-click goes through to the frame: its menu)
if hotspot.SetPassThroughButtons then pcall(hotspot.SetPassThroughButtons, hotspot, "RightButton") end

-- Disque rouge visible uniquement en mode déplacement
ring = hotspot:CreateTexture(nil, "OVERLAY")
ring:SetAllPoints()
ring:SetColorTexture(1, 0.1, 0.1, 0.40)
if hotspot.CreateMaskTexture then
    local mask = hotspot:CreateMaskTexture()
    mask:SetAllPoints()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    ring:AddMaskTexture(mask)
end
ring:Hide()

hint = hotspot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hint:SetPoint("BOTTOM", hotspot, "TOP", 0, 4)
hint:SetText(L("hint"))
hint:Hide()

local function FindLevelRegion()
    local pf = _G.PlayerFrame
    if pf then
        local content = pf.PlayerFrameContent
        local main = content and content.PlayerFrameContentMain
        if main and main.LevelText then return main.LevelText end
    end
    return _G.PlayerLevelText
end

local function DefaultHotspotPosition()
    local region = FindLevelRegion()
    if region and region.IsVisible and region:IsVisible() then
        local cx, cy = region:GetCenter()
        if cx and cy then
            local k = region:GetEffectiveScale() / UIParent:GetEffectiveScale()
            return cx * k, cy * k
        end
    end
    return UIParent:GetWidth() * 0.30, UIParent:GetHeight() * 0.35
end

local function ApplyHotspot()
    hotspot:ClearAllPoints()
    local h = DB.hotspot
    if h then
        hotspot:SetSize(h.size, h.size)
        hotspot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", h.x, h.y)
    else
        hotspot:SetSize(DEFAULT_HOTSPOT_SIZE, DEFAULT_HOTSPOT_SIZE)
        -- (Clara Combo Points: on the level circle itself, wherever the player frame in use puts it)
        local region = FindLevelRegion()
        if region then
            hotspot:SetPoint("CENTER", region, "CENTER")
        else
            local x, y = DefaultHotspotPosition()
            hotspot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        end
    end
end

local function SaveHotspot()
    local cx, cy = hotspot:GetCenter()
    if cx and cy then
        DB.hotspot = { x = Round2(cx), y = Round2(cy), size = hotspot:GetWidth() }
    end
end

---------------------------------------------------------------------
-- Position du menu : absolue, INDÉPENDANTE de la zone rouge
-- (le coin bas-droit du menu est ancré à UIParent ; il grandit vers la gauche / le haut)
---------------------------------------------------------------------
local function HotspotCenter()
    local h = DB.hotspot
    if h then return h.x, h.y end
    return DefaultHotspotPosition()
end

local function ApplyMenuAnchor()
    if not (DB.menuPos and DB.menuPos.x and DB.menuPos.y) then
        -- (Clara Combo Points: never moved by hand, it stays beside the hotspot, wherever that stands)
        menu:ClearAllPoints()
        menu:SetPoint("BOTTOMRIGHT", hotspot, "CENTER", DB.menuX or DEFAULTS.menuX, DB.menuY or DEFAULTS.menuY)
        return
    end
    menu:ClearAllPoints()
    menu:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", DB.menuPos.x, DB.menuPos.y)
end

local function SaveMenuPos()
    local mr, mb = menu:GetRight(), menu:GetBottom()
    if mr and mb then
        DB.menuPos = { x = Round2(mr), y = Round2(mb) }
    end
    ApplyMenuAnchor()
end

local function StartMenuMove()
    if unlocked then menu:StartMoving() end
end

local function StopMenuMove()
    menu:StopMovingOrSizing()
    SaveMenuPos()
end

menu:SetScript("OnDragStart", StartMenuMove)
menu:SetScript("OnDragStop", StopMenuMove)

-- Voile rouge semi-transparent « Move me! » : visible uniquement tant que l'addon est
-- déverrouillé. Il capte la souris sur tout le menu (on ne clique pas les icônes par erreur)
-- et fait glisser le menu, quel que soit l'endroit saisi.
overlay = CreateFrame("Frame", "MinimapDrawerMoveOverlay", menu)
overlay:SetPoint("TOPLEFT", menu, "TOPLEFT", OVERLAY_INSET, -OVERLAY_INSET)
overlay:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -OVERLAY_INSET, OVERLAY_INSET)
overlay:SetFrameLevel(menu:GetFrameLevel() + 40) -- au-dessus des icônes capturées
overlay:EnableMouse(true)
overlay:RegisterForDrag("LeftButton")
overlay:SetScript("OnDragStart", StartMenuMove)
overlay:SetScript("OnDragStop", StopMenuMove)
overlay:Hide()

local overlayBg = overlay:CreateTexture(nil, "BACKGROUND")
overlayBg:SetAllPoints()
overlayBg:SetColorTexture(1, 0.1, 0.1, OVERLAY_ALPHA)

local overlayText = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
overlayText:SetPoint("LEFT", overlay, "LEFT", 6, 0)
overlayText:SetPoint("RIGHT", overlay, "RIGHT", -6, 0)
overlayText:SetJustifyH("CENTER")
overlayText:SetText(L("move_me"))

---------------------------------------------------------------------
-- Ouverture / fermeture
---------------------------------------------------------------------
local function CancelHover()
    if hoverTimer then hoverTimer:Cancel(); hoverTimer = nil end
end

local function Open()
    if menu:IsShown() then return end
    menu:Show()
end

local function Close()
    menu:Hide()
end

local function Toggle()
    if menu:IsShown() then Close() else Open() end
end

-- (Clara Combo Points: the mouse already on the circle as the world shows (a reload by the portrait's
-- double middle-click, the cursor left there) opens nothing: it has to leave the circle and come back)
local hoverArmed = true
local quietUntil = math.huge -- (until the world has shown, and a moment after)
hotspot:SetScript("OnEnter", function()
    if GetTime() < quietUntil then hoverArmed = false end
    if not hoverArmed then return end
    if unlocked or menu:IsShown() or not DB.autoopen then return end
    CancelHover()
    local delay = DB.delay
    if delay <= 0 then
        Open()
    else
        hoverTimer = C_Timer.NewTimer(delay, function()
            hoverTimer = nil
            if not unlocked and DB.autoopen then Open() end
        end)
    end
end)

hotspot:SetScript("OnLeave", function()
    hoverArmed = true
    CancelHover()
end)
local function DisarmIfUnderMouse()
    local ok, over = pcall(hotspot.IsMouseOver, hotspot)
    if ok and not (issecretvalue and issecretvalue(over)) and over == true then
        hoverArmed = false
        CancelHover()
    end
end

hotspot:SetScript("OnClick", function()
    if unlocked then return end
    CancelHover()
    Toggle() -- un simple clic ouvre / ferme le menu
end)

hotspot:SetScript("OnDragStart", function(self) if unlocked then self:StartMoving() end end)
hotspot:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveHotspot()
end)

hotspot:SetScript("OnMouseWheel", function(self, delta)
    if not unlocked then return end
    local size = Clamp(self:GetWidth() + delta * 2, 12, 90)
    self:SetSize(size, size)
    SaveHotspot()
end)

local function SetUnlocked(flag, keepOpen)
    unlocked = flag
    UpdateLockIcon()
    ReleaseFreeLocks() -- /mmd lock comme /mmd unlock : les icônes libres redeviennent déplaçables
    CancelHover()
    hotspot:EnableMouseWheel(flag)
    -- En mode déplacement, la zone passe au-dessus du voile : on peut toujours l'attraper,
    -- même si le menu a été posé par-dessus.
    hotspot:SetFrameStrata(flag and "DIALOG" or HOTSPOT_STRATA)
    hotspot:SetFrameLevel(flag and 100 or HotspotLevel())
    overlay:SetShown(flag)
    if flag then
        ring:Show()
        hint:Show()
        Open() -- le menu s'ouvre pour pouvoir être déplacé
    else
        ring:Hide()
        hint:Hide()
        SaveHotspot() -- la position du menu est déjà enregistrée à chaque fin de glisser
        if not keepOpen then Close() end
    end
end

-- Verrou : verrouillé -> déverrouille, déverrouillé -> verrouille (bouton et /mmd lock)
local function ToggleLock(keepOpen)
    if unlocked then
        SetUnlocked(false, keepOpen)
        Print(L("msg_locked"))
    else
        SetUnlocked(true)
        Print(L("msg_unlocked"))
    end
end

-- Le cadenas verrouille sans fermer le menu (/mmd lock, lui, le ferme comme avant)
lockBtn:SetScript("OnClick", function() ToggleLock(true) end)

---------------------------------------------------------------------
-- Double clic molette sur le cadre du joueur (portrait, nom, vie, mana) : /reload (option : /mmd portrait)
---------------------------------------------------------------------
local lastMiddle = 0

local function OnMiddleRelease(button)
    if button ~= "MiddleButton" or not DB or not DB.portraitReload then return end
    local now = GetTime()
    if now - lastMiddle <= DOUBLE_CLICK_WINDOW then
        lastMiddle = 0
        ReloadUI()
    else
        lastMiddle = now
    end
end

-- La zone rouge recouvre le badge de niveau, qui fait partie du portrait : elle relaie aussi
-- le clic molette (sauf en mode déplacement).
hotspot:SetScript("OnMouseUp", function(_, button)
    if unlocked then return end
    OnMiddleRelease(button)
end)

-- Tout le cadre du joueur compte : portrait, nom, barre de vie, barre de mana. On accroche le
-- cadre lui-même et ses barres (au cas où elles captent la souris dans cette version du client).
-- (Clara Combo Points: only the bars that take their clicks already: a mouse script set on one turns
-- its clicks on, and the frame under it, the right-click's menu included, would get none.)
local function TakesClicks(f)
    if f.IsMouseClickEnabled then return f:IsMouseClickEnabled() and true or false end
    return f.IsMouseEnabled and f:IsMouseEnabled() and true or false
end

local function HookPlayerFrame()
    local pf = _G.PlayerFrame
    if not pf then return end
    local content = pf.PlayerFrameContent
    local main = content and content.PlayerFrameContentMain
    local targets = {
        pf,
        _G.PlayerFrameHealthBar, _G.PlayerFrameManaBar,
        main and main.HealthBarsContainer, main and main.HealthBarsContainer and main.HealthBarsContainer.HealthBar,
        main and main.ManaBarArea, main and main.ManaBarArea and main.ManaBarArea.ManaBar,
    }
    for _, f in pairs(targets) do
        if type(f) == "table" and f.HookScript and f.HasScript and (f == pf or TakesClicks(f)) then
            pcall(f.HookScript, f, "OnMouseUp", function(_, button) OnMiddleRelease(button) end)
        end
    end
end

---------------------------------------------------------------------
-- Commandes /mmd
---------------------------------------------------------------------
local function ButtonLabel(btn)
    return btn:GetName() or L("no_name")
end

local function ShowHelp()
    Print(L("help_title"))
    for _, key in ipairs({ "h_unlock1", "h_unlock2", "h_lock", "h_toggle", "h_autoopen", "h_portrait",
                           "h_delay", "h_cols", "h_list", "h_debug", "h_reorder", "h_free1", "h_free2",
                           "h_ignore", "h_reset", "h_rl" }) do
        print(L(key))
    end
end

-- (Clara Combo Points: /rl is Clara's own)

SLASH_MINIMAPDRAWER1 = "/mmd"
SLASH_MINIMAPDRAWER2 = "/minimapdrawer"
SlashCmdList["MINIMAPDRAWER"] = function(msg)
    msg = msg or ""
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()

    if cmd == "unlock" or cmd == "move" then
        SetUnlocked(true)
        Print(L("msg_unlock_cmd"))
    elseif cmd == "lock" then
        ToggleLock() -- /mmd lock alterne : verrouillé -> déverrouille, déverrouillé -> verrouille
    elseif cmd == "toggle" or cmd == "open" then
        Toggle()
    elseif cmd == "autoopen" or cmd == "ao" then
        DB.autoopen = not DB.autoopen
        if not DB.autoopen then CancelHover() end
        Print(L("msg_autoopen", DB.autoopen and "|cff33ff99on|r" or "|cffff5555off|r"))
    elseif cmd == "portrait" then
        DB.portraitReload = not DB.portraitReload
        Print(L("msg_portrait", DB.portraitReload and "|cff33ff99on|r" or "|cffff5555off|r"))
    elseif cmd == "delay" then
        local v = tonumber((arg:gsub(",", ".")))
        if v then
            Print(L("msg_delay", FormatDelay(SetDelay(v))))
        else
            Print(L("usage_delay"))
        end
    elseif cmd == "cols" then
        local v = tonumber(arg)
        if v then
            DB.columns = Clamp(math.floor(v), 2, 12)
            lastSig = nil
            if menu:IsShown() then Layout() end
            Print(L("msg_cols", DB.columns))
        else
            Print(L("usage_cols"))
        end
    elseif cmd == "list" then
        Scan()
        if #buttons == 0 then
            Print(L("list_none"))
        else
            Print(L("list_count", #buttons))
            for _, btn in ipairs(buttons) do
                print("  " .. ButtonLabel(btn)
                    .. (info[btn].free and (info[btn].locked and ("  |cff33ff99" .. L("tag_free_locked") .. "|r") or ("  |cff33ff99" .. L("tag_free") .. "|r")) or "")
                    .. (btn:IsShown() and "" or ("  |cff888888" .. L("tag_hidden") .. "|r")))
            end
        end
    elseif cmd == "debug" then
        Scan()
        Print(L("dbg_title"))
        for _, btn in ipairs(buttons) do
            local i = info[btn]
            print(string.format(L("dbg_line"),
                ButtonLabel(btn),
                i.free and L("dbg_free") or L("dbg_menu"),
                btn:GetScript("OnDragStart") == OnIconDragStart and L("dbg_ok") or ("|cffff5555" .. L("dbg_over") .. "|r"),
                (btn.IsMovable and btn:IsMovable()) and L("dbg_yes") or ("|cffff5555" .. L("dbg_no") .. "|r"),
                i.locked and L("dbg_yes") or L("dbg_no")))
        end
    elseif cmd == "ignore" and arg ~= "" then
        DB.ignore[arg] = true
        Print(L("ignore_msg", arg))
    elseif cmd == "unignore" and arg ~= "" then
        DB.ignore[arg] = nil
        Print(L("unignore_msg", arg))
    elseif cmd == "reset" then
        DB.hotspot = nil
        DB.menuX, DB.menuY = DEFAULTS.menuX, DEFAULTS.menuY
        DB.menuPos = nil -- recalculée depuis la zone par défaut
        DB.free = {}
        DB.order = {}
        orderList = nil
        for _, btn in ipairs(buttons) do
            if info[btn].free then SetAttached(btn) end
        end
        DB.columns = DEFAULTS.columns
        DB.autoopen = DEFAULTS.autoopen
        DB.portraitReload = DEFAULTS.portraitReload
        SetDelay(DEFAULTS.delay)
        lastSig = nil
        ApplyHotspot()
        ApplyMenuAnchor()
        SetUnlocked(true)
        Print(L("reset_msg"))
    else
        ShowHelp()
    end
end

---------------------------------------------------------------------
-- Événements
---------------------------------------------------------------------
local function OnLogin()
    BuildBlizzIndex(_G.Minimap)
    BuildBlizzIndex(_G.MinimapBackdrop)

    local firstRun = (DB.hotspot == nil)
    ApplyHotspot()
    ApplyMenuAnchor()
    SetDelay(DB.delay)
    HookLibDBIcon()
    HookPlayerFrame()
    Scan()
    C_Timer.NewTicker(5, Scan)

    -- (Clara Combo Points: built in, it starts on the level circle, locked and quiet)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then InitDB() end
    elseif event == "PLAYER_LOGIN" then
        OnLogin()
    elseif event == "PLAYER_ENTERING_WORLD" then
        quietUntil = GetTime() + 2
        DisarmIfUnderMouse() -- (Clara Combo Points: no drawer opened by a mouse left on the circle)
        -- les autres addons créent leurs boutons au fil du chargement
        C_Timer.After(1, Scan)
        C_Timer.After(3, Scan)
        C_Timer.After(8, Scan)
    end
end)

-- (Clara Combo Points: its settings and its drawer, for its theme's page: Glue.lua)
ClaraNS.MinimapDrawerSettings = function() return DB end
ClaraNS.MinimapDrawerToggle = function() if DB then Toggle() end end
ClaraNS.MinimapDrawerCancelHover = CancelHover
