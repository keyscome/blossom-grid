extends Control

# ─── Constants ────────────────────────────────────────────────────────────────

const BOARD_SIZE := 4
const CELL_SIZE := 90.0
const GAP := 10.0
const CORNER_R := 10

# Animation durations (seconds)
const MOVE_DUR := 0.12
const MERGE_SCALE := 1.18
const MERGE_DUR := 0.22
const SPAWN_DUR := 0.36
const BREATHE_PERIOD := 5.0
const BREATHE_SCALE := 0.003

# 12 % of newly spawned tiles carry the Bloom tag
const BLOOM_CHANCE := 0.12

# Board background colours
const BOARD_BG := Color("#d4c8b4")
const EMPTY_COLOR := Color("#c0b8a8")

# Growth-stage definitions: value → {name, bg hex, fg hex}
const STAGE_KEYS: Array[int] = [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048]
const STAGE_DATA: Dictionary = {
	2:    {"name": "seed",     "bg": "#c8b090", "fg": "#6a5040"},
	4:    {"name": "sprout",   "bg": "#acc882", "fg": "#3a5828"},
	8:    {"name": "leaf",     "bg": "#78aa68", "fg": "#f0f8e8"},
	16:   {"name": "bud",      "bg": "#d4b870", "fg": "#6a5020"},
	32:   {"name": "bloom",    "bg": "#e89060", "fg": "#f8eee8"},
	64:   {"name": "flower",   "bg": "#e07878", "fg": "#f8eeee"},
	128:  {"name": "petal",    "bg": "#cc8cd0", "fg": "#f8f0f8"},
	256:  {"name": "drift",    "bg": "#88b8e8", "fg": "#eef4ff"},
	512:  {"name": "glow",     "bg": "#ece870", "fg": "#606020"},
	1024: {"name": "radiance", "bg": "#f8c858", "fg": "#705820"},
	2048: {"name": "ethereal", "bg": "#fff4dc", "fg": "#907858"},
}

# ─── State ────────────────────────────────────────────────────────────────────

# grid[y][x] = {value: int, special: String}
var grid: Array = []

# tile_nodes[y][x] = Panel node or null
var tile_nodes: Array = []

# Locked while animations are running
var is_locked := false

var breathe_tween: Tween = null

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func start() -> void:
	_reset_grid()
	_init_tile_nodes()
	_spawn_tile(true)
	_spawn_tile(true)
	_start_breathing()

func reset() -> void:
	if breathe_tween:
		breathe_tween.kill()
		breathe_tween = null
	for child in get_children():
		child.queue_free()
	is_locked = false
	start()

# ─── Grid ─────────────────────────────────────────────────────────────────────

func _reset_grid() -> void:
	grid.clear()
	for _y in BOARD_SIZE:
		var row: Array = []
		for _x in BOARD_SIZE:
			row.append({"value": 0, "special": "none"})
		grid.append(row)

func _init_tile_nodes() -> void:
	for child in get_children():
		child.queue_free()
	tile_nodes.clear()
	for _y in BOARD_SIZE:
		var row: Array = []
		for _x in BOARD_SIZE:
			row.append(null)
		tile_nodes.append(row)

# ─── Draw: board background + empty-cell slots ────────────────────────────────

func _draw() -> void:
	var board_w: float = BOARD_SIZE * CELL_SIZE + (BOARD_SIZE + 1) * GAP
	var origin := Vector2((size.x - board_w) * 0.5, (size.y - board_w) * 0.5)
	draw_rect(Rect2(origin, Vector2(board_w, board_w)), BOARD_BG, true)
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var p := origin + Vector2(GAP + x * (CELL_SIZE + GAP), GAP + y * (CELL_SIZE + GAP))
			draw_rect(Rect2(p, Vector2(CELL_SIZE, CELL_SIZE)), EMPTY_COLOR, true)

# ─── Position helpers ─────────────────────────────────────────────────────────

func _cell_pos(x: int, y: int) -> Vector2:
	var board_w: float = BOARD_SIZE * CELL_SIZE + (BOARD_SIZE + 1) * GAP
	var origin := Vector2((size.x - board_w) * 0.5, (size.y - board_w) * 0.5)
	return origin + Vector2(GAP + x * (CELL_SIZE + GAP), GAP + y * (CELL_SIZE + GAP))

