class_name MusicManager
extends Node
## 音乐管理：优先加载 Kevin MacLeod 的 CC-BY 曲目；
## 若文件未放入项目，则回退到生成的小型循环音轨，保证可玩。

const MENU_PATH_MP3 := "res://assets/music/Funkorama.mp3"
const MENU_PATH_OGG := "res://assets/music/Funkorama.ogg"
const GAME_PATH_MP3 := "res://assets/music/Faster Does It.mp3"
const GAME_PATH_OGG := "res://assets/music/Faster Does It.ogg"

var _player: AudioStreamPlayer

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = -10.0
	add_child(_player)

func play_menu() -> void:
	var stream := _load_first([MENU_PATH_MP3, MENU_PATH_OGG])
	if stream == null:
		stream = _generate_placeholder("menu")
	if stream:
		_player.stream = stream
		_player.play()

func play_game() -> void:
	var stream := _load_first([GAME_PATH_MP3, GAME_PATH_OGG])
	if stream == null:
		stream = _generate_placeholder("game")
	if stream:
		_player.stream = stream
		_player.play()

func stop() -> void:
	_player.stop()

func _load_first(paths: Array[String]) -> AudioStream:
	for path in paths:
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is AudioStream:
				return res
	return null

func _generate_placeholder(kind: String) -> AudioStream:
	var sample_rate := 11025
	var seconds := 8.0
	var frame_count := int(sample_rate * seconds)
	var data := PackedByteArray()
	data.resize(frame_count * 2)
	var scale := [0, 3, 5, 7, 10, 12, 15, 17] if kind == "menu" else [0, 2, 4, 7, 9, 12, 14, 16]
	var bpm := 120.0 if kind == "menu" else 150.0
	var root := 110.0 if kind == "menu" else 130.0
	var semitone := 0.0
	for i in frame_count:
		var t := float(i) / sample_rate
		var beat := int(t * bpm / 60.0) % 8
		semitone = scale[beat]
		if int(t * bpm / 60.0) % 2 == 1:
			semitone += 12.0
		var freq := root * pow(2.0, semitone / 12.0)
		var value := sin(TAU * freq * t) * 0.22 + sin(TAU * freq * 2.0 * t) * 0.05
		value = clampf(value, -1.0, 1.0)
		var sample := int(value * 32767.0)
		data[i * 2] = sample & 0xff
		data[(i * 2) + 1] = (sample >> 8) & 0xff
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frame_count
	wav.data = data
	return wav
