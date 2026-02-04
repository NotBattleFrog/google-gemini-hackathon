extends TextureRect

func _ready() -> void:
    # Set pivot to center for rotation
    pivot_offset = size / 2
    # Connect to signal
    GlobalSignalBus.time_changed.connect(_on_time_changed)

func _on_time_changed(cycle_pos: float) -> void:
    # Rotate 360 degrees over the day
    # Assuming the texture has Sun at top at 0 rotation?
    # Actually, let's say Sun is top (Noon) at cycle_pos 0.0??
    # Wait, Game.gd logic:
    # 0.0 - 0.2 is Night -> Dawn. 0.0 is Midnight?
    # Logic in Game.gd:
    # cycle_pos < 0.2 or > 0.8 is NIGHT.
    # So 0.0 is MIDNIGHT.
    # 0.5 is NOON.
    
    # We want Sun to be visible at NOON (0.5).
    # If texture has Sun Up at 0 deg, then at Noon (0.5) we want 0 deg?
    # Let's assume standard dial:
    # Rot = (cycle_pos + 0.5) * 360  (So at 0.0 (midnight), rot is 180 (upside down/Moon up?))
    # Let's inspect the generated image first to know orientation.
    # Usually Sun/Moon are opposite.
    # Let's just rotate -360 * cycle_pos and calibrate offset visually.
    
    rotation_degrees = (cycle_pos * 360.0) - 180 # Start at bottom (Midnight)?
