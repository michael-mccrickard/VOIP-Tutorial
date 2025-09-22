extends Button

func _ready():
		_update_text(AudioManager.is_talk_mode())

func _pressed():
		var is_talking = AudioManager.toggle_talk_mode()
		_update_text(is_talking)

func _update_text(is_talking: bool):
		if is_talking:
				text = "Talking"
		else:
				text = "Talk"
