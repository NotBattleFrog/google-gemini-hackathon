# Turn-Based System Documentation

## Overview

The game now uses a **turn-based system** where:
- Each character takes one action per turn in a fixed order
- Actions are determined by the character's goals, knowledge, fear, and composure
- The LLM generates what each character says/thinks based on these factors
- After each round (all characters act), the ghost player can take an action
- Turn limit is configurable (default: 2 turns)

## Character Goals

**Character goals are defined in `Scripts/Managers/TurnBasedGameState.gd`** in the `character_goals` dictionary (lines 10-30).

### Current Goals:

1. **UNIT-7 (Detective)**: Solve the murder while maintaining composure, but fear grows as evidence points toward them
2. **Madam Vanna**: Steal Source Code before discovery, panicked and desperate
3. **Dr. Aris**: Clean Neural Logs to cover involvement, cold fury while destroying evidence
4. **Lila**: Find mother's Digital Mind, grieving with low composure and high fear

### How to Modify Goals:

Edit the `character_goals` dictionary in `TurnBasedGameState.gd`:

```gdscript
var character_goals: Dictionary = {
	"UNIT-7": """Your goal text here...""",
	"Madam Vanna": """Your goal text here...""",
	# etc.
}
```

The goal text should be a detailed description of what the character wants to achieve, their motivations, and how they should behave.

## Character State

Each character maintains:

1. **Goal** (String): Their primary objective (from `character_goals`)
2. **Knowledge** (Array[String]): Facts they've learned
3. **Fear** (float 0.0-1.0): How scared they are (0.0 = calm, 1.0 = terrified)
4. **Composure** (float 0.0-1.0): How well they're holding together (0.0 = breaking down, 1.0 = perfectly calm)

These are stored in the `Soul` component and updated by the LLM after each action.

## Turn Flow

1. **Turn Start**: `TurnBasedGameState` selects next character in fixed order
2. **Action Generation**: LLM is prompted with character's state (goal, knowledge, fear, composure)
3. **LLM Response**: Returns JSON with:
   - `action_type`: "speech", "thought", or "whisper"
   - `text`: What they say/think
   - `visibility`: "public" or "private"
   - `target`: Character name (if whisper/directed)
   - `state_changes`: Fear/composure deltas and new knowledge
   - `knowledge_updates`: What each character learns from this action
4. **State Update**: Character's fear/composure/knowledge updated
5. **Visibility**: Other characters observe based on visibility rules
6. **Next Character**: Process repeats until all characters act
7. **Ghost Turn**: Player can input an action to influence a character
8. **Next Round**: Repeat until turn limit reached

## Action Visibility System

Actions can be:
- **Public**: Everyone hears the full content
- **Private/Whisper**: Only target hears content, others see "[Actor whispers to Target]"

The LLM determines visibility based on the character's goals and situation. The system automatically:
- Updates knowledge for characters who heard the action
- Updates knowledge for characters who only observed whispering
- Applies state changes (fear/composure) to the acting character

## Ghost Actions

After each round, the ghost player can:
1. Enter text describing their action
2. Select a target character (or "All Characters" for public)
3. Submit the action

The action is added to the target character's knowledge and influences their next turn.

## Configuration

### Turn Limit

Set in `TurnBasedGameState.gd`:
```gdscript
@export var max_turns: int = 2  # Change this value
```

### Turn Order

Fixed order is set in `_initialize_turn_order()`:
1. Detective (first unit)
2. Suspects (remaining units in order)

## LLM Prompt Structure

The LLM receives a prompt containing:
- Character's goal
- Current knowledge list
- Fear and composure levels
- Other characters' recent actions
- Instructions to generate action with state changes

The LLM must respond with JSON including:
- Action details (type, text, visibility)
- State changes (fear_delta, composure_delta, new_knowledge)
- Knowledge updates for each character

## Files Modified

- `Scripts/Managers/TurnBasedGameState.gd` - Main turn controller
- `Scripts/Components/Soul.gd` - Added turn-based state management
- `Scripts/Units/Unit.gd` - Added thought/whisper display methods
- `Scripts/Managers/LLMController.gd` - Added turn action handling
- `Scripts/Managers/GlobalSignalBus.gd` - Added turn-based signals
- `Scripts/UI/GhostActionInput.gd` - Ghost action input UI
- `Scenes/UI/GhostActionInput.tscn` - UI scene
- `Scripts/Game.gd` - Updated to use TurnBasedGameState

## Example Goal Definition

```gdscript
"Madam Vanna": """You are Madam Vanna, a tech tycoon. Your goal is to steal the Source Code from the neural link system before anyone discovers your plan. You are panicked and desperate because Somchai's death clause funding depends on you getting that code. You must maintain composure in front of others while secretly working toward your goal. Your fear increases as the investigation progresses."""
```

This goal text is used directly in the LLM prompt, so be detailed and specific about:
- What the character wants
- How they should behave
- What affects their fear/composure
- How they interact with others
