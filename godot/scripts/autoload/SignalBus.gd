extends Node

signal scene_changed(scene_name: String)
signal player_health_changed(current: int, maximum: int)
signal player_stamina_changed(current: float, maximum: float)
signal player_mana_changed(current: float, maximum: float)
signal player_xp_changed(xp: int, xp_needed: int, level: int)
signal player_level_up(level: int)
signal player_skill_cooldown(id: String, cur: float, max: float)  # cur==max on ready/unlock flash
signal player_died()
signal enemy_died(enemy_id: int)
signal enemy_damaged(enemy_id: int, amount: int)
signal dialogue_started(speaker: String, lines: Array)
signal dialogue_ended()
signal item_picked_up(item_id: String)
signal hud_message(text: String, duration: float)
signal screen_shake(trauma: float)
