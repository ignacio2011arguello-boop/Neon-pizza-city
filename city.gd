extends Node2D

# Neon Lluvia: procedural top-down cyberpunk exploration prototype.
# Pixel-art look is preserved by drawing at a low logical resolution and nearest filtering.

const WORLD_W := 2400
const WORLD_H := 1800
const TILE := 32
const PLAYER_SPEED := 115.0

var player := Vector2(420, 390)
var player_dir := Vector2.DOWN
var rain: Array[Vector4] = []
var buildings: Array[Rect2] = []
var npcs: Array[Vector2] = []
var interactables: Array[Dictionary] = []
var messages: Array[String] = []
var credits := 35
var energy := 78
var mission_done := false
var show_map := false
var touch_move := Vector2.ZERO
var joystick_origin := Vector2.ZERO
var joystick_active := false
var action_pressed := false
var elapsed := 0.0
var camera_pos := Vector2.ZERO
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 902104
	_make_city()
	for i in range(190):
		rain.append(Vector4(rng.randf_range(0, 480), rng.randf_range(0, 270), rng.randf_range(45, 110), rng.randf_range(5, 15)))
	_push_message("LLUVIA ÁCIDA // Distrito Neón")
	_push_message("Buscá a la mensajera cerca del mercado.")
	set_process(true)

func _make_city() -> void:
	# Street grid with varied building footprints.
	for y in range(70, WORLD_H - 100, 190):
		for x in range(70, WORLD_W - 100, 210):
			var w = rng.randi_range(100, 150)
			var h = rng.randi_range(90, 140)
			var r = Rect2(x, y, w, h)
			buildings.append(r)
			interactables.append({"pos": Vector2(x + w/2, y + h/2), "kind": "terminal", "label": "Terminal pública"})
	for i in range(18):
		npcs.append(Vector2(rng.randi_range(90, WORLD_W-90), rng.randi_range(90, WORLD_H-90)))
	interactables.append({"pos": Vector2(650, 420), "kind": "messenger", "label": "Mensajera"})
	interactables.append({"pos": Vector2(830, 640), "kind": "shop", "label": "Puesto de ramen"})
	interactables.append({"pos": Vector2(1050, 500), "kind": "mission", "label": "Panel de encargos"})

func _process(delta: float) -> void:
	elapsed += delta
	_move_player(delta)
	camera_pos = player - Vector2(240, 135)
	camera_pos.x = clamp(camera_pos.x, 0, WORLD_W - 480)
	camera_pos.y = clamp(camera_pos.y, 0, WORLD_H - 270)
	for i in range(rain.size()):
		var r = rain[i]
		r.x -= r.w * delta * 0.35
		r.y += r.w * delta
		if r.y > 278:
			r.y = rng.randf_range(-30, 0)
			r.x = rng.randf_range(0, 480)
		rain[i] = r
	queue_redraw()

func _move_player(delta: float) -> void:
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): d.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): d.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): d.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): d.y += 1
	if touch_move.length() > 0.15: d = touch_move
	if d.length() > 0:
		d = d.normalized()
		player_dir = d
		var next = player + d * PLAYER_SPEED * delta
		if not _blocked(next):
			player = next
	if Input.is_key_just_pressed(KEY_E) or action_pressed:
		action_pressed = false
		_interact()

func _blocked(p: Vector2) -> bool:
	if p.x < 12 or p.y < 12 or p.x > WORLD_W-12 or p.y > WORLD_H-12: return true
	for b in buildings:
		if b.grow(5).has_point(p): return true
	return false

