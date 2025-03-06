extends Node

@onready var input : AudioStreamPlayer 
var index : int
var effect : AudioEffectCapture
var playback : AudioStreamGeneratorPlayback
@export var outputPath : NodePath
var inputThreshold = 0.005
var receiveBuffer := PackedFloat32Array()


var micOn = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.
	

func setupAudio(id):
	input = $Input
	set_multiplayer_authority(id)
	if is_multiplayer_authority():
		print("setting up audio")
		input.stream = AudioStreamMicrophone.new()
		input.play()
		index = AudioServer.get_bus_index("Record")
		effect = AudioServer.get_bus_effect(index, 0)

	playback = get_node(outputPath).get_stream_playback()
	print("playback is " + str(playback))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if is_multiplayer_authority():
		print("mpa " + str(multiplayer.get_unique_id()))
		print(str(micOn)  + str(multiplayer.get_unique_id()))
		if (micOn == true):
			
			processMic()
		processVoice()
	

func processMic():
	var sterioData : PackedVector2Array = effect.get_buffer(effect.get_frames_available())
	
	if sterioData.size() > 0:
		
		print(str(sterioData.size()))
		
		var data = PackedFloat32Array()
		data.resize(sterioData.size())
		var maxAmplitude := 0.0
		
		for i in range(sterioData.size()):
			var value = (sterioData[i].x + sterioData[i].y) / 2
			maxAmplitude = max(value, maxAmplitude)
			data[i] = value
		if maxAmplitude < inputThreshold:
			return
		print("sending data from " + str(multiplayer.get_unique_id()))
		sendData.rpc(data)
		#sendData(data)
		

func processVoice():
	if receiveBuffer.size() <= 0:
		return
	print("getting data addressed to " + str(multiplayer.get_unique_id()))
	for i in range(min(playback.get_frames_available(), receiveBuffer.size())):
		playback.push_frame(Vector2(receiveBuffer[0], receiveBuffer[0]))
		receiveBuffer.remove_at(0)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func sendData(data : PackedFloat32Array):
	receiveBuffer.append_array(data)


func doBusMute(which : bool):
	
	index = AudioServer.get_bus_index("Record")
	AudioServer.set_bus_mute(index, which)
		

func _on_button_talk_pressed() -> void:
	micOn = !micOn
	
	var btn = $ButtonTalk
	
	if (micOn):
		set_button_font_color(btn, Color.GREEN)
		doBusMute(false)
	else:
		set_button_font_color(btn, Color.YELLOW)
		doBusMute(true)
		
	print("mic on at the end of talk buttton pressed = " + str(micOn))

func set_button_font_color(button: Control, color: Color):
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)
	button.add_theme_color_override("font_focus_color", color)
