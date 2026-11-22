class_name Profile
extends RefCounted
## Everything that persists between runs: banked coins, owned/equipped weapons
## and upgrades. Stored in user:// (a browser's IndexedDB on the web build).
## Tests point `save_path` at a scratch file so they never touch a real save.

static var save_path := "user://squirrel.cfg"

var coins := 0
var owned: Array[String] = ["acorn"]
var equipped := "acorn"
var ammo_level := 0  # extra starting acorns bought in the shop
var best_score := 0


func load_from_disk() -> void:
    var cf := ConfigFile.new()
    if cf.load(save_path) != OK:
        return
    coins = maxi(0, int(cf.get_value("profile", "coins", 0)))
    ammo_level = clampi(int(cf.get_value("profile", "ammo_level", 0)), 0, Weapons.AMMO_UPGRADE_PRICES.size())
    best_score = maxi(0, int(cf.get_value("profile", "best_score", 0)))
    owned.clear()
    owned.append("acorn")
    for id in cf.get_value("profile", "owned", ["acorn"]):
        if Weapons.DEFS.has(id) and not owned.has(str(id)):
            owned.append(str(id))
    equipped = str(cf.get_value("profile", "equipped", "acorn"))
    if not owned.has(equipped):
        equipped = "acorn"


func save() -> void:
    var cf := ConfigFile.new()
    cf.set_value("profile", "coins", coins)
    cf.set_value("profile", "owned", owned)
    cf.set_value("profile", "equipped", equipped)
    cf.set_value("profile", "ammo_level", ammo_level)
    cf.set_value("profile", "best_score", best_score)
    cf.save(save_path)


func add_coins(n: int) -> void:
    coins += n
    save()


func owns(id: String) -> bool:
    return owned.has(id)


func equip(id: String) -> void:
    if owns(id):
        equipped = id
        save()


## Buy and equip a weapon. False when already owned or too expensive.
func buy_weapon(id: String) -> bool:
    var price: int = Weapons.DEFS[id]["price"]
    if owns(id) or coins < price:
        return false
    coins -= price
    owned.append(id)
    equipped = id
    save()
    return true


## Price of the next "+1 starting acorn" level, or -1 when maxed out.
func ammo_upgrade_price() -> int:
    if ammo_level >= Weapons.AMMO_UPGRADE_PRICES.size():
        return -1
    return Weapons.AMMO_UPGRADE_PRICES[ammo_level]


func buy_ammo_upgrade() -> bool:
    var price := ammo_upgrade_price()
    if price < 0 or coins < price:
        return false
    coins -= price
    ammo_level += 1
    save()
    return true


func start_ammo() -> int:
    return Weapons.START_AMMO + ammo_level


func record_score(score: int) -> void:
    if score > best_score:
        best_score = score
        save()
