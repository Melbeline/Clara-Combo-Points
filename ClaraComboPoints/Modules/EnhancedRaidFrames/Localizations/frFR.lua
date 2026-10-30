-- Enhanced Raid Frames is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2025 Britt W. Yazel
-- This code is licensed under the MIT license (see LICENSE for details)

local _, ClaraNS = ... -- (Clara Combo Points: only for Enhanced Raid Frames built in)
if not ClaraNS.ERFRuns then return end

local L = LibStub("AceLocale-3.0"):NewLocale("EnhancedRaidFrames", "frFR", false)

if not L then
	return
end

-------------------------------------------------------------------------
-------------------------------------------------------------------------

L["Animations"] = "Animations"
L["Attached to Cursor"] = "Attaché au curseur"
L["Aura Watch List"] = "Liste de surveillance d'aura"
L["auras_desc"] = "La liste des buffs, debuffs, et/ou caractères génériques à regarder dans cette position"
L["auras_usage"] = "N'importe quel nom d'aura ou d'ID de sort trouvé dans le jeu, épelé correctement, devrait fonctionner"
L["Background Opacity"] = "Opacité du fond"
L["backgroundAlpha_desc"] = "Le pourcentage d'opacité du fond du cadre de raid"
L["Blizzard Default"] = "Défaut Blizzard"
L["curseWildcard_desc"] = "N'importe quel malédiction"
L["customRange_desc"] = "Remplace la valeur par défaut (40 yards) de la distance de l'indicateur hors de portée"
L["customRangeCheck_desc"] = "Change la valeur par défaut de 40 yard pour l'indicateur de hors de porté à la distance spécifiée"
L["diseaseWildcard_desc"] = "N'importe quel debuff de maladie"
L["frameScale_desc"] = "L'échelle du cadre de raid par rapport à la taille normale"
L["Glow At Countdown Time"] = "Lueur au compte à rebours"
L["glowRemainingSecs_desc1"] = "La durée (en secondes) restante sur le compte à rebours de buff ou debuff avant que le brillant commence"
L["glowRemainingSecs_desc2"] = "'0' veux dire que cela va toujours briller"
L["Icon"] = "Îcone"
L["Icon and Visuals"] = "Icône et visuels"
L["Icon Opacity"] = "Opacité de l'icône"
L["Indicator Color"] = "Couleur de l'indicateur"
L["Indicator Font"] = "Police de l'indicateur"
L["Indicator Glow Effect"] = "Indicateur d'effet lumineux"
L["Indicator Size"] = "Taille de l'indicateur"
L["indicatorAlpha_desc"] = "Le pourcentage d'opacité de l'icône de l'indicateur"
L["indicatorColor_desc1"] = "La couleur utilisée pour l'indicateur lorsqu'il n'affiche pas l'icône de buff ou de debuff"
L["indicatorColor_desc2"] = "sauf si augmenté par d'autres options de couleur (Need to verify ''augmenté'', need context of this one)"
L["indicatorFont_desc"] = "La police utilisée pour les indicateurs"
L["indicatorGlow_desc"] = "Afficher un effet d'animation de brillance sur l'indicateur pour le rendre plus facile à repérer"
L["indicatorOptions_desc"] = "Veuillez sélectionner une position pour l'indicateur dans le menu déroulant ci-dessous"
L["indicatorSize_desc"] = "La taille de l'indicateur en pixels"
L["instructions_desc1"] = "La case à droite contient la liste des auras à surveiller à la position sélectionnée"
L["magicWildcard_desc"] = "tout debuff magique"
L["meOnly_desc"] = "Afficher uniquement cet indicateur sur moi-même"
L["Mine Only"] = "Seulement les miens"
L["mineOnly_desc"] = "Afficher uniquement les buffs et debuffs lancés par moi"
L["missingOnly_desc"] = "Afficher uniquement lorsque le buff ou le debuff est manquant"
L["Out-of-Range"] = "Hors de portée"
L["Out-of-Range Opacity"] = "Opacité hors de portée"
L["Override Default Distance"] = "Remplacer la distance par défaut"
L["poisonWildcard_desc"] = "tout debuff de poison"
L["Position"] = "Position"
L["rangeAlpha_desc"] = "Le pourcentage d'opacité du cadre de raid lorsqu'il est hors de portée"
L["Select a Custom Distance"] = "Sélectionnez une distance personnalisée"
L["Show Countdown Swipe"] = "Afficher le compte à rebours"
L["Show Icon"] = "Montrer l'icône"
L["Show On Me Only"] = "Afficher uniquement sur moi"
L["Show Only if Missing"] = "Afficher uniquement si manquant"
L["Show Tooltip"] = "Afficher l'info-bulle"
L["showCountdownSwipe_desc"] = "Afficher l'animation de balayage dans le sens horaire indiquant le temps restant sur le buff ou le debuff"
L["showIcon_desc1"] = "Afficher une icône si le buff ou le debuff est actuellement sur l'unité"
L["showIcon_desc2"] = "si pas cochée, une couleur unie sera utilisé pour l'indicateur "
L["showTooltip_desc"] = "Afficher l'info-bulle au survol de la souris"
L["Text"] = "Texte"
L["Text Color"] = "Couleur du texte"
L["textColor_desc1"] = "La couleur utilisée pour le texte de l'indicateur"
L["textColor_desc2"] = "sauf si augmenté par d'autres options de couleur de texte (Need context for augmented)"
L["Tooltip Location"] = "Emplacement de l'info-bulle"
L["tooltipLocation_desc"] = "L'emplacement spécifié où l'infobulle doit apparaître"
L["Tooltips"] = "Infobulle"
L["Visibility and Behavior"] = "Visibilité et comportement"



