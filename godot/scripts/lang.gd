class_name Lang
extends RefCounted
## Tiny gettext-style translation: the English text is the key, `Lang.t("Text")`
## returns the French version when French is selected (and falls back to the
## English text for anything missing). Format arguments: `Lang.t("Run %d", [3])`.

const LANGUAGES: Array[String] = ["en", "fr"]
const NATIVE_NAMES := {"en": "English", "fr": "Français"}

static var current := "en"

const FR := {
    # HUD
    "Points: %d": "Points : %d",
    "Acorns: %d": "Glands : %d",
    "%s (%d ammo)  [Q]": "%s (%d munitions)  [Q]",
    "RUN %d": "MANCHE %d",
    "PAUSED": "PAUSE",
    "RUN %d COMPLETE": "MANCHE %d TERMINÉE",
    "BOSS DEFEATED!": "BOSS VAINCU !",
    "WARNING: BOSS!": "ATTENTION : BOSS !",
    "+%d coins": "+%d pièces",
    "BOSS": "BOSS",
    # menus
    "GAME OVER": "PARTIE TERMINÉE",
    "Final Score: %d   (Best: %d)": "Score final : %d   (Record : %d)",
    "Reached run %d": "Manche %d atteinte",
    "Restart": "Recommencer",
    "Continue": "Continuer",
    "Show Controls": "Voir les commandes",
    "Quit": "Quitter",
    "Language: %s": "Langue : %s",
    "Use UP/DOWN to navigate, ENTER/SPACE to select": "HAUT/BAS pour naviguer, ENTRÉE/ESPACE pour choisir",
    "LEFT/RIGHT changes the language": "GAUCHE/DROITE change la langue",
    # controls
    "Controls": "Commandes",
    "SPACE - Jump": "ESPACE - Sauter",
    "SHIFT - Throw weapon": "MAJ - Lancer l'arme",
    "Q - Switch weapon": "Q - Changer d'arme",
    "F - Matrix Fist (slow-motion punch)": "F - Poing Matrix (coup au ralenti)",
    "ESC - Pause menu": "ÉCHAP - Menu pause",
    "Survive 60 s per run. A boss waits every 3rd run!": "Survivez 60 s par manche. Un boss attend toutes les 3 manches !",
    "Boxes give acorns (ammo) and coins.": "Les caisses donnent des glands (munitions) et des pièces.",
    "Defeated enemies drop coins.": "Les ennemis vaincus laissent des pièces.",
    "Spend coins in the Shop between runs.": "Dépensez vos pièces à la boutique entre les manches.",
    "You can stand on trees and enemies!": "Vous pouvez vous tenir sur les arbres et les ennemis !",
    "Press ESC, ENTER, or SPACE to return": "ÉCHAP, ENTRÉE ou ESPACE pour revenir",
    # shop
    "SHOP": "BOUTIQUE",
    "Welcome! Take a look at my wares.": "Bienvenue ! Jetez un œil à mes marchandises.",
    "Ready for the next run?": "Prêt pour la manche suivante ?",
    "EQUIPPED": "ÉQUIPÉ",
    "OWNED": "POSSÉDÉ",
    "MAX": "MAX",
    "%d coins": "%d pièces",
    "Start run %d": "Lancer la manche %d",
    "Start run %d (BOSS)": "Lancer la manche %d (BOSS)",
    "UP/DOWN select - ENTER buy / equip": "HAUT/BAS choisir - ENTRÉE acheter / équiper",
    "Bought %s!": "%s acheté !",
    "Not enough coins.": "Pas assez de pièces.",
    "%s equipped.": "%s équipé.",
    "Pouch upgraded!": "Bourse améliorée !",
    "Pouch is already at maximum.": "La bourse est déjà au maximum.",
    "Extra Life": "Vie supplémentaire",
    "Lives: %d/%d. Also won from bosses and 1UP hearts.": "Vies : %d/%d. Aussi gagnées contre les boss et avec les cœurs 1UP.",
    "You already have the maximum lives.": "Vous avez déjà le maximum de vies.",
    "Extra life!": "Vie supplémentaire !",
    "+1 life": "+1 vie",
    "Matrix Fist": "Poing Matrix",
    "Pack of 3 uses (key F): slow-motion dash across the screen, punching everything for 3 damage.": "Lot de 3 usages (touche F) : ruée au ralenti à travers l'écran, tout est frappé pour 3 dégâts.",
    "owned": "possédés",
    "Bigger Pouch (+1 start acorn)": "Grande bourse (+1 gland)",
    "Start every run with %d acorns (level %d/%d).": "Chaque manche commence avec %d glands (niveau %d/%d).",
    "Costs 1 acorn per throw.": "Coûte 1 gland par lancer.",
    "Costs %d acorns per throw.": "Coûte %d glands par lancer.",
    # weapons
    "Acorn": "Gland",
    "Triple Acorn": "Triple gland",
    "Boomerang": "Boomerang",
    "Bouncing Chestnut": "Châtaigne rebondissante",
    "Pinecone Bomb": "Bombe de pomme de pin",
    "Rainbow Beam": "Rayon arc-en-ciel",
    "Homing Acorn": "Gland à tête chercheuse",
    "Straight shot. Cheap and reliable.": "Tir droit. Économique et fiable.",
    "Three acorns in a fan.": "Trois glands en éventail.",
    "Flies out and back: can hit twice.": "Va et revient : peut toucher deux fois.",
    "Arcs and bounces along the ground.": "Décrit un arc et rebondit au sol.",
    "Slow lob that explodes: area damage.": "Lob lent qui explose : dégâts de zone.",
    "Fast, hits hard, pierces every enemy in line.": "Rapide, puissant, traverse tous les ennemis alignés.",
    "Steers toward the nearest enemy.": "Se dirige vers l'ennemi le plus proche.",
}


## Translate `text` (and format it with `args` when given).
static func t(text: String, args: Array = []) -> String:
    var out: String = FR.get(text, text) if current == "fr" else text
    return out % args if not args.is_empty() else out


static func native_name(code := current) -> String:
    return NATIVE_NAMES[code]


## "fr" when the OS language is French, else "en" (used until the player picks one).
static func detect() -> String:
    return "fr" if OS.get_locale_language() == "fr" else "en"


static func next_language(code := current) -> String:
    return LANGUAGES[(LANGUAGES.find(code) + 1) % LANGUAGES.size()]
