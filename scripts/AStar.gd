extends Node2D

const GRID = 25
const TILE = 64

var grid = []
var start = Vector2()
var goal = Vector2()
var obs = []
var path = []
var placing = true
var player = null
var drag = false
var last_cell = Vector2(-1, -1)

func _ready():
	var cam = Camera2D.new()
	cam.position = Vector2(800, 800)
	cam.zoom = Vector2(0.5, 0.5)
	cam.enabled = true
	add_child(cam)
	
	var ui = CanvasLayer.new()
	add_child(ui)
	
	var button1 = Button.new()
	button1.text = "Start Pathfinding"
	button1.position = Vector2(10, 10)
	button1.size = Vector2(150, 40)
	button1.pressed.connect(_on_start_pressed)
	ui.add_child(button1)
	
	var button2 = Button.new()
	button2.text = "Reset"
	button2.position = Vector2(170, 10)
	button2.size = Vector2(100, 40)
	button2.pressed.connect(_on_reset_pressed)
	ui.add_child(button2)
	
	init_grid()
	place_items()
	update_display()

func init_grid():
	grid.resize(GRID)
	for x in range(GRID):
		grid[x] = []
		for y in range(GRID):
			grid[x].append(0)

func place_items():
	start = get_rand_pos()
	goal = get_rand_pos()
	while manhattan(start, goal) < (GRID / 2) + 1:
		goal = get_rand_pos()
	
	grid[start.x][start.y] = 0
	grid[goal.x][goal.y] = 0

func get_rand_pos():
	return Vector2(randi() % GRID, randi() % GRID)

func update_display():
	for child in get_children():
		if child is Sprite2D and child.name.begins_with("grid_"):
			child.queue_free()
		elif child.name == "grid_player":
			child.queue_free()
	
	for x in range(GRID):
		for y in range(GRID):
			var tile = Sprite2D.new()
			tile.name = "grid_bg_%d_%d" % [x, y]
			tile.texture = load("res://asset/static-green.png")
			tile.position = Vector2(x * TILE + TILE/2, y * TILE + TILE/2)
			add_child(tile)
	
	for o in obs:
		var rock = Sprite2D.new()
		rock.name = "grid_obs_%d_%d" % [o.x, o.y]
		rock.texture = load("res://asset/rock1.png")
		rock.position = Vector2(o.x * TILE + TILE/2, o.y * TILE + TILE/2)
		add_child(rock)
	
	
	var end = Sprite2D.new()
	end.name = "grid_goal"
	end.texture = load("res://asset/orange.png")
	end.position = Vector2(goal.x * TILE + TILE/2, goal.y * TILE + TILE/2)
	add_child(end)
	var char = load("res://scenes/character.tscn")
	player = char.instantiate()
	player.name = "grid_player"
	player.position = Vector2(start.x * TILE + TILE/2, 
								 start.y * TILE + TILE/2)
	print("Placed character at position: ", player.position)
	add_child(player)

func _input(event):
	if placing:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					drag = true
					place_obs()
				else:
					drag = false
					last_cell = Vector2(-1, -1)
		
		elif event is InputEventMouseMotion and drag:
			place_obs()

func place_obs():
	var mouse = get_viewport().get_mouse_position()
	var world = get_viewport_transform().affine_inverse() * mouse
	var gx = int(world.x / TILE)
	var gy = int(world.y / TILE)
	
	if gx < 0 or gx >= GRID or gy < 0 or gy >= GRID:
		return
	var pos = Vector2(gx, gy)
	
	if pos == last_cell:
		return
	last_cell = pos
	
	if pos == start or pos == goal:
		return
		
	if obs.has(pos):
		obs.erase(pos)
		grid[pos.x][pos.y] = 0
	else:
		obs.append(pos)
		grid[pos.x][pos.y] = 1
	
	update_display()

func _on_start_pressed():
	placing = false
	path = find_path(start, goal)
	move_char()

func _on_reset_pressed():
	placing = true
	obs.clear()
	path.clear()
	
	place_items()
	update_display()
	
	print("Game reset with new player and goal positions")

func find_path(s, g):
	var open = [s]
	var from = {}
	var gscore = {}
	var fscore = {}
	
	gscore[s] = 0
	fscore[s] = manhattan(s, g)
	
	while not open.is_empty():
		# pick the best spot to check next
		var curr = open[0]
		var idx = 0
		
		# Find lowest score
		for i in range(1, open.size()):
			if fscore.get(open[i], INF) < fscore.get(curr, INF):
				curr = open[i]
				idx = i
		open.remove_at(idx)
		# If goal, then done
		if curr == g:
			var p = [curr]
			# Work backwards to build path
			while curr in from:
				curr = from[curr]
				p.push_front(curr)
			return p
		
		# Check each neighbor spot
		for n in get_near(curr):
			# Cost to reach neighbor
			var tmp = gscore.get(curr, INF) + get_dist(curr, n)
			
			# If better path
			if tmp < gscore.get(n, INF):
				# Remember this path
				from[n] = curr
				gscore[n] = tmp
				fscore[n] = tmp + manhattan(n, g)
				
				# Add to check list
				if not n in open:
					open.append(n)
	
	# no path
	return []

func get_near(pos):
	var near = []
	var dirs = [
		Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1),
		Vector2(-1, 0),                  Vector2(1, 0),
		Vector2(-1, 1),  Vector2(0, 1),  Vector2(1, 1)
	]
	
	for d in dirs:
		var n = pos + d
		if n.x >= 0 and n.x < GRID and n.y >= 0 and n.y < GRID:
			if grid[n.x][n.y] == 0:
				near.append(n)
	
	return near

func get_dist(a, b):
	return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))

func manhattan(a, b):
	return abs(a.x - b.x) + abs(a.y - b.y)

func move_char():
	if path.is_empty():
		print("No path found!")
		return
	
	if not player or not is_instance_valid(player):
		print("Character node invalid, locating it...")
		player = get_node_or_null("grid_player")
		
		if not player:
			print("Character not found, cannot move!")
			return
		
	for i in range(1, path.size()):
		var pos = path[i]
		var tpos = Vector2(pos.x * TILE + TILE/2, pos.y * TILE + TILE/2)
		player.position = tpos
		await get_tree().create_timer(0.3).timeout
	
	print("Reached destination!")
