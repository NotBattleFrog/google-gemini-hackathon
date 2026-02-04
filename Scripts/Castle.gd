extends Area2D

@export var max_hp: int = 100
var current_hp: int

func _ready() -> void:
    current_hp = max_hp
    # Sync with SaveManager if loading, but for now simple init
    if SaveManager.current_state.has("castle_hp"):
         current_hp = SaveManager.current_state["castle_hp"]

func take_damage(amount: int) -> void:
    current_hp -= amount
    SaveManager.current_state["castle_hp"] = current_hp
    # Update UI (We might need a signal in GlobalSignalBus for this properly, but direct access for now is okay for prototype)
    # Ideally: GlobalSignalBus.emit_signal("castle_hp_changed", current_hp)
    # But since we didn't define that, let's rely on polling or add it.
    
    # Check Game Over
    if current_hp <= 0:
        GlobalSignalBus.game_over.emit()
        print("Castle Destroyed!")
