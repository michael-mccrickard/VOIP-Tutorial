extends Node2D

@onready var button_host = $Server/Host

func _ready():
	print("Running as dedicated_server:", OS.has_feature("dedicated_server"))
	
	var is_server := OS.has_feature("dedicated_server") or "--server" in OS.get_cmdline_args()
	if is_server:
		button_host.visible = false
		$Client.queue_free()
		if "--server" in OS.get_cmdline_args():
			$AudioManager.setupAudio(1)
	
	else:
		$Server.queue_free()
