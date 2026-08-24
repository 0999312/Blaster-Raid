extends RefCounted
## 轻量音效工具：统一走 sound_manager 插件（Engine 单例 "SoundManager"）。

static func play(stream: AudioStream, pitch: float = 1.0, volume_db: float = 0.0, ui: bool = false) -> void:
	if stream == null:
		return
	var sm = Engine.get_singleton("SoundManager")
	if sm == null:
		return
	var player = null
	if ui:
		player = sm.call("play_ui_sound_with_pitch", stream, pitch)
	else:
		player = sm.call("play_sound_with_pitch", stream, pitch)
	if player is AudioStreamPlayer:
		if volume_db != 0.0:
			player.volume_db = volume_db
