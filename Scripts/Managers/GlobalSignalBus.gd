extends Node

# Game State Signals
signal game_started
signal game_over
signal wave_ended
signal day_started
signal night_started
signal time_changed(cycle_pos: float)

# Chronicle/Lore signals
signal request_chronicle_generation(prompt: String)
signal chronicle_generated(response: Dictionary)

# Conversation Summary signals
signal request_summary_merge(soul: Node, partner_name: String, prompt: String)
signal summary_merged(soul: Node, partner_name: String, merged_summary: String)

# Quest/Petition signals
signal request_petition_generation(npc_soul: Node, prompt: String)
signal petition_received(npc_soul: Node, response: Dictionary)
signal petition_accepted(quest: Resource)
signal petition_rejected(quest: Resource)
signal day_changed(day: int)

signal gold_changed(new_amount: int)

# Persistence Signals
signal request_save
signal request_load

# LLM Signals
# LLM Signals
signal response_received(text: String)
signal request_social_interaction(soul_a: Node, soul_b: Node, prompt: String)
