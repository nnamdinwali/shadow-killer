extends Camera3D

# The target node to follow (usually the Spidey character)
@export var target_path: NodePath = ".." 
# Offset from the character (X: horizontal, Y: height, Z: distance from character)
# For a side-scroller, Z should be a positive number to stay back.
@export var offset: Vector3 = Vector3(0, 2.5, 8.0) 
# How smoothly the camera follows (higher = faster)
@export var smooth_speed: float = 5.0

@onready var target = get_node_or_null(target_path)

func _ready():
	# This ensures the camera doesn't rotate when the character turns
	top_level = true
	if target:
		global_position = target.global_position + offset

func _physics_process(delta):
	if not target:
		target = get_node_or_null(target_path)
		return
		
	# Calculate the desired target position
	var target_pos = target.global_position + offset
	
	# Smoothly interpolate the camera's position
	global_position = global_position.lerp(target_pos, smooth_speed * delta)
	
	# Keep the camera looking at the character's center
	# Vector3(0, 1.5, 0) offsets the "look at" point to the character's chest
	look_at(target.global_position + Vector3(0, 1.5, 0))
