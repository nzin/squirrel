class_name AudioHub
extends Node
## All the game's sound in one place:
##  - music: one looping track at a time, crossfaded when the situation changes
##  - effects: a small pool of players, a touch of random pitch so repeats differ
##  - the shopkeeper's speech blips
##  - slow motion: the music slows down and gets muffled while the world does
##  - two volume sliders (Music / Effects) that the pause menu controls
## Sounds are looked up by file name in assets/audio/{sfx,music}/ (.ogg first, then
## .wav), so a sound can be replaced just by dropping in a file with the same name.
## A sound that has no file is silently skipped.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const EXTENSIONS := ["ogg", "wav"]  # an .ogg overrides the synthesized .wav of the same name
const POOL_SIZE := 14
const CROSSFADE := 0.9      # seconds
const LOOPING := ["run_a", "run_b", "run_c", "boss", "shop"]
## The files are all normalised to the same peak; this sets how loud each one
## really is (dB, 0 = full).
const LEVELS_DB := {
    "ui_move": -16.0, "ui_select": -11.0, "ui_back": -11.0, "pause": -9.0, "land": -9.0,
    "hit": -5.0, "coin": -6.0, "box_bump": -6.0, "warn": -10.0, "no_money": -9.0,
    "dwarf_blip": -13.0, "dwarf_laugh": -8.0, "throw_acorn": -7.0, "throw_spread": -7.0,
    "throw_boomerang": -8.0, "throw_chestnut": -9.0, "throw_pinecone": -6.0, "throw_harpoon": -8.0,
    "throw_homing": -8.0, "jump": -8.0, "splat": -8.0, "mole_pop": -6.0, "stomp": -4.0,
    "dive": -8.0, "pounce": -8.0, "roll": -6.0, "hiss": -8.0, "fireball": -5.0, "whoosh": -6.0,
    "smash": -5.0, "shield_clang": -4.0, "enemy_defeat": -4.0, "rainbow_collect": -5.0,
    "life_lost": -4.0, "respawn": -6.0, "fade": -12.0, "shop_bell": -5.0, "buy": -4.0,
    "oneup": -3.0, "run_complete": -3.0, "boss_defeated": -2.0, "game_over": -3.0,
    "fist_start": -2.0, "fist_dash": -5.0, "fist_hit": -2.0, "fist_turn": -2.0, "fist_end": -5.0,
    "boom": -2.0, "boss_roar": -1.0,
}
const MUSIC_BASE_DB := -7.0  # music sits under the effects

var music_volume := 0.7      # 0..1 (the slider)
var sfx_volume := 0.8
var current_music := ""
var played: Array[String] = []     # recent effects, for the tests

var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _music: Array[AudioStreamPlayer] = []   # two players, for crossfading
var _gain: Array[float] = [0.0, 0.0]        # linear fade level of each music player
var _target: Array[float] = [0.0, 0.0]
var _active_music := 0
var _streams := {}
var _lowpass: AudioEffectLowPassFilter
var _world_speed := 1.0
var _muffled := false
var _speak_left := 0
var _speak_timer := 0.0
var _speak_index := 0


func _ready() -> void:
    _ensure_bus("Music")
    _ensure_bus("SFX")
    var music_bus := AudioServer.get_bus_index("Music")
    _lowpass = AudioEffectLowPassFilter.new()
    _lowpass.cutoff_hz = 20500.0
    AudioServer.add_bus_effect(music_bus, _lowpass)
    for i in 2:
        var p := AudioStreamPlayer.new()
        p.bus = "Music"
        p.volume_db = -80.0
        add_child(p)
        _music.append(p)
    for i in POOL_SIZE:
        var p := AudioStreamPlayer.new()
        p.bus = "SFX"
        add_child(p)
        _players.append(p)
    set_music_volume(music_volume)
    set_sfx_volume(sfx_volume)


func _ensure_bus(bus_name: String) -> void:
    if AudioServer.get_bus_index(bus_name) == -1:
        AudioServer.add_bus()
        var idx := AudioServer.bus_count - 1
        AudioServer.set_bus_name(idx, bus_name)
        AudioServer.set_bus_send(idx, "Master")


func set_music_volume(v: float) -> void:
    music_volume = clampf(v, 0.0, 1.0)
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), _volume_db(music_volume) + MUSIC_BASE_DB)


