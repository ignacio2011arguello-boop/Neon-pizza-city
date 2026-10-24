
extends Node2D

# NEON LLUVIA - Godot 4.3
# Exploracion cyberpunk 2D para PC y Android.

const WORLD_W := 2400
const WORLD_H := 1800
const PLAYER_SPEED := 115.0

var player := Vector2(420, 390)
var player_dir := Vector2.DOWN
var camera_pos := Vector2.ZERO

var buildings: Array[Rect2] = []
var npcs: Array[Vector2] = []
var interactables: Array[Dictionary] = []
var rain: Array[Vector4] = []
var messages: Array[String] = []

var credits := 35
var energy := 78
var mission_done := false
var show_map := false
var elapsed := 0.0

var touch_move := Vector2.ZERO
var joystick_origin := Vector2.ZERO
var joystick_active := false

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	_make_city()

	for i in range(190):
		rain.append(Vector4(
			rng.randf_range(0, 480),
			rng.randf_range(0, 270),
			rng.randf_range(45, 110),
			rng.randf_range(5, 15)
		))

	_push_message("LLUVIA ACIDA // DISTRITO NEON")
	_push_message("Busca a la mensajera cerca del mercado.")
	_push_message("Pulsa E o USAR para interactuar.")


func _make_city() -> void:
	buildings.clear()
	npcs.clear()
	interactables.clear()

	for y in range(70, WORLD_H - 100, 190):
		for x in range(70, WORLD_W - 100, 210):
			var w := rng.randi_range(100, 150)
			var h := rng.randi_range(90, 140)
			var building := Rect2(x, y, w, h)
			buildings.append(building)

			interactables.append({
				"pos": Vector2(x + w / 2.0, y + h / 2.0),
				"kind": "terminal",
				"label": "Terminal publica"
			})

	for i in range(18):
		npcs.append(Vector2(
			rng.randi_range(90, WORLD_W - 90),
			rng.randi_range(90, WORLD_H - 90)
		))

	interactables.append({
		"pos": Vector2(650, 420),
		"kind": "messenger",
		"label": "Mensajera"
	})

	interactables.append({
		"pos": Vector2(830, 640),
		"kind": "shop",
		"label": "Puesto de ramen"
	})

	interactables.append({
		"pos": Vector2(1050, 500),
		"kind": "mission",
		"label": "Panel de encargos"
	})


func _process(delta: float) -> void:
	elapsed += delta
	_move_player(delta)

	camera_pos = player - Vector2(240, 135)
	camera_pos.x = clampf(camera_pos.x, 0.0, WORLD_W - 480.0)
	camera_pos.y = clampf(camera_pos.y, 0.0, WORLD_H - 270.0)

	for i in range(rain.size()):
		var drop := rain[i]
		drop.x -= drop.z * delta * 0.35
		drop.y += drop.z * delta

		if drop.y > 278:
			drop.y = rng.randf_range(-30, 0)
			drop.x = rng.randf_range(0, 480)

		rain[i] = drop

	queue_redraw()


func _move_player(delta: float) -> void:
	var direction := Vector2.ZERO

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1

	direction += touch_move

	if direction.length() > 1.0:
		direction = direction.normalized()

	if direction.length() > 0.01:
		player_dir = direction.normalized()
		player += direction * PLAYER_SPEED * delta

	player.x = clampf(player.x, 8.0, WORLD_W - 8.0)
	player.y = clampf(player.y, 8.0, WORLD_H - 8.0)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_interact()
		elif event.keycode == KEY_M:
			show_map = not show_map

	if event is InputEventScreenTouch:
		if event.pressed:
			var p: Vector2 = event.position

			if p.x > 390 and p.y < 65:
				show_map = not show_map
			elif p.x > 375 and p.y > 180:
				_interact()
			elif p.x < 135 and p.y > 170:
				joystick_active = true
				joystick_origin = Vector2(61, 218)
				touch_move = ((p - joystick_origin) / 34.0).limit_length(1.0)
		else:
			joystick_active = false
			touch_move = Vector2.ZERO

	if event is InputEventScreenDrag and joystick_active:
		touch_move = ((event.position - joystick_origin) / 34.0).limit_length(1.0)


