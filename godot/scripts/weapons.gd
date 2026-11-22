class_name Weapons
extends RefCounted
## Weapon catalogue + upgrade prices. Purely data: how a weapon behaves lives in
## Shot (flight) and Game.do_throw (what gets fired). Add a weapon by adding an
## entry here, a branch in Game.do_throw and a branch in Shot.setup/_draw.
##   price - coins in the shop       ammo - acorns spent per throw

const ORDER: Array[String] = ["acorn", "spread", "boomerang", "chestnut", "pinecone", "rainbow", "homing"]

const DEFS := {
    "acorn": {"name": "Acorn", "price": 0, "ammo": 1,
        "desc": "Straight shot. Cheap and reliable."},
    "spread": {"name": "Triple Acorn", "price": 15, "ammo": 3,
        "desc": "Three acorns in a fan."},
    "boomerang": {"name": "Boomerang", "price": 30, "ammo": 1,
        "desc": "Flies out and back: can hit twice."},
    "chestnut": {"name": "Bouncing Chestnut", "price": 50, "ammo": 1,
        "desc": "Arcs and bounces along the ground."},
    "pinecone": {"name": "Pinecone Bomb", "price": 80, "ammo": 2,
        "desc": "Slow lob that explodes: area damage."},
    "rainbow": {"name": "Rainbow Beam", "price": 120, "ammo": 3,
        "desc": "Fast, hits hard, pierces every enemy in line."},
    "homing": {"name": "Homing Acorn", "price": 180, "ammo": 2,
        "desc": "Steers toward the nearest enemy."},
}

const START_AMMO := 3
## Price of each "+1 starting acorn" level; its length is the maximum level.
const AMMO_UPGRADE_PRICES: Array[int] = [10, 25, 45, 70, 100]