-- (Clara Combo Points : le reste de la traduction, et WoW Forever)
L["General"] = "Général"
L["General Options"] = "Options générales"
L["Indicator Options"] = "Options des indicateurs"
L["Target Marker Options"] = "Options des marqueurs de cible"
L["Profiles"] = "Profils"
L["Vertical Offset"] = "Décalage vertical"
L["verticalOffset_desc"] = "Le décalage vertical, en pourcentage de la hauteur du cadre, depuis la position de départ"
L["Horizontal Offset"] = "Décalage horizontal"
L["horizontalOffset_desc"] = "Le décalage horizontal, en pourcentage de la largeur du cadre, depuis la position de départ"
L["Example"] = "Exemple"
L["Wildcards"] = "Mots-clés"
L["Color"] = "Couleur"
L["Color By Debuff Type"] = "Couleur selon le type de debuff"
L["colorByDebuff_desc"] = "La couleur dépend du type de debuff"
L["Color By Remaining Time"] = "Couleur selon le temps restant"
L["colorByTime_desc"] = "La couleur dépend du temps restant"
L["colorOverride_desc"] = "remplace la couleur normale"
L["zeroMeansIgnored_desc"] = "0 : ce réglage est ignoré"
L["Time #1"] = "Temps n° 1"
L["colorByTime_low_desc"] = "Le temps (en secondes) de la limite basse"
L["Time #2"] = "Temps n° 2"
L["colorByTime_high_desc"] = "Le temps (en secondes) de la limite haute"
L["Dispel"] = "Dissipation"
L["Poison"] = "Poison"
L["Curse"] = "Malédiction"
L["Disease"] = "Maladie"
L["Magic"] = "Magie"
L["Bleed"] = "Saignement"
L["Top-Left"] = "En haut à gauche"
L["Top"] = "En haut"
L["Top-Right"] = "En haut à droite"
L["Left"] = "À gauche"
L["Center"] = "Au centre"
L["Right"] = "À droite"
L["Bottom-Left"] = "En bas à gauche"
L["Bottom"] = "En bas"
L["Bottom-Right"] = "En bas à droite"
L["Melee"] = "Mêlée"
L["10 yards"] = "10 mètres"
L["15 yards"] = "15 mètres"
L["20 yards"] = "20 mètres"
L["25 yards"] = "25 mètres"
L["30 yards"] = "30 mètres"
L["35 yards"] = "35 mètres"
L["40 yards"] = "40 mètres"
L["generalOptions_desc"] = "Voici les options générales. Ouvre la ligne « Enhanced Raid Frames » dans la colonne de gauche pour régler les indicateurs d'auras, les marqueurs de cible et le reste"
L["Open the Blizzard Raid Profiles Options"] = "Ouvrir les profils de raid du jeu"
L["blizzardRaidOptionsButton_desc"] = "Ouvre les options des profils de raid du jeu"
L["Default Icon Visibility"] = "Icônes du jeu"
L["Stock Buff Icons"] = "Icônes des buffs du jeu"
L["showBuffs_desc"] = "Afficher les icônes de buffs des cadres de raid du jeu"
L["Stock Debuff Icons"] = "Icônes des debuffs du jeu"
L["showDebuffs_desc"] = "Afficher les icônes de debuffs des cadres de raid du jeu"
L["Stock Dispellable Icons"] = "Icônes des debuffs dissipables du jeu"
L["showDispellableDebuffs_desc"] = "Afficher les icônes de debuffs dissipables des cadres de raid du jeu"
L["Power Bar Vertical Offset"] = "Décalage au-dessus de la barre de ressource"
L["powerBarOffset_desc"] = "Décale les icônes et indicateurs vers le haut pour ne pas couvrir la barre de ressource (mana, rage, énergie)"
L["Raidframe Scale"] = "Échelle des cadres de raid"
L["Mouseover Cast Compatibility"] = "Compatibilité avec les sorts au survol"
L["mouseoverCast_desc"] = "Laisse passer le survol jusqu'au cadre de raid, pour les macros de sorts au survol. Les infobulles des indicateurs ne s'affichent plus."
L["markerOptions_desc"] = "Comment le marqueur de cible apparaît sur les cadres de raid"
L["Show Target Markers"] = "Afficher les marqueurs de cible"
L["showTargetMarkers_desc"] = "Affiche le marqueur de cible (crâne, croix…) sur les cadres de raid"
L["Target Marker Size"] = "Taille du marqueur"
L["markerSize_desc"] = "La taille du marqueur, en pixels"
L["Target Marker Opacity"] = "Opacité du marqueur"
L["markerAlpha_desc"] = "L'opacité du marqueur, en pourcentage"
L["Marker Position"] = "Position du marqueur"
L["markerPosition_desc"] = "La position du marqueur sur le cadre"
L["dispelWildcard_desc"] = "tous les debuffs que tu peux dissiper"
L["bleedWildcard_desc"] = "tous les saignements (Retail seulement)"
L["Show Countdown Text"] = "Afficher le temps restant"
L["showCountdownText_desc"] = "Affiche le temps restant du buff ou du debuff"
L["Show Stack Size"] = "Afficher les charges"
L["showStackSize_desc"] = "Affiche le nombre de charges du buff ou du debuff"
L["Countdown Text Size"] = "Taille du temps restant"
L["countdownTextSize_desc"] = "La taille du texte du temps restant (en pixels)"
L["Stack Size Location"] = "Position des charges"
L["stackSizeLocation_desc"] = "Où s'affiche le nombre de charges dans l'indicateur"
L["The database is being migrated to version:"] = "Mise à jour des réglages vers la version :"
L["Database migration successful."] = "Réglages mis à jour."
L["Profile"] = "Profil"
L["Import"] = "Importer"
L["Export"] = "Exporter"
L["Import or Export the current profile:"] = "Importer ou exporter le profil actuel :"
L["ImportExport_Desc"] = [[

Voici le profil Enhanced Raid Frames actuel, sous forme de texte.

Pour l'exporter, sélectionne tout le texte ci-dessous, copie-le et garde-le en lieu sûr.

Pour importer un profil, remplace le texte ci-dessous par celui du profil et valide.
]]
L["ImportExport_WarningDesc"] = [[

Copier et coller un profil peut prendre du temps : le jeu peut se figer quelques secondes.

ATTENTION : cela remplace le profil actuel, et ses réglages sont perdus.
]]
L["ImportWarning"] = "Es-tu certain de vouloir importer ce profil ? Le profil actuel sera remplacé."
L["No data to import."] = "Rien à importer."
L["Decoding failed."] = "Le décodage a échoué."
L["Decompression failed."] = "La décompression a échoué."
L["Data import Failed."] = "L'import a échoué."
L["Aborting."] = "Abandon."
L["Experimental"] = "Expérimental"
L["Experimental Options"] = "Options expérimentales"
L["Experimental_Options_Warning"] = [[

Attention :

Voici des options expérimentales, potentiellement risquées.
]]
L["forever_indicators_desc"] = "En combat, WoW Forever cache les auras aux addons. Les buffs écrits par nom ou par ID de sort, et les debuffs par type (Magic, Curse, Poison, Disease, Dispel), sont affichés par le jeu lui-même, en combat aussi. Les debuffs écrits un par un, par nom ou ID, s'affichent hors combat."
L["forever_outOfCombat_desc"] = "WoW Forever : hors combat seulement"
L["forever_stockIcons_desc"] = "Dans WoW Forever, le jeu dessine lui-même les buffs et debuffs de ses cadres de raid : on les affiche ou les masque dans les options des profils de raid du jeu (bouton ci-dessus)."
L["forever_range_desc"] = "WoW Forever garde secrète la distance aux membres du groupe : les cadres pâlissent à la portée du jeu, jusqu'à l'opacité réglée ci-dessous."