func _interact() -> void:
	var closest: Dictionary = {}
	var closest_distance := 72.0

	for obj in interactables:
		var distance: float = player.distance_to(obj["pos"])
		if distance < closest_distance:
			closest_distance = distance
			closest = obj

	if closest.is_empty():
		_push_message("No hay nada cerca para usar.")
		return

	match closest["kind"]:
		"messenger":
			if not mission_done:
				mission_done = true
				credits += 50
				energy = mini(100, energy + 10)
				_push_message("Encargo completado: +50 creditos.")
				_push_message("La mensajera te agradece.")
			else:
				_push_message("Mensajera: buen trabajo, corredor.")

		"shop":
			if credits >= 8:
				credits -= 8
				energy = mini(100, energy + 20)
				_push_message("Ramen comprado. Energia +20.")
			else:
				_push_message("No tienes suficientes creditos.")

		"mission":
			if mission_done:
				_push_message("Panel: encargo completado.")
			else:
				_push_message("Objetivo: encuentra a la mensajera.")
				_push_message("Busca el marcador amarillo.")

		"terminal":
			credits += 1
			_push_message("Terminal consultada: +1 credito.")


func _push_message(message: String) -> void:
	messages.append(message)

	while messages.size() > 3:
		messages.pop_front()


func _draw() -> void:
	# Dibujo del mundo con camara.
	draw_set_transform(-camera_pos, 0.0, Vector2.ONE)

	draw_rect(
		Rect2(0, 0, WORLD_W, WORLD_H),
		Color("#101426")
	)

	_draw_streets()
	_draw_city_details()
	_draw_buildings()
	_draw_npcs()
	_draw_interactables()
	_draw_player()

	# Restablecer coordenadas para la interfaz.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_draw_rain()
	_draw_hud()


func _draw_streets() -> void:
	for x in range(0, WORLD_W, 210):
		draw_rect(
			Rect2(x, 0, 48, WORLD_H),
			Color("#171c30")
		)
		draw_line(
			Vector2(x + 24, 0),
			Vector2(x + 24, WORLD_H),
			Color(0.18, 0.76, 0.91, 0.25),
			1.0
		)

	for y in range(0, WORLD_H, 190):
		draw_rect(
			Rect2(0, y, WORLD_W, 42),
			Color("#171c30")
		)
		draw_line(
			Vector2(0, y + 21),
			Vector2(WORLD_W, y + 21),
			Color(0.18, 0.76, 0.91, 0.22),
			1.0
		)


func _draw_buildings() -> void:
	var colors: Array[Color] = [
		Color("#202642"),
		Color("#29213e"),
		Color("#1c3042"),
		Color("#30233b")
	]

	for i in range(buildings.size()):
		var b := buildings[i]
		var color := colors[i % colors.size()]

		draw_rect(
			Rect2(b.position + Vector2(5, 7), b.size),
			Color("#050711")
		)
		draw_rect(b, color)

		draw_rect(
			Rect2(b.position, Vector2(b.size.x, 5)),
			Color("#f04cbd")
		)
		draw_rect(
			Rect2(b.position + Vector2(4, 8), Vector2(b.size.x - 8, 2)),
			Color("#32e6ed")
		)

		for wx in range(int(b.position.x + 12), int(b.end.x - 8), 15):
			for wy in range(int(b.position.y + 18), int(b.end.y - 8), 17):
				var window_color := Color("#22bfe5")
				if (wx + wy + i) % 4 == 0:
					window_color = Color("#f9c96c")

				draw_rect(
					Rect2(wx, wy, 5, 7),
					window_color
				)

		draw_rect(
			Rect2(b.position + Vector2(12, 12), Vector2(18, 8)),
			Color("#505a77")
		)
		draw_rect(
			Rect2(
				b.position + Vector2(b.size.x - 30, b.size.y - 18),
				Vector2(17, 5)
			),
			Color("#fa4cbd")
		)


