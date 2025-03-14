extends Node

#@onready var input : AudioStreamPlayer 
var input : AudioStreamPlayer
var output : AudioStreamPlayer2D
var index : int
var effect : AudioEffectCapture
var playback
#@export var outputPath : NodePath
var inputThreshold = 0.005
var receiveBuffer := PackedFloat32Array()

var audioIsReady = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func setupAudio(id):
	#input = $Input
	input = AudioStreamPlayer.new()
	set_multiplayer_authority(id)
	if is_multiplayer_authority():
		input.stream = AudioStreamMicrophone.new()
		input.name = "NewInput"
		input.bus = "Record"
		input.autoplay = true
		input.play()
		index = AudioServer.get_bus_index("Record")
		effect = AudioServer.get_bus_effect(index, 0)
		add_child(input)
		
		output = AudioStreamPlayer2D.new()
		output.stream = AudioStreamGenerator.new()
		output.bus = "Master"
		output.autoplay = true
		add_child(output)
		output.play()
		playback = output.get_stream_playback()
	
	#print(outputPath)
	#playback = get_node(outputPath).get_stream_playback()
	audioIsReady = true
	print("chilling")
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if !audioIsReady: return
	
	if is_multiplayer_authority():
		processMic()
	processVoice()
	pass

func processMic():
	var sterioData : PackedVector2Array = effect.get_buffer(effect.get_frames_available())
	
	if sterioData.size() > 0:
		
		var data = PackedFloat32Array()
		data.resize(sterioData.size())
		var maxAmplitude := 0.0
		
		for i in range(sterioData.size()):
			var value = (sterioData[i].x + sterioData[i].y) / 2
			maxAmplitude = max(value, maxAmplitude)
			data[i] = value
		if maxAmplitude < inputThreshold:
			return
		#print("sending data from " + str(multiplayer.get_unique_id()))
		sendData.rpc(data)
		#sendData(data)
		

func processVoice():
	if receiveBuffer.size() <= 0:
		return
	#print("getting data addressed to " + str(multiplayer.get_unique_id()))
	for i in range(min(playback.get_frames_available(), receiveBuffer.size())):
		playback.push_frame(Vector2(receiveBuffer[0], receiveBuffer[0]))
		receiveBuffer.remove_at(0)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func sendData(data : PackedFloat32Array):
	receiveBuffer.append_array(data)
