extends KinematicBody

# Tweakable properties

export (float) var gravity = 4

export (float) var run_speed = 8
export (float) var fly_speed = 2
export (float) var max_run_speed = 15

export (float) var run_damp = 0.85
export (float) var fly_damp = 0.98

export (int) var jump_speed = 20
export (float) var jump_time = 0.2 # Time in seconds for advanced control over jump

var planet_position = Vector3()

# Node References
#onready var player_camera = $"../PlayerCamera"
#onready var front_camera = $"../FrontCamera"
onready var ground_ray = $GroundRay

var cam_offset = Vector3()

# Velocity in global coordinates
var velocity = Vector3()

# New vars  for planet control
var current_planet = 1
var last_planet = 1
var target_planet = 1

var HUD_Target_P
var HUD_Planet

var planet1_pos = Vector3()
var planet2_pos = Vector3()
var planet3_pos = Vector3()

onready var planet_jump_timer = get_node("P_Jump_Timer")

onready var player_collider_main = get_node("CollisionShape")
onready var player_collider_feet = get_node("Feet")

func _ready():
	# Set up the HUD
	HUD_Target_P = get_parent().get_node("HUD/Target_P")
	HUD_Planet = get_parent().get_node("HUD/Planet")
	
	# Get the planet positions
	planet1_pos = get_parent().get_node("PlanetHolder/Planet01").get_global_transform().origin
	planet2_pos = get_parent().get_node("PlanetHolder/Planet02").get_global_transform().origin
	planet3_pos = get_parent().get_node("PlanetHolder/Planet03").get_global_transform().origin
#	cam_offset = player_camera.transform.origin - transform.origin

# Accessed from the change disks to give us the new planet
func player_change_planet(planet):
#	print ("target planet : ", target_planet)
#	print ("planet pos : ", planet_position)
	target_planet = planet

#var using_front_camera = false

func _process(delta):
	# Update the HUD
	HUD_Target_P.text = "Target Planet : " + str(target_planet)
	HUD_Planet.text = "Current Planet : " + str(current_planet)
	# No changing of cameras
#	if Input.is_action_just_pressed("ui_focus_next"):
#		using_front_camera = !using_front_camera
#		if using_front_camera:
#			front_camera.make_current()
#		else:
#			player_camera.make_current()
			
#	player_camera.transform.origin = transform.origin + cam_offset
	
	if Input.is_action_just_pressed("ui_cancel"):
		grav = !grav
	
	# Changes the planet as long as you're on a change disc
	# Change planet button is currently set to c
	if Input.is_action_just_pressed("change_planet_button"):
		if current_planet != target_planet:
			change_to_planet()
		else:
			pass

func change_to_planet():
	# Turn off the colliders so it doesn't get stuck on current planet
	player_collider_main.disabled = true
	player_collider_feet.disabled = true
	# Countdown til re-enable the colliders
	planet_jump_timer.start()
	# Get the new planet
	current_planet = target_planet

# Re-enable the colliders after a second
func _on_P_Jump_Timer_timeout():
	player_collider_main.disabled = false
	player_collider_feet.disabled = false
#	current_planet = target_planet

# Accessed from change disc script so that it resets the planet when we step off the discs
func reset_planet():
	target_planet = current_planet

var jumping = false
var timer = 0.0
func jump(delta):
	var newjump = Input.is_action_just_pressed('ui_select')
	
	# Only reset if it is a new jump, and from the floor
	if newjump and not jumping and is_on_floor():
		jumping = true
		timer = 0.0
	
	# More of the current jump
	if jumping and timer < jump_time:
		var proportion_completed = timer / jump_time
		# Gradually decrease the jump speed over the time of the jump
		var jump_amount = lerp(jump_speed, 0, proportion_completed)
		timer += delta
		return jump_amount
	else:
		# Finished jumping
		jumping = false
	
	return 0