func _inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < BOARD_SIZE and p.y >= 0 and p.y < BOARD_SIZE

func _neighbors(pos: Vector2i) -> Array:
	var result: Array = []
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var n: Vector2i = pos + d
		if _inside(n):
			result.append(n)
	return result

# ─── Tile visual helpers ──────────────────────────────────────────────────────

func _get_stage_key(value: int) -> int:
	for i in range(STAGE_KEYS.size() - 1, -1, -1):
		if value >= STAGE_KEYS[i]:
			return STAGE_KEYS[i]
	return 2

func _format_value(v: int) -> String:
	if v >= 1000:
		return str(v / 1000) + "k"
	return str(v)

func _create_tile_node(value: int, special: String) -> Panel:
	var panel := Panel.new()
	panel.size = Vector2(CELL_SIZE, CELL_SIZE)
	panel.pivot_offset = Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = CORNER_R
	style.corner_radius_top_right = CORNER_R
	style.corner_radius_bottom_left = CORNER_R
	style.corner_radius_bottom_right = CORNER_R
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_top = 0
	style.border_width_bottom = 0
	panel.add_theme_stylebox_override("panel", style)

	# Main value label
	var val_lbl := Label.new()
	val_lbl.name = "ValueLabel"
	val_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_size_override("font_size", 28)
	panel.add_child(val_lbl)

	# Small stage-name label at the bottom
	var stage_lbl := Label.new()
	stage_lbl.name = "StageLabel"
	stage_lbl.anchor_left = 0.0
	stage_lbl.anchor_right = 1.0
	stage_lbl.anchor_top = 0.62
	stage_lbl.anchor_bottom = 1.0
	stage_lbl.offset_left = 0.0
	stage_lbl.offset_right = 0.0
	stage_lbl.offset_top = 0.0
	stage_lbl.offset_bottom = -5.0
	stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	stage_lbl.add_theme_font_size_override("font_size", 11)
	panel.add_child(stage_lbl)

	# Tiny bloom indicator dot (top-right corner)
	if special == "bloom":
		var dot := ColorRect.new()
		dot.name = "BloomDot"
		dot.color = Color(1.0, 0.70, 0.85, 0.85)
		dot.size = Vector2(7.0, 7.0)
		dot.position = Vector2(CELL_SIZE - 13.0, 6.0)
		panel.add_child(dot)

	_update_tile_visual(panel, value, special)
	return panel

func _update_tile_visual(panel: Panel, value: int, special: String) -> void:
	var stage_key: int = _get_stage_key(value)
	var data: Dictionary = STAGE_DATA.get(stage_key, STAGE_DATA[2])

	var bg_color := Color(str(data["bg"]))
	if special == "bloom":
		bg_color = bg_color.lerp(Color("#f3b5d0"), 0.28)

	var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.bg_color = bg_color

	var fg_color := Color(str(data["fg"]))

	var val_lbl: Label = panel.get_node_or_null("ValueLabel") as Label
	if val_lbl:
		val_lbl.text = _format_value(value)
		val_lbl.add_theme_color_override("font_color", fg_color)

	var stage_lbl: Label = panel.get_node_or_null("StageLabel") as Label
	if stage_lbl:
		stage_lbl.text = str(data.get("name", ""))
		stage_lbl.add_theme_color_override("font_color", fg_color.darkened(0.15))

# ─── Spawn ────────────────────────────────────────────────────────────────────

func _spawn_tile(instant: bool) -> bool:
	var empties: Array = []
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			if grid[y][x]["value"] == 0:
				empties.append(Vector2i(x, y))
	if empties.is_empty():
		return false

	var pos: Vector2i = empties.pick_random()
	var value := 2 if randf() > 0.1 else 4
	var special := "bloom" if randf() < BLOOM_CHANCE else "none"
	grid[pos.y][pos.x] = {"value": value, "special": special}

	var tile := _create_tile_node(value, special)
	tile.position = _cell_pos(pos.x, pos.y)
	add_child(tile)
	tile_nodes[pos.y][pos.x] = tile

	if not instant:
		tile.scale = Vector2(0.45, 0.45)
		tile.modulate.a = 0.0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(tile, "scale", Vector2.ONE, SPAWN_DUR) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(tile, "modulate:a", 1.0, SPAWN_DUR * 0.7) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	return true

