class_name Loadout
extends RefCounted
## Everything you own during ONE game (a series of runs): coins, weapons and
## upgrades. A new game starts empty again - nothing here is saved to disk.

var coins := 0
var owned: Array[String] = ["acorn"]
var equipped := "acorn"
var ammo_level := 0  # extra starting acorns bought in the shop
var fists := 0       # Matrix Fist charges in the bag (each use consumes one)
var lives := Weapons.START_LIVES


func add_coins(n: int) -> void:
    coins += n


func owns(id: String) -> bool:
    return owned.has(id)


func equip(id: String) -> void:
    if owns(id):
        equipped = id


## Buy and equip a weapon. False when already owned or too expensive.
func buy_weapon(id: String) -> bool:
    var price: int = Weapons.DEFS[id]["price"]
    if owns(id) or coins < price:
        return false
    coins -= price
    owned.append(id)
    equipped = id
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
    return true


## +1 life up to MAX_LIVES. False when already full.
func add_life() -> bool:
    if lives >= Weapons.MAX_LIVES:
        return false
    lives += 1
    return true


func buy_life() -> bool:
    if lives >= Weapons.MAX_LIVES or coins < Weapons.LIFE_PRICE:
        return false
    coins -= Weapons.LIFE_PRICE
    lives += 1
    return true


func buy_fist() -> bool:
    if coins < Weapons.FIST_PRICE:
        return false
    coins -= Weapons.FIST_PRICE
    fists += Weapons.FIST_PACK
    return true


func start_ammo() -> int:
    return Weapons.START_AMMO + ammo_level
