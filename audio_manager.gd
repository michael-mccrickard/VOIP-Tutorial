extends Node

#@onready var input : AudioStreamPlayer
var input : AudioStreamPlayer
var output : AudioStreamPlayer2D
var index : int
var effect : AudioEffectCapture
var playback
# Identifier for the remote peer we are communicating with.
var partner_id : int = 0
# Push-to-talk mode flag.
var talk_mode := false
#@export var outputPath : NodePath
var inputThreshold = 0.005
var receiveBuffer := PackedFloat32Array()
var audioIsReady = false
var mix_rate = 48000

const AUDIO_PACKET_SAMPLES = 128 # 128 samples * 4 bytes = 512 bytes (well below MTU)
const MU = 255.0

# --- μ-law encode/decode functions ---
# Encode a float [-1, 1] to an 8-bit μ-law value (0-255)
func mulaw_encode(sample: float) -> int:
	# Clamp to [-1, 1]
	sample = clamp(sample, -1.0, 1.0)
	# μ-law compression
	var sign := 0 if sample >= 0 else 1
	var abs_sample = abs(sample)
	var mu_encoded := log(1 + MU * abs_sample) / log(1 + MU)
	mu_encoded = int((sign << 7) | int(mu_encoded * 127.0))
	return mu_encoded

# Decode an 8-bit μ-law value (0-255) to float [-1, 1]
func mulaw_decode(mu_val: int) -> float:
	var sign := -1.0 if (mu_val & 0x80) else 1.0
	mu_val = mu_val & 0x7F
	var decoded := (1.0 / MU) * ((1 + MU) ** (mu_val / 127.0) - 1)
	return sign * decoded

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
		output.stream.mix_rate = mix_rate
		output.bus = "Master"
		output.autoplay = true
		add_child(output)
		output.play()
		playback = output.get_stream_playback()

	audioIsReady = true
	print("chilling")

# Store the id of the remote peer that audio should be sent to.
func set_partner_id(id: int):
	partner_id = id

# Clear the stored remote peer id.
func clear_partner_id():
	partner_id = 0

# Toggle push-to-talk mode and return the new state.
func toggle_talk_mode() -> bool:
	talk_mode = !talk_mode
	return talk_mode

# Retrieve the current push-to-talk state.
func is_talk_mode() -> bool:
	return talk_mode

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if !audioIsReady:
		return

	if talk_mode:
		processMic2()
	processVoice()
	pass

func processMic():
	if effect == null:
		return
	var frames_available := effect.get_frames_available()
	if frames_available <= 0:
		return
	var sterioData : PackedVector2Array = effect.get_buffer(frames_available)
	if !talk_mode or partner_id == 0:
		return

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
		# Instead, use μ-law encoding and chunking:
		var p = 0
		while p < data.size():
			var chunk_size = min(AUDIO_PACKET_SAMPLES, data.size() - p)
			var chunk = data.slice(p, p + chunk_size)
			var mu_chunk = PackedByteArray()
			for j in range(chunk.size()):
				mu_chunk.append(mulaw_encode(chunk[j]))
			sendData.rpc_id(partner_id, mu_chunk)
			p += chunk_size

func processVoice():
	if receiveBuffer.size() <= 0:
		return
	for i in range(min(playback.get_frames_available(), receiveBuffer.size())):
		playback.push_frame(Vector2(receiveBuffer[0], receiveBuffer[0]))
		receiveBuffer.remove_at(0)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func sendData(data : PackedByteArray):
	for i in data:
		receiveBuffer.append(mulaw_decode(i))

func processMic2():
	var sterioData : PackedVector2Array = effect.get_buffer(effect.get_frames_available())
	var data = PackedFloat32Array()
	
	if sterioData.size() > 0:
		data.resize(sterioData.size())
		var maxAmplitude := 0.0

		for i in range(sterioData.size()):
			var value = (sterioData[i].x + sterioData[i].y) / 2
			maxAmplitude = max(value, maxAmplitude)
			data[i] = value

		if maxAmplitude < inputThreshold:
			return

		# Chunk to μ-law!
		var p = 0
		while p < data.size():
			var chunk_size = min(AUDIO_PACKET_SAMPLES, data.size() - p)
			var chunk = data.slice(p, p + chunk_size)
			var mu_chunk = PackedByteArray()
			for j in range(chunk.size()):
				mu_chunk.append(mulaw_encode(chunk[j]))
			sendData.rpc_id(partner_id, mu_chunk)
			p += chunk_size
