extends Node

enum State { LOADING, EXPLORING, COMBAT, DIALOGUE, MENU, PAUSED }

var current_state: State
var health: int
var max_health: int
var stamina: float
var max_stamina: float
var level: int
var gold: int
var current_scene_name: String

func _ready() -> void:
	current_state = State.LOADING
	health = 100
	max_health = 100
	stamina = 50.0
	max_stamina = 50.0
	level = 1
	gold = 0

func change_state(new_state: State) -> void:
	current_state = new_state

func get_state() -> State:
	return current_state

func is_paused() -> bool:
	return current_state == State.PAUSED

func set_health(value: int) -> void:
	health = clamp(value, 0, max_health)
	SignalBus.player_health_changed.emit(health, max_health)

func set_stamina(value: float) -> void:
	stamina = clamp(value, 0.0, max_stamina)
	SignalBus.player_stamina_changed.emit(stamina, max_stamina)
