class_name Profile
extends RefCounted
## What survives between games (stored in user:// - a browser's IndexedDB on
## the web build): best score, furthest run and the chosen language.
## Coins, weapons and upgrades do NOT live here: every new game starts from
## scratch (see Loadout). Tests point `save_path` at a scratch file.

static var save_path := "user://squirrel.cfg"

var best_score := 0
var best_run := 0
var language := ""  # "" = not chosen yet -> follow the OS language


func load_from_disk() -> void:
    var cf := ConfigFile.new()
    if cf.load(save_path) == OK:
        best_score = maxi(0, int(cf.get_value("profile", "best_score", 0)))
        best_run = maxi(0, int(cf.get_value("profile", "best_run", 0)))
        language = str(cf.get_value("profile", "language", ""))
    if not Lang.LANGUAGES.has(language):
        language = ""
    Lang.current = language if language != "" else Lang.detect()


func save() -> void:
    var cf := ConfigFile.new()
    cf.set_value("profile", "best_score", best_score)
    cf.set_value("profile", "best_run", best_run)
    cf.set_value("profile", "language", language)
    cf.save(save_path)


func set_language(code: String) -> void:
    language = code
    Lang.current = code
    save()


func record_game(score: int, run: int) -> void:
    if score > best_score or run > best_run:
        best_score = maxi(best_score, score)
        best_run = maxi(best_run, run)
        save()
