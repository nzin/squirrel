class_name Cfg
extends RefCounted
## Global tuning constants (ported 1:1 from the pygame version).
## Coordinates are screen pixels, origin top-left, y grows downward.

const SCREEN_W := 800
const SCREEN_H := 600
const SOIL_HEIGHT := 100
const SOIL_Y := SCREEN_H - SOIL_HEIGHT  # 500: top of the ground strip

const GRAVITY := 0.8
const JUMP_STRENGTH := -15.0
const SCROLL_SPEED := 3.0  # world scroll in px per physics tick (60/s)
const MAX_JUMP_HEIGHT := 15.0 * 15.0 / (2.0 * 0.8)  # ~140 px

const SPAWN_X := SCREEN_W + 50  # everything spawns just off the right edge

const CLOUD_ROWS := [150.0, 250.0]
const CLOUD_SPACING := 70.0

const ASSET_DIR := "res://assets/"


static func tex(file: String) -> Texture2D:
    # load() caches resources, so repeated spawns never hit the disk again
    return load(ASSET_DIR + file)
