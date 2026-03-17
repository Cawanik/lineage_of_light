extends AnimatedSprite2D

const IDLE_PATH = "res://assets/sprites/lich_king/animations/breathing-idle/"
const ROT_PATH = "res://assets/sprites/lich_king/rotations/"
const DIRECTIONS = ["south", "south-east", "east", "north-east", "north"]


func _ready() -> void:
	_setup_animations()
	play("idle_south")


func _setup_animations() -> void:
	var frames = SpriteFrames.new()

	for dir in DIRECTIONS:
		var dir_key = dir.replace("-", "_")
		var idle_name = "idle_" + dir_key
		frames.add_animation(idle_name)
		frames.set_animation_speed(idle_name, 2.0)
		frames.set_animation_loop(idle_name, true)

		var loaded = false
		for i in range(10):
			var path = IDLE_PATH + dir + "/frame_%03d.png" % i
			if ResourceLoader.exists(path):
				frames.add_frame(idle_name, load(path))
				loaded = true
			else:
				break
		if not loaded:
			var rot = ROT_PATH + dir + ".png"
			if ResourceLoader.exists(rot):
				frames.add_frame(idle_name, load(rot))

	# Mirror directions: west = east flipped, etc.
	for dir in ["south-west", "west", "north-west"]:
		var dir_key = dir.replace("-", "_")
		var mirror_dir = dir.replace("west", "east")
		var mirror_key = mirror_dir.replace("-", "_")
		var idle_name = "idle_" + dir_key
		var mirror_name = "idle_" + mirror_key
		frames.add_animation(idle_name)
		frames.set_animation_speed(idle_name, 2.0)
		frames.set_animation_loop(idle_name, true)
		if frames.has_animation(mirror_name):
			for i in range(frames.get_frame_count(mirror_name)):
				frames.add_frame(idle_name, frames.get_frame_texture(mirror_name, i))

	if frames.has_animation("default"):
		frames.remove_animation("default")

	sprite_frames = frames