func get_movement(delta):
	# Input events
	# had to swap 
	var left = Input.is_action_pressed('ui_right')
	var right = Input.is_action_pressed('ui_left')
	var backward = Input.is_action_pressed("ui_up")
	var forward = Input.is_action_pressed("ui_down")
	var jump = Input.is_action_pressed('ui_select')

	# Movement velocity in local coordinates
	var move = Vector3()
	
	# Different speed on ground and in air
	var move_speed = run_speed if is_on_floor() else fly_speed
	if right:
		move.x += move_speed
	if left:
		move.x -= move_speed
	if backward:
		move.z += move_speed
	if forward:
		move.z -= move_speed
	
	# Make sure player doesn't accelerate too much, clamp vector length
	move = move.normalized() * clamp(move.length(), -move_speed, move_speed)
	
	# Apply jump
	if jump:
		move.y += jump(delta)
	else:
		jumping = false
#	if planet_jump:
#		move.y += jump_planet(delta)
#	else:
#		planet_jump = false
	return move

var planet_jump = false

var grav = true

func _physics_process(delta):
	# Vector in the direction of gravity
	
	# change gravity to be the centre of the desired planet
	if current_planet == 1:
		planet_position = planet1_pos
	elif current_planet == 2:
		planet_position = planet2_pos
	elif current_planet == 3:
		planet_position = planet3_pos
	
	var grav_vec = Vector3()
	# I think this is the problem bit, as the ray is still facing towards the old planet
	if ground_ray.is_colliding():
		grav_vec = (planet_position - transform.origin).normalized()
#		grav_vec = -ground_ray.get_collision_normal()
	else:
		grav_vec = (planet_position - transform.origin).normalized()
	
	# Feet of player
	var down = -transform.basis.y
	
	# Rotation axis, perpindicular to the down direction and gravity direction
	var rot_axis = down.cross(grav_vec)
	
	# Check to make sure we don't screw up later on, can't normalize null vector
	if (rot_axis.length_squared() == 0):
		var front = transform.basis.z
		rot_axis = front
	else:
		rot_axis = rot_axis.normalized()
	
		# Find the angle to rotate
		var dot = clamp(down.dot(grav_vec), -1, 1)
		# Both are unit vectors, so dot product = cos(angle)
		var angle = acos(dot)
		
		# Rotate player so the local down direction is in the direction of gravity
		transform.basis = transform.basis.rotated(rot_axis, angle)
		transform = transform.orthonormalized() # Fix up basis
	
	# Apply input movement
	var movement = get_movement(delta)
	# Movement is a local translation, so transform with the rotation to get it in global coordinates
	velocity += transform.basis.xform(movement)
	
	# Add gravity 
	velocity += grav_vec * gravity if grav else Vector3()
	
	# Clamp velocity length to something reasonable
#	velocity = velocity.normalized() * clamp(velocity.length(), -15, 15)
	
	# Apply friction or air resistance
	var damp = run_damp if is_on_floor() else fly_damp
	
	# Move player
	velocity = move_and_slide(velocity, -grav_vec) * damp
	
	if get_slide_count() > 0:
		var collision = get_slide_collision(0)
		# Sanity check
		if !is_on_floor():
			print("why")
#			assert(false)


#
#func move_and_slide_custom(var lv, var floor_direction = Vector3(0,1,0), 
#						var physics_delta = get_physics_process_delta_time(), 
#						var max_slides = 4, 
#						var slope_stop_min_velocity = 0.05, 
#						var floor_max_angle = deg2rad(45)):
#	var motion = (floor_velocity + lv) * physics_delta
#	floor_velocity = Vector3(0,0,0)
#	on_floor = false
#	while(max_slides):
#		var collision = move_and_collide(motion)
#		if collision:
#			motion = collision.remainder
#			on_floor = true
#			if (collision.normal.dot(floor_direction) >= cos(floor_max_angle)):
#				floor_velocity = collision.collider_velocity
#				var rel_v = lv - floor_velocity
#				var hor_v = rel_v - floor_direction * floor_direction.dot(rel_v)
#				if collision.get_travel().length() < 0.05 and hor_v.length() < slope_stop_min_velocity:
#					var gt = get_global_transform()
#					gt.origin -= collision.travel 
#					set_global_transform(gt)
#					return (floor_velocity - floor_direction * floor_direction.dot(floor_velocity))
#			var n = collision.normal
#			motion = motion.slide(n)
#			lv = lv.slide(n)
#		else:
##	        print("no collision")
#			break
#		max_slides -= 1
#		if motion.length() == 0:
#			break
#	return lv