func set_sfx_volume(v: float) -> void:
    sfx_volume = clampf(v, 0.0, 1.0)
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), _volume_db(sfx_volume))


static func _volume_db(v: float) -> float:
    return -80.0 if v <= 0.001 else linear_to_db(v)


# ---------------------------------------------------------------- effects

func _load_stream(folder: String, sound: String) -> AudioStream:
    var key := folder + sound
    if _streams.has(key):
        return _streams[key]
    var stream: AudioStream = null
    for ext: String in EXTENSIONS:
        var path := "%s%s.%s" % [folder, sound, ext]
        if ResourceLoader.exists(path):
            stream = load(path)
            break
    if stream is AudioStreamWAV and folder == MUSIC_DIR and LOOPING.has(sound):
        var wav := (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
        wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
        wav.loop_begin = 0
        wav.loop_end = int(wav.get_length() * wav.mix_rate)
        stream = wav
    _streams[key] = stream
    return stream


## The stream of an effect. The long jingles (game over, boss defeated) live with
## the music files, so look there too.
func sfx_stream(sound: String) -> AudioStream:
    var stream := _load_stream(SFX_DIR, sound)
    return stream if stream != null else _load_stream(MUSIC_DIR, sound)


## Play an effect. `variation` randomises the pitch a little (0 = never).
func sfx(sound: String, variation := 0.06, extra_db := 0.0) -> void:
    played.append(sound)
    if played.size() > 80:
        played.pop_front()
    var stream := sfx_stream(sound)
    if stream == null:
        return
    var p := _players[_next_player]
    _next_player = (_next_player + 1) % _players.size()
    p.stream = stream
    p.volume_db = LEVELS_DB.get(sound, 0.0) + extra_db
    var slow := lerpf(0.78, 1.0, clampf((_world_speed - 0.1) / 0.9, 0.0, 1.0))  # sounds drop in pitch in slow motion
    p.pitch_scale = slow * (1.0 + randf_range(-variation, variation))
    p.play()


## Did `sound` play recently? (for the tests)
func heard(sound: String) -> bool:
    return played.has(sound)


# ---------------------------------------------------------------- the shopkeeper talks

## A burst of short blips, a little higher or lower each time (like a muttering voice).
func speak(text: String) -> void:
    _speak_left = clampi(text.length() / 3, 3, 14)
    _speak_index = 0
    _speak_timer = 0.0


# ---------------------------------------------------------------- music

func play_music(track: String) -> void:
    if track == current_music:
        return
    current_music = track
    var old := _active_music
    _target[old] = 0.0
    if track == "":
        return
    var stream := _load_stream(MUSIC_DIR, track)
    if stream == null:
        return
    _active_music = 1 - old
    var p := _music[_active_music]
    p.stream = stream
    _gain[_active_music] = 0.0
    _target[_active_music] = 1.0
    p.volume_db = -80.0
    p.play()


## Called every frame with the game's time scale: in Matrix slow motion the music
## slows down and loses its high end.
func set_world_speed(ts: float) -> void:
    _world_speed = ts
    _apply_filters()


func set_muffled(on: bool) -> void:
    _muffled = on
    _apply_filters()


func _apply_filters() -> void:
    var k := clampf((_world_speed - 0.1) / 0.9, 0.0, 1.0)
    var cutoff := lerpf(650.0, 20500.0, k * k)
    if _muffled:
        cutoff = minf(cutoff, 900.0)
    _lowpass.cutoff_hz = cutoff
    for p in _music:
        p.pitch_scale = lerpf(0.62, 1.0, k)


func _process(delta: float) -> void:
    for i in 2:
        if _gain[i] != _target[i]:
            _gain[i] = move_toward(_gain[i], _target[i], delta / CROSSFADE)
            _music[i].volume_db = _volume_db(_gain[i])
            if _gain[i] <= 0.0 and _target[i] <= 0.0:
                _music[i].stop()
    if _speak_left > 0:
        _speak_timer -= delta
        if _speak_timer <= 0.0:
            _speak_timer = 0.075
            _speak_left -= 1
            _speak_index += 1
            var pitch := 0.85 + float((_speak_index * 7) % 9) * 0.08
            sfx("dwarf_blip", 0.0, 0.0)
            _players[(_next_player + _players.size() - 1) % _players.size()].pitch_scale = pitch
