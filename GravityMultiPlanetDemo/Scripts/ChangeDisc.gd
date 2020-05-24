extends Spatial

export var planet_to_go_to = 2
# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _on_Area_body_entered(body):
	# checks if the body has "get_movement", as that is a method unique to the player
	if body.has_method("get_movement"):
		change_planet()

func _on_Area_body_exited(body):
	if body.has_method("get_movement"):
		body.reset_planet()

func change_planet():
	var area = $Area
	var bodies = area.get_overlapping_bodies()
	for abody in bodies:
		if abody == self:
			continue
		if abody.has_method("get_movement"):
			abody.player_change_planet(planet_to_go_to)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