func _draw_city_details() -> void:
	for y in range(80, WORLD_H, 125):
		for x in range(45, WORLD_W, 145):
			draw_rect(
				Rect2(x, y, 18, 6),
				Color(0.05, 0.75, 0.95, 0.25)
			)
			draw_rect(
				Rect2(x + 4, y + 2, 9, 2),
				Color(0.15, 0.8, 1.0, 0.4)
			)

	for y in range(100, WORLD_H, 380):
		for x in range(100, WORLD_W, 420):
			draw_rect(
				Rect2(x, y, 9, 22),
				Color("#11131e")
			)
			draw_rect(
				Rect2(x - 2, y, 13, 4),
				Color("#d950ff")
			)
			draw_rect(
				Rect2(x + 2, y + 4, 5, 12),
				Color("#22cce8")
			)


func _draw_interactables() -> void:
	for obj in interactables:
		var p: Vector2 = obj["pos"]
		var color := Color("#42f5e9")

		match obj["kind"]:
			"messenger":
				color = Color("#ffcf5c")
			"shop":
				color = Color("#ff4fb8")
			"mission":
				color = Color("#8b74ff")

		draw_rect(
			Rect2(p + Vector2(-7, -11), Vector2(14, 22)),
			Color("#080b18")
		)
		draw_rect(
			Rect2(p + Vector2(-5, -9), Vector2(10, 18)),
			color
		)
		draw_rect(
			Rect2(p + Vector2(-3, -7), Vector2(6, 3)),
			Color("#f4f8ff")
		)


func _draw_npcs() -> void:
	for i in range(npcs.size()):
		var p := npcs[i]
		var bob := sin(elapsed * 2.0 + i) * 1.5
		var body_color := Color("#e44e9c")

		if i % 2 != 0:
			body_color = Color("#39d9e8")

		draw_rect(
			Rect2(p + Vector2(-5, -2 + bob), Vector2(10, 11)),
			body_color
		)
		draw_rect(
			Rect2(p + Vector2(-4, -8 + bob), Vector2(8, 7)),
			Color("#d8b9a1")
		)
		draw_rect(
			Rect2(p + Vector2(-5, -9 + bob), Vector2(10, 3)),
			Color("#24213b")
		)


func _draw_player() -> void:
	var p := player

	draw_rect(
		Rect2(p + Vector2(-7, 2), Vector2(14, 5)),
		Color(0.0, 0.0, 0.0, 0.45)
	)
	draw_rect(
		Rect2(p + Vector2(-5, -8), Vector2(10, 14)),
		Color("#202b54")
	)
	draw_rect(
		Rect2(p + Vector2(-6, -5), Vector2(12, 7)),
		Color("#25e6ed")
	)
	draw_rect(
		Rect2(p + Vector2(-4, -15), Vector2(8, 8)),
		Color("#e8b8a1")
	)
	draw_rect(
		Rect2(p + Vector2(-5, -16), Vector2(10, 4)),
		Color("#17192d")
	)
	draw_rect(
		Rect2(p + Vector2(-3, -12), Vector2(6, 2)),
		Color("#ff4ecb")
	)
	draw_rect(
		Rect2(p + Vector2(-4, 6), Vector2(3, 5)),
		Color("#0a0d19")
	)
	draw_rect(
		Rect2(p + Vector2(1, 6), Vector2(3, 5)),
		Color("#0a0d19")
	)


func _draw_rain() -> void:
	for drop in rain:
		draw_line(
			Vector2(drop.x, drop.y),
			Vector2(drop.x - 3, drop.y + drop.w),
			Color(0.25, 0.72, 1.0, 0.5),
			1.0
		)

	for i in range(14):
		var x := fposmod(i * 41 + elapsed * 8, 500)
		var y := fposmod(i * 29 + elapsed * 34, 280)

		draw_line(
			Vector2(x, y),
			Vector2(x + 9, y + 2),
			Color(0.95, 0.15, 0.72, 0.2),
			2.0
		)