func _interact() -> void:
	var best: Dictionary = {}
	var dist := 999999.0
	for obj in interactables:
		var d = player.distance_to(obj.pos)
		if d < dist:
			dist = d
			best = obj
	if dist > 72:
		_push_message("No hay nada cerca. Explorá las calles.")
	elif best.kind == "messenger":
		if not mission_done:
			credits += 50
			mission_done = true
			_push_message("Encargo completado: paquete entregado. +50 créditos.")
			_push_message("Nuevo objetivo: visitá el panel de encargos.")
		else:
			_push_message("Mensajera: la ciudad nunca duerme. Cuidate.")
	elif best.kind == "shop":
		if credits >= 8:
			credits -= 8
			energy = min(100, energy + 20)
			_push_message("Ramen caliente: energía +20. -8 créditos.")
		else:
			_push_message("Puesto de ramen: te faltan créditos.")
	elif best.kind == "mission":
		_push_message("ENCARGO: encontrá la mensajera del mercado.")
		_push_message("Consejo: usá el minimapa para orientarte.")
	else:
		credits += 1
		_push_message("Terminal hackeada: +1 crédito.")

func _push_message(t: String) -> void:
	messages.push_front(t)
	while messages.size() > 3: messages.pop_back()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var p = event.position
			if p.x > 360 and p.y > 190:
				action_pressed = true
			elif p.x < 155 and p.y > 145:
				joystick_active = true
				joystick_origin = p
				_update_touch(p)
			elif p.x > 410 and p.y < 55:
				show_map = not show_map
		else:
			joystick_active = false
			touch_move = Vector2.ZERO
	elif event is InputEventScreenDrag:
		if joystick_active:
			_update_touch(event.position)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_M:
		show_map = not show_map

func _update_touch(p: Vector2) -> void:
	var v = p - joystick_origin
	touch_move = v.limit_length(50) / 50.0

func _draw() -> void:
	# Draw world in camera-relative coordinates.
	draw_rect(Rect2(Vector2.ZERO, Vector2(480, 270)), Color("#080d20"))
	draw_set_transform(-camera_pos)
	_draw_streets()
	_draw_buildings()
	_draw_city_details()
	_draw_npcs()
	_draw_player()
	draw_set_transform(Vector2.ZERO)
	_draw_rain()
	_draw_hud()

func _draw_streets() -> void:
	draw_rect(Rect2(0, 0, WORLD_W, WORLD_H), Color("#101629"))
	# Main asphalt lanes and sidewalks.
	for y in range(0, WORLD_H, 190):
		draw_rect(Rect2(0, y+145, WORLD_W, 42), Color("#22283b"))
		draw_line(Vector2(0, y+166), Vector2(WORLD_W, y+166), Color("#596078"), 1)
		for x in range(0, WORLD_W, 55):
			draw_rect(Rect2(x, y+164, 22, 2), Color("#b5a86b"))
	for x in range(0, WORLD_W, 210):
		draw_rect(Rect2(x+145, 0, 42, WORLD_H), Color("#22283b"))
		draw_line(Vector2(x+166, 0), Vector2(x+166, WORLD_H), Color("#596078"), 1)
		for y in range(0, WORLD_H, 55):
			draw_rect(Rect2(x+164, y, 2, 22), Color("#b5a86b"))
	# Neon crosswalks.
	for y in range(0, WORLD_H, 190):
		for x in range(0, WORLD_W, 210):
			for k in range(4):
				draw_rect(Rect2(x+147+k*9, y+146, 4, 12), Color(0.1, 0.85, 0.95, 0.65))

func _draw_buildings() -> void:
	var colors = [Color("#202642"), Color("#29213e"), Color("#1c3042"), Color("#30233b")]
	for i in range(buildings.size()):
		var b = buildings[i]
		draw_rect(Rect2(b.position+Vector2(5,7), b.size), Color("#050711"))
		draw_rect(b, colors[i % colors.size()])
		draw_rect(Rect2(b.position, Vector2(b.size.x, 5)), Color("#f04cbd"))
		draw_rect(Rect2(b.position+Vector2(4, 8), Vector2(b.size.x-8, 2)), Color("#32e6ed", 0.8))
		# Windows
		for wx in range(int(b.position.x+12), int(b.end.x-8), 15):
			for wy in range(int(b.position.y+18), int(b.end.y-8), 17):
				var c = Color("#f9c96c") if ((wx+wy+i)%4 == 0) else Color("#22bfe5")
				draw_rect(Rect2(wx, wy, 5, 7), Color(c, 0.78))
		# Rooftop machinery and signs.
		draw_rect(Rect2(b.position+Vector2(12, 12), Vector2(18, 8)), Color("#505a77"))
		draw_rect(Rect2(b.position+Vector2(b.size.x-30, b.size.y-18), Vector2(17, 5)), Color("#fa4cbd"))
		if i % 3 == 0:
			draw_rect(Rect2(b.position+Vector2(b.size.x/2-2, -8), Vector2(4, 9)), Color("#ff4fc3"))

