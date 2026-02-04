extends SceneTree

func _init():
    print("Starting Phase 1 Verification...")
    
    # 1. Test ConfigManager
    print("Testing ConfigManager...")
    var test_key = "test_api_key_123"
    ConfigManager.save_api_key(test_key)
    if ConfigManager.api_key == test_key:
        print("[PASS] save_api_key")
    else:
        print("[FAIL] save_api_key. Expected %s, got %s" % [test_key, ConfigManager.api_key])
        
    # reload to test persistence logic (though we can't fully restart the engine here)
    ConfigManager.load_config()
    if ConfigManager.api_key == test_key:
        print("[PASS] load_config (Persistence)")
    else:
        print("[FAIL] load_config. Expected %s, got %s" % [test_key, ConfigManager.api_key])

    # 2. Test SaveManager
    print("Testing SaveManager...")
    SaveManager.current_state["gold"] = 999
    SaveManager.save_game()
    
    # Modify state to verify load restores it
    SaveManager.current_state["gold"] = 0
    if SaveManager.load_game():
        if SaveManager.current_state["gold"] == 999:
            print("[PASS] Save/Load Game")
        else:
            print("[FAIL] Load Game: Gold mismatch. Expected 999, got %s" % SaveManager.current_state["gold"])
    else:
        print("[FAIL] Load Game: Failed to load.")

    # 3. Test LLMController (Initialization)
    # We cannot easily test the async HTTP request in this short script without a main loop yielding
    # But we can check if it exists
    if LLMController.http_request:
        print("[PASS] LLMController initialized")
    else:
        print("[FAIL] LLMController http_request missing")

    print("Verification Script Finished. Quitting.")
    quit()