func _draw_hud() -> void:
	draw_rect(
		Rect2(5, 5, 238, 43),
		Color(0.02, 0.03, 0.08, 0.9)
	)
	draw_rect(
		Rect2(5, 5, 238, 2),
		Color("#36e7f5")
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(12, 18),
		"NEON LLUVIA / DISTRITO 07",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		8,
		Color("#53efff")
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(12, 31),
		"¢ %d     ENERGIA %d%%" % [credits, energy],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		8,
		Color("#f5b8e7")
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(12, 42),
		"WASD: MOVER   E: USAR   M: MAPA",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		7,
		Color("#d0d9ee")
	)

	# Minimapa.
	draw_rect(
		Rect2(410, 5, 65, 50),
		Color(0.02, 0.03, 0.08, 0.9)
	)
	draw_rect(
		Rect2(410, 5, 65, 2),
		Color("#ff4fc8")
	)

	for b in buildings:
		var p := Vector2(
			410 + b.position.x / float(WORLD_W) * 65,
			5 + b.position.y / float(WORLD_H) * 50
		)
		draw_rect(
			Rect2(
				p,
				Vector2(
					maxf(1.0, b.size.x / float(WORLD_W) * 65),
					maxf(1.0, b.size.y / float(WORLD_H) * 50)
				)
			),
			Color("#48516f")
		)

	var map_player := Vector2(
		410 + player.x / float(WORLD_W) * 65,
		5 + player.y / float(WORLD_H) * 50
	)
	draw_rect(
		Rect2(map_player - Vector2.ONE, Vector2(3, 3)),
		Color.WHITE
	)

	# Mensajes.
	draw_rect(
		Rect2(5, 215, 300, 49),
		Color(0.02, 0.03, 0.08, 0.88)
	)

	for i in range(messages.size()):
		draw_string(
			ThemeDB.fallback_font,
			Vector2(11, 229 + i * 12),
			messages[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			288,
			8,
			Color("#c5faff")
		)

	# Joystick tactil.
	draw_circle(
		Vector2(61, 218),
		34,
		Color(0.04, 0.08, 0.15, 0.75)
	)
	draw_arc(
		Vector2(61, 218),
		34,
		0,
		TAU,
		32,
		Color(0.15, 0.85, 0.95, 0.8),
		2.0
	)

	var knob := Vector2(61, 218) + touch_move * 22
	draw_circle(knob, 11, Color(0.1, 0.85, 0.95, 0.65))

	# Boton de interaccion.
	draw_circle(
		Vector2(425, 222),
		27,
		Color(0.7, 0.08, 0.48, 0.75)
	)
	draw_arc(
		Vector2(425, 222),
		27,
		0,
		TAU,
		32,
		Color("#ff66d6"),
		2.0
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(408, 225),
		"USAR",
		HORIZONTAL_ALIGNMENT_LEFT,
		40,
		8,
		Color.WHITE
	)

	# Mapa ampliado.
	if show_map:
		draw_rect(
			Rect2(65, 48, 350, 174),
			Color(0.015, 0.02, 0.06, 0.97)
		)
		draw_rect(
			Rect2(65, 48, 350, 2),
			Color("#35eaf4")
		)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(78, 65),
			"MAPA DEL DISTRITO",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			10,
			Color("#ff67d7")
		)

		for b in buildings:
			var p := Vector2(
				75 + b.position.x / float(WORLD_W) * 330,
				75 + b.position.y / float(WORLD_H) * 130
			)
			draw_rect(
				Rect2(
					p,
					Vector2(
						maxf(2.0, b.size.x / float(WORLD_W) * 330),
						maxf(2.0, b.size.y / float(WORLD_H) * 130)
					)
				),
				Color("#46506e")
			)

		var p2 := Vector2(
			75 + player.x / float(WORLD_W) * 330,
			75 + player.y / float(WORLD_H) * 130
		)
		draw_circle(p2, 3, Color.WHITE)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(78, 210),
			"Pulsa M para cerrar",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			8,
			Color("#a8f8ff")
		)