func _draw_city_details() -> void:
	# Puddles, vending machines, street lamps, drains, neon signs.
	for y in range(80, WORLD_H, 125):
		for x in range(45, WORLD_W, 145):
			draw_rect(Rect2(x, y, 18, 6), Color(0.05, 0.75, 0.95, 0.20))
			draw_rect(Rect2(x+4, y+2, 9, 2), Color(0.15, 0.8, 1.0, 0.35))
	for y in range(100, WORLD_H, 380):
		for x in range(100, WORLD_W, 420):
			draw_rect(Rect2(x, y, 9, 22), Color("#11131e"))
			draw_rect(Rect2(x-2, y, 13, 4), Color("#d950ff"))
			draw_rect(Rect2(x+2, y+4, 5, 12), Color(0.12, 0.8, 1.0, 0.65))
	for obj in interactables:
		var p = obj.pos
		var col = Color("#42f5e9")
		if obj.kind == "messenger": col = Color("#ffcf5c")
		elif obj.kind == "shop": col = Color("#ff4fb8")
		elif obj.kind == "mission": col = Color("#8b74ff")
		draw_rect(Rect2(p+Vector2(-7,-11), Vector2(14,22)), Color("#080b18"))
		draw_rect(Rect2(p+Vector2(-5,-9), Vector2(10,18)), col)
		draw_rect(Rect2(p+Vector2(-3,-7), Vector2(6,3)), Color("#f4f8ff"))

func _draw_npcs() -> void:
	for i in range(npcs.size()):
		var p = npcs[i]
		var bob = sin(elapsed*2.0+i)*1.5
		draw_rect(Rect2(p+Vector2(-5, -2+bob), Vector2(10, 11)), Color("#e44e9c") if i%2==0 else Color("#39d9e8"))
		draw_rect(Rect2(p+Vector2(-4, -8+bob), Vector2(8, 7)), Color("#d8b9a1"))
		draw_rect(Rect2(p+Vector2(-5, -9+bob), Vector2(10, 3)), Color("#24213b"))

func _draw_player() -> void:
	var p = player
	# shadow, jacket, head, cyber visor and animated coat pixels
	draw_rect(Rect2(p+Vector2(-7, 2), Vector2(14, 5)), Color(0,0,0,0.45))
	draw_rect(Rect2(p+Vector2(-5,-8), Vector2(10, 14)), Color("#202b54"))
	draw_rect(Rect2(p+Vector2(-6,-5), Vector2(12, 7)), Color("#25e6ed"))
	draw_rect(Rect2(p+Vector2(-4,-15), Vector2(8, 8)), Color("#e8b8a1"))
	draw_rect(Rect2(p+Vector2(-5,-16), Vector2(10, 4)), Color("#17192d"))
	draw_rect(Rect2(p+Vector2(-3,-12), Vector2(6, 2)), Color("#ff4ecb"))
	draw_rect(Rect2(p+Vector2(-4,6), Vector2(3,5)), Color("#0a0d19"))
	draw_rect(Rect2(p+Vector2(1,6), Vector2(3,5)), Color("#0a0d19"))