# Bloom effect: sprout 1-2 seeds floating up from nearby empty cells
func _spawn_bloom_seeds(near_pos: Vector2i) -> void:
	var count := 1 + (1 if randf() < 0.35 else 0)
	var nbrs := _neighbors(near_pos)
	nbrs.shuffle()
	var spawned := 0
	for nbr_var in nbrs:
		if spawned >= count:
			break
		var nbr: Vector2i = nbr_var
		if grid[nbr.y][nbr.x]["value"] != 0:
			continue
		grid[nbr.y][nbr.x] = {"value": 2, "special": "none"}
		var tile := _create_tile_node(2, "none")
		var base_pos := _cell_pos(nbr.x, nbr.y)
		tile.position = base_pos + Vector2(0.0, -10.0)
		tile.scale = Vector2(0.3, 0.3)
		tile.modulate.a = 0.0
		add_child(tile)
		tile_nodes[nbr.y][nbr.x] = tile
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(tile, "scale", Vector2.ONE, SPAWN_DUR * 1.1) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(tile, "modulate:a", 1.0, SPAWN_DUR * 0.85) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(tile, "position", base_pos, SPAWN_DUR * 1.1) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		spawned += 1

# ─── Player move ──────────────────────────────────────────────────────────────

func apply_player_move(direction: Vector2i) -> void:
	if is_locked:
		return
	var result := _slide_and_merge(direction)
	if not result["moved"]:
		return
	is_locked = true
	_run_move_animation(result)

# Runs as a coroutine; sets is_locked = false when done.
func _run_move_animation(result: Dictionary) -> void:
	var tile_moves: Array = result["tile_moves"]
	var merged_positions: Array = result["merged_positions"]
	var bloom_positions: Array = result["bloom_positions"]

	# ── Phase 1: slide tiles to new positions ────────────────────────────────
	var has_slide := false
	for tm in tile_moves:
		var fp: Vector2i = tm["from"]
		var tp: Vector2i = tm["to"]
		if fp != tp:
			has_slide = true
			break

	if has_slide:
		var tween := create_tween()
		tween.set_parallel(true)
		for tm in tile_moves:
			var fp: Vector2i = tm["from"]
			var tp: Vector2i = tm["to"]
			if fp == tp:
				continue
			var tile: Panel = tile_nodes[fp.y][fp.x] as Panel
			if tile == null:
				continue
			tween.tween_property(tile, "position", _cell_pos(tp.x, tp.y), MOVE_DUR) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		await tween.finished

	# ── Phase 2: reconcile tile_nodes, free consumed tiles, update visuals ───
	var new_nodes: Array = []
	for _y in BOARD_SIZE:
		var row: Array = []
		for _x in BOARD_SIZE:
			row.append(null)
		new_nodes.append(row)

	for tm in tile_moves:
		var fp: Vector2i = tm["from"]
		var tp: Vector2i = tm["to"]
		var consumed: bool = tm["consumed"]
		var tile: Panel = tile_nodes[fp.y][fp.x] as Panel
		if consumed:
			if tile:
				tile.queue_free()
		else:
			if tile:
				new_nodes[tp.y][tp.x] = tile
				var cell: Dictionary = grid[tp.y][tp.x]
				_update_tile_visual(tile, int(cell["value"]), str(cell["special"]))

	tile_nodes = new_nodes

	# ── Phase 3: gentle merge pulse ──────────────────────────────────────────
	if merged_positions.size() > 0:
		var pulse := create_tween()
		pulse.set_parallel(true)
		for mp_var in merged_positions:
			var mp: Vector2i = mp_var
			var tile: Panel = tile_nodes[mp.y][mp.x] as Panel
			if tile == null:
				continue
			pulse.tween_property(tile, "scale",
				Vector2(MERGE_SCALE, MERGE_SCALE), MERGE_DUR * 0.4) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			pulse.tween_property(tile, "scale",
				Vector2.ONE, MERGE_DUR * 0.6) \
				.set_delay(MERGE_DUR * 0.4) \
				.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		await pulse.finished

	# ── Phase 4: spawn one new tile ──────────────────────────────────────────
	_spawn_tile(false)

	# ── Phase 5: bloom seed burst (slight delay for visual rhythm) ───────────
	if bloom_positions.size() > 0:
		await get_tree().create_timer(0.08).timeout
		for bp_var in bloom_positions:
			var bp: Vector2i = bp_var
			_spawn_bloom_seeds(bp)

	await get_tree().create_timer(SPAWN_DUR).timeout
	is_locked = false

