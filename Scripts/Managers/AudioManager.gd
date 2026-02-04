extends Node

# Audio Layout
# - MusicPlayer (StreamPlayer)
# - SFXPlayers (Pool of StreamPlayers)

var music_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE = 10

func _ready() -> void:
    # Setup Music
    music_player = AudioStreamPlayer.new()
    music_player.bus = "Music"
    add_child(music_player)
    
    # Setup SFX Pool
    for i in range(SFX_POOL_SIZE):
        var p = AudioStreamPlayer.new()
        p.bus = "SFX"
        add_child(p)
        sfx_pool.append(p)

    process_mode = Node.PROCESS_MODE_ALWAYS

func play_sfx(stream: AudioStream, pitch_scale: float = 1.0) -> void:
    if not stream: return
    
    # Find free player
    var player = _get_free_sfx_player()
    if player:
        player.stream = stream
        player.pitch_scale = pitch_scale
        player.play()

func change_music(stream: AudioStream, fade_time: float = 1.0) -> void:
    if music_player.stream == stream:
        return
        
    # Quick fade out/in logic (placeholder)
    music_player.stop()
    music_player.stream = stream
    music_player.play()

func _get_free_sfx_player() -> AudioStreamPlayer:
    for p in sfx_pool:
        if not p.playing:
            return p
    return sfx_pool[0] # Aggressively steal oldest if full (simplified)