func _draw_rain() -> void:
	# Overlay rain is camera-locked for a strong rainy-night atmosphere.
	for r in rain:
		draw_line(Vector2(r.x, r.y), Vector2(r.x-3, r.y+8), Color(0.25,0.72,1.0,0.42), 1)
	# occasional neon reflection streaks
	for i in range(14):
		var x = fposmod(i*41 + elapsed*8, 500)
		var y = fposmod(i*29 + elapsed*34, 280)
		draw_line(Vector2(x,y), Vector2(x+9,y+2), Color(0.95,0.15,0.72,0.16), 2)

func _draw_hud() -> void:
	draw_rect(Rect2(5,5,238,43), Color(0.02,0.03,0.08,0.88))
	draw_rect(Rect2(5,5,238,2), Color("#36e7f5"))
	draw_string(ThemeDB.fallback_font, Vector2(12,18), "NEON LLUVIA  /  DISTRITO 07", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#53efff"))
	draw_string(ThemeDB.fallback_font, Vector2(12,31), "¢ %d     ENERGIA %d%%" % [credits, energy], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#f5b8e7"))
	draw_string(ThemeDB.fallback_font, Vector2(12,42), "WASD/FLECHAS: MOVER   E: USAR   M: MAPA", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("#d0d9ee"))
	# Mini-map
	draw_rect(Rect2(410,5,65,50), Color(0.02,0.03,0.08,0.88))
	draw_rect(Rect2(410,5,65,2), Color("#ff4fc8"))
	for b in buildings:
		var p = Vector2(410 + b.position.x/WORLD_W*65, 5+b.position.y/WORLD_H*50)
		draw_rect(Rect2(p, Vector2(max(1,b.size.x/WORLD_W*65), max(1,b.size.y/WORLD_H*50))), Color("#48516f"))
	var mp = Vector2(410 + player.x/WORLD_W*65, 5+player.y/WORLD_H*50)
	draw_rect(Rect2(mp-Vector2(1,1), Vector2(3,3)), Color("#ffffff"))
	# Messages
	draw_rect(Rect2(5, 215, 300, 49), Color(0.02,0.03,0.08,0.82))
	for i in range(messages.size()):
		draw_string(ThemeDB.fallback_font, Vector2(11, 229+i*12), messages[i], HORIZONTAL_ALIGNMENT_LEFT, 288, 8, Color("#c5faff"))
	# Mobile controls
	draw_circle(Vector2(61,218), 34, Color(0.04,0.08,0.15,0.68))
	draw_arc(Vector2(61,218), 34, 0, TAU, 32, Color(0.15,0.85,0.95,0.7), 2)
	var knob = Vector2(61,218) + touch_move*22
	draw_circle(knob, 11, Color(0.1,0.85,0.95,0.45))
	draw_circle(Vector2(425,222), 27, Color(0.7,0.08,0.48,0.65))
	draw_arc(Vector2(425,222), 27, 0, TAU, 32, Color("#ff66d6"), 2)
	draw_string(ThemeDB.fallback_font, Vector2(408,225), "USAR", HORIZONTAL_ALIGNMENT_LEFT, 40, 8, Color.WHITE)
	if show_map:
		draw_rect(Rect2(65,48,350,174), Color(0.015,0.02,0.06,0.96))
		draw_rect(Rect2(65,48,350,2), Color("#35eaf4"))
		draw_string(ThemeDB.fallback_font, Vector2(78,65), "MAPA DEL DISTRITO // EXPLORACION", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#ff67d7"))
		for b in buildings:
			var p = Vector2(75+b.position.x/WORLD_W*330, 75+b.position.y/WORLD_H*130)
			draw_rect(Rect2(p, Vector2(max(2,b.size.x/WORLD_W*330), max(2,b.size.y/WORLD_H*130))), Color("#46506e"))
		var p2 = Vector2(75+player.x/WORLD_W*330, 75+player.y/WORLD_H*130)
		draw_circle(p2, 3, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(78,210), "M o toca el icono superior para cerrar", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#a8f8ff"))
