extends Node
## Registers every keyboard action in code, so all bindings live in one readable table.
## Touch controls do not use these; they feed the same PlayerCommand directly.

const BINDINGS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"ability": [KEY_Q],
	"ultimate": [KEY_E],
	"drop_relay": [KEY_F],
	"show_deck": [KEY_TAB],
	"buy_1": [KEY_1],
	"buy_2": [KEY_2],
	"buy_3": [KEY_3],
	"buy_4": [KEY_4],
	"buy_5": [KEY_5],
	"buy_6": [KEY_6],
	"toggle_debug": [KEY_F1],
	"toggle_seat": [KEY_F2],
	"toggle_touch": [KEY_F3],
	"back": [KEY_ESCAPE],
}


func _enter_tree() -> void:
	register()


static func register() -> void:
	for action: String in BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for key: Key in BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
