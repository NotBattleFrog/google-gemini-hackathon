# Cyber Noir - Game Documentation

## Overview

**Cyber Noir** is a murder mystery simulation game built in Godot 4.5. The player takes on the role of Somchai, a ghost who was murdered by a Neural Link overload. The game features AI-powered NPCs that engage in dynamic conversations, with the player able to influence conversations as a ghost.

## Game Mechanics

### Core Concept

- **Player Role**: You play as Somchai, a ghost who can observe and influence conversations between suspects
- **Mystery Setup**: A detective (UNIT-7, an AI) investigates your murder with 3 suspects
- **Conversation System**: NPCs autonomously engage in conversations, and you can interrupt every 5 conversations to whisper messages to specific characters
- **AI-Powered Dialogue**: All conversations are generated using Google Gemini API

### Characters

1. **UNIT-7 (Detective)**: A logical AI detective who believes they are innocent, but is actually the killer (memory erased)
2. **Madam Vanna**: Tech Tycoon - Calculating, panicked desperation. Secret: Trying to steal Source Code
3. **Dr. Aris**: Bio-Engineer - Cold fury, analyzing logs. Secret: Trying to clean Neural Logs
4. **Lila**: Estranged Daughter - Grief, weeping. Secret: Searching for Mother's Digital Mind

### Game Flow

1. **Conversation Phase**: NPCs engage in conversations automatically (5 conversations per cycle)
2. **Ghost Turn**: After 5 conversations, you can whisper a message to any suspect or the detective
3. **Influence**: Your whispers affect how characters behave in subsequent conversations
4. **Investigation**: The detective and suspects reveal clues through their conversations

## Understanding the Logs

### Partner Finding Logs

When you see logs like:
```
Unit @CharacterBody2D@39 found potential partner Unit.
Partner Unit is busy or on cooldown.
```

**What this means:**
- Units periodically check for nearby conversation partners (every 5 seconds)
- When a unit finds a potential partner, it checks if that partner is available
- If the partner is on cooldown (15 seconds after their last conversation), they're "busy"
- This is **normal behavior** - units are trying to socialize but respecting cooldown timers
- The cooldown prevents spam conversations and makes interactions feel more natural

**Cooldown System:**
- Each unit has a 15-second cooldown after each conversation (`COOLDOWN_TIME` in `Soul.gd`)
- Units can only have 2 unique conversation partners per day
- Maximum 3 conversations per partner per day
- These limits prevent conversation spam and create more meaningful interactions

### Mystery Manager Error

If you see:
```
[MysteryManager] WARNING: Not enough units found! Needs 4 (1 Detective + 3 Suspects). Found: 0
```

**What this means:**
- The MysteryManager is trying to set up the mystery scene but can't find enough units
- This happens when units haven't been spawned yet or aren't in the "Units" group
- **Fix**: The timing issue has been addressed - MysteryManager now waits for units to spawn

## API Key Configuration

### Where to Set API Key

The API key is stored in `user://settings.cfg` via the `ConfigManager`. There are two ways to set it:

1. **In-Game Settings** (Recommended): 
   - Press a key (default: `K`) to open the API Key settings panel
   - Enter your Google Gemini API key
   - Click "Save Key"

2. **Manual Configuration**:
   - The config file is located at: `user://settings.cfg`
   - Format: `[auth]` section with `api_key=YOUR_KEY_HERE`

### Getting a Google Gemini API Key

1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Create a new API key
4. Copy the key and paste it into the game's settings

### API Key Usage

The API key is used by `LLMStreamService` to:
- Generate dynamic dialogue between NPCs
- Create conversation summaries
- Process relationship updates
- Generate ghost influence effects

## File Structure

```
google-gemini-hackathon/
├── Scenes/
│   ├── Game.tscn              # Main game scene
│   ├── MainMenu.tscn           # Start menu (can be bypassed)
│   ├── Unit.tscn               # NPC unit scene
│   ├── Player.tscn             # Player ghost scene
│   └── UI/
│       ├── GameUI.tscn         # Main game UI
│       ├── GhostUI.tscn        # Ghost turn interface
│       └── DialogueBubble.tscn # Speech bubbles
├── Scripts/
│   ├── Game.gd                 # Main game controller
│   ├── Managers/
│   │   ├── MysteryManager.gd   # Manages mystery flow
│   │   ├── ConfigManager.gd    # Handles API key storage
│   │   ├── LLMController.gd    # Coordinates LLM requests
│   │   └── LoreManager.gd      # Tracks game events
│   ├── Services/
│   │   └── LLMStreamService.gd  # Handles Gemini API streaming
│   ├── Units/
│   │   └── Unit.gd             # NPC behavior and AI
│   ├── Components/
│   │   └── Soul.gd              # Personality and conversation logic
│   └── UI/
│       ├── GameUI.gd            # Main UI controller
│       └── GhostUI.gd           # Ghost turn UI
└── project.godot               # Godot project configuration
```

## Key Systems

### Socialization System

**Location**: `Scripts/Units/Unit.gd` and `Scripts/Components/Soul.gd`

- Units detect nearby units within 300 pixels
- Every 5 seconds, units check for available conversation partners
- Partners must be:
  - In IDLE state
  - Not on cooldown (15 seconds)
  - Within conversation limits (2 partners/day, 3 conversations/partner)

### Conversation Generation

**Location**: `Scripts/Components/Soul.gd` → `_construct_social_prompt()`

- Each conversation includes:
  - Character personalities and traits
  - Relationship history
  - Hidden secrets (for suspects)
  - Ghost influence (if applicable)
- LLM generates 2-line dialogues in JSON format
- Conversations are saved and used to build relationship summaries

### Mystery Management

**Location**: `Scripts/Managers/MysteryManager.gd`

- Manages conversation queue (10 random pairings)
- Tracks conversation count
- Triggers ghost turn every 5 conversations
- Assigns roles to units (Detective + 3 Suspects)
- Applies ghost influence to conversations

### LLM Streaming

**Location**: `Scripts/Services/LLMStreamService.gd`

- Connects to Google Gemini API
- Streams responses in real-time
- Supports two modes:
  - `CHAT`: Text responses for dialogue
  - `LOGIC`: JSON responses for game logic
- Handles context window management

## Troubleshooting

### Units Not Socializing

- Check if API key is set (look for "[LLM DEBUG] Error: No API Key" in console)
- Verify units are in the "Units" group
- Check cooldown timers (units can't socialize during 15-second cooldown)
- Ensure units are in IDLE state (not in COMBAT, MUTINY, etc.)

### API Errors

- Verify API key is valid and has quota remaining
- Check internet connection
- Look for error messages in console starting with "[LLM DEBUG]"
- Ensure `LLMStreamService` is loaded as an autoload singleton

### Mystery Not Starting

- Ensure exactly 4 units are spawned (1 detective + 3 suspects)
- Check that units are added to "Units" group
- Verify MysteryManager is added to the scene tree
- Check console for timing issues

## Development Notes

### Autoload Singletons

The following singletons are loaded automatically:
- `GlobalSignalBus`: Event system
- `ConfigManager`: Configuration storage
- `LLMController`: LLM request coordinator
- `LLMStreamService`: API communication
- `LoreManager`: Event tracking
- `AudioManager`: Sound system
- `GameStateTracker`: State tracking
- `PetitionManager`: Petition system (legacy)

### State Management

- Conversation summaries are saved to `user://npc_conversations/`
- API key is stored in `user://settings.cfg`

## Future Improvements

- Better error handling for API failures
- Conversation history viewer
- Save/load game state
- More complex mystery scenarios
- Visual indicators for cooldowns
- Relationship visualization