# ─── Slide & Merge logic ──────────────────────────────────────────────────────

func _slide_and_merge(direction: Vector2i) -> Dictionary:
	var merge_delta := 0
	var merged_positions: Array = []
	var bloom_positions: Array = []
	var tile_moves: Array = []

	for index in BOARD_SIZE:
		var line_pos := _line_positions(index, direction)

		# Collect non-empty tiles in order
		var active: Array = []
		for i in BOARD_SIZE:
			var p: Vector2i = line_pos[i]
			if grid[p.y][p.x]["value"] > 0:
				active.append({
					"pos": p,
					"value": grid[p.y][p.x]["value"],
					"special": grid[p.y][p.x]["special"],
				})

		# Merge pass
		var result_tiles: Array = []
		var i := 0
		while i < active.size():
			if i + 1 < active.size() and active[i]["value"] == active[i + 1]["value"]:
				var new_v: int = int(active[i]["value"]) * 2
				var new_sp := _merge_special(str(active[i]["special"]), str(active[i + 1]["special"]))
				var was_bloom: bool = active[i]["special"] == "bloom" \
					or active[i + 1]["special"] == "bloom"
				result_tiles.append({"value": new_v, "special": new_sp})
				var slot: int = result_tiles.size() - 1
				var dest: Vector2i = line_pos[slot]
				merge_delta += int(active[i]["value"])
				merged_positions.append(dest)
				if was_bloom:
					bloom_positions.append(dest)
				tile_moves.append({"from": active[i]["pos"],     "to": dest, "consumed": false})
				tile_moves.append({"from": active[i + 1]["pos"], "to": dest, "consumed": true})
				i += 2
			else:
				result_tiles.append({"value": int(active[i]["value"]), "special": str(active[i]["special"])})
				var slot: int = result_tiles.size() - 1
				var dest: Vector2i = line_pos[slot]
				tile_moves.append({"from": active[i]["pos"], "to": dest, "consumed": false})
				i += 1

		# Write result back to grid
		for j in BOARD_SIZE:
			var p: Vector2i = line_pos[j]
			if j < result_tiles.size():
				grid[p.y][p.x] = result_tiles[j].duplicate()
			else:
				grid[p.y][p.x] = {"value": 0, "special": "none"}

	var moved := merge_delta > 0
	if not moved:
		for tm in tile_moves:
			var fp: Vector2i = tm["from"]
			var tp: Vector2i = tm["to"]
			if fp != tp:
				moved = true
				break

	return {
		"moved": moved,
		"merge_delta": merge_delta,
		"merged_positions": merged_positions,
		"bloom_positions": bloom_positions,
		"tile_moves": tile_moves,
	}

func _line_positions(index: int, direction: Vector2i) -> Array:
	var positions: Array = []
	for i in BOARD_SIZE:
		var pos: Vector2i
		if direction == Vector2i.LEFT:
			pos = Vector2i(i, index)
		elif direction == Vector2i.RIGHT:
			pos = Vector2i(BOARD_SIZE - 1 - i, index)
		elif direction == Vector2i.UP:
			pos = Vector2i(index, i)
		else:
			pos = Vector2i(index, BOARD_SIZE - 1 - i)
		positions.append(pos)
	return positions

func _merge_special(a: String, b: String) -> String:
	if a == b:
		return a
	if a == "none":
		return b
	if b == "none":
		return a
	return a

# ─── Board breathing animation ────────────────────────────────────────────────

func _start_breathing() -> void:
	if breathe_tween:
		breathe_tween.kill()
	pivot_offset = size * 0.5
	breathe_tween = create_tween()
	breathe_tween.set_loops(-1)
	breathe_tween.tween_property(self, "scale",
		Vector2(1.0 + BREATHE_SCALE, 1.0 + BREATHE_SCALE),
		BREATHE_PERIOD * 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	breathe_tween.tween_property(self, "scale",
		Vector2.ONE,
		BREATHE_PERIOD * 0.5) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
