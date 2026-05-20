extends Control

const BOARD_SIZE := 4
const CELL_SIZE := 96.0
const GAP := 8.0

var grid: Array = []
var previous_merge_delta := 0
var config := {
  "spawn_values": [2, 2, 2, 4],
  "special_weights": {
    "none": 78,
    "bloom": 9,
    "moss": 7,
    "flow": 4,
    "echo": 2
  },
  "special_colors": {
    "none": Color("d9c7a5"),
    "bloom": Color("f3b5d0"),
    "moss": Color("b9c7a4"),
    "flow": Color("9bc4dd"),
    "echo": Color("d2b9ef")
  }
}

func start() -> void:
  _load_config()
  _reset_grid()
  spawn_tile()
  spawn_tile()
  queue_redraw()

func _load_config() -> void:
  var file := FileAccess.open("res://config/tile_config.json", FileAccess.READ)
  if file == null:
    push_warning("Failed to load tile_config.json, using defaults")
    return

  var parsed := JSON.parse_string(file.get_as_text())
  if typeof(parsed) == TYPE_DICTIONARY:
    config.merge(parsed, true)
    var mapped_colors := {}
    for key in config["special_colors"].keys():
      mapped_colors[key] = Color(str(config["special_colors"][key]))
    config["special_colors"] = mapped_colors
  else:
    push_warning("Malformed tile_config.json, using defaults")

func _reset_grid() -> void:
  grid.clear()
  for y in BOARD_SIZE:
    var row: Array = []
    for x in BOARD_SIZE:
      row.append(_empty_cell())
    grid.append(row)

func _empty_cell() -> Dictionary:
  return {"value": 0, "special": "none"}

func apply_player_move(direction: Vector2i) -> void:
  var result := _slide_and_merge(direction)
  if not result["moved"]:
    return

  if result["merge_delta"] > 0:
    previous_merge_delta = result["merge_delta"]

  _resolve_special_after_merge(result)
  _apply_passive_specials()
  spawn_tile()
  _play_soft_feedback(result["merge_delta"] > 0)
  queue_redraw()

func _slide_and_merge(direction: Vector2i) -> Dictionary:
  var moved := false
  var merge_delta := 0
  var bloom_triggers := 0

  for index in BOARD_SIZE:
    var line := _extract_line(index, direction)
    var compact: Array = []
    for cell in line:
      if cell["value"] > 0:
        compact.append(cell.duplicate(true))

    var merged: Array = []
    var cursor := 0
    while cursor < compact.size():
      if cursor + 1 < compact.size() and compact[cursor]["value"] == compact[cursor + 1]["value"]:
        var merged_cell := {
          "value": compact[cursor]["value"] * 2,
          "special": _merge_special(compact[cursor]["special"], compact[cursor + 1]["special"])
        }
        if compact[cursor]["special"] == "bloom" or compact[cursor + 1]["special"] == "bloom":
          bloom_triggers += 1
        merge_delta += merged_cell["value"] - compact[cursor]["value"]
        merged.append(merged_cell)
        cursor += 2
      else:
        merged.append(compact[cursor])
        cursor += 1

    while merged.size() < BOARD_SIZE:
      merged.append(_empty_cell())

    if _write_line(index, direction, merged):
      moved = true

  return {"moved": moved, "merge_delta": merge_delta, "bloom_triggers": bloom_triggers}

func _merge_special(a: String, b: String) -> String:
  if a == b:
    return a
  if a == "none":
    return b
  if b == "none":
    return a
  # Keep left tile special when both are non-none and different.
  return a

func _extract_line(index: int, direction: Vector2i) -> Array:
  var line: Array = []
  for i in BOARD_SIZE:
    var pos := Vector2i.ZERO
    if direction == Vector2i.LEFT:
      pos = Vector2i(i, index)
    elif direction == Vector2i.RIGHT:
      pos = Vector2i(BOARD_SIZE - 1 - i, index)
    elif direction == Vector2i.UP:
      pos = Vector2i(index, i)
    else:
      pos = Vector2i(index, BOARD_SIZE - 1 - i)
    line.append(grid[pos.y][pos.x])
  return line

func _write_line(index: int, direction: Vector2i, merged: Array) -> bool:
  var changed := false
  for i in BOARD_SIZE:
    var pos := Vector2i.ZERO
    if direction == Vector2i.LEFT:
      pos = Vector2i(i, index)
    elif direction == Vector2i.RIGHT:
      pos = Vector2i(BOARD_SIZE - 1 - i, index)
    elif direction == Vector2i.UP:
      pos = Vector2i(index, i)
    else:
      pos = Vector2i(index, BOARD_SIZE - 1 - i)

    if grid[pos.y][pos.x]["value"] != merged[i]["value"] or grid[pos.y][pos.x]["special"] != merged[i]["special"]:
      changed = true
    grid[pos.y][pos.x] = merged[i].duplicate(true)
  return changed

func _resolve_special_after_merge(result: Dictionary) -> void:
  for _i in result["bloom_triggers"]:
    spawn_tile(2, "none")

func _apply_passive_specials() -> void:
  _apply_moss()
  _apply_flow()
  _apply_echo()

func _apply_moss() -> void:
  for y in BOARD_SIZE:
    for x in BOARD_SIZE:
      if grid[y][x]["special"] != "moss":
        continue
      var neighbors := _neighbors(Vector2i(x, y))
      neighbors.shuffle()
      for n in neighbors:
        if grid[n.y][n.x]["value"] > 0:
          grid[n.y][n.x]["value"] *= 2
          break

func _apply_flow() -> void:
  var dirs := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
  for y in BOARD_SIZE:
    for x in BOARD_SIZE:
      if grid[y][x]["special"] != "flow":
        continue
      dirs.shuffle()
      _try_flow_move(Vector2i(x, y), dirs[0])

func _try_flow_move(start: Vector2i, dir: Vector2i) -> void:
  var end := start + dir
  if not _inside(end):
    return
  if grid[end.y][end.x]["value"] == 0:
    var temp := grid[start.y][start.x]
    grid[start.y][start.x] = _empty_cell()
    grid[end.y][end.x] = temp.duplicate(true)
    return

  var chain: Array = [end]
  var cursor := end
  while true:
    cursor += dir
    if not _inside(cursor):
      return
    if grid[cursor.y][cursor.x]["value"] == 0:
      break
    chain.append(cursor)

  for i in range(chain.size() - 1, -1, -1):
    var from_pos := chain[i]
    var to_pos := from_pos + dir
    grid[to_pos.y][to_pos.x] = grid[from_pos.y][from_pos.x].duplicate(true)
  grid[end.y][end.x] = grid[start.y][start.x].duplicate(true)
  grid[start.y][start.x] = _empty_cell()

func _apply_echo() -> void:
  if previous_merge_delta <= 0:
    return

  for y in BOARD_SIZE:
    for x in BOARD_SIZE:
      if grid[y][x]["special"] != "echo":
        continue
      for n in _neighbors(Vector2i(x, y)):
        if grid[n.y][n.x]["value"] > 0:
          grid[n.y][n.x]["value"] *= 2
          break

func _neighbors(pos: Vector2i) -> Array:
  var result: Array = []
  for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
    var n := pos + d
    if _inside(n):
      result.append(n)
  return result

func _inside(p: Vector2i) -> bool:
  return p.x >= 0 and p.x < BOARD_SIZE and p.y >= 0 and p.y < BOARD_SIZE

func spawn_tile(override_value := -1, override_special := "") -> bool:
  var empties: Array = []
  for y in BOARD_SIZE:
    for x in BOARD_SIZE:
      if grid[y][x]["value"] == 0:
        empties.append(Vector2i(x, y))
  if empties.is_empty():
    return false

  var pos: Vector2i = empties.pick_random()
  var value := override_value if override_value != -1 else _random_spawn_value()
  var special := override_special if override_special != "" else _random_special()
  grid[pos.y][pos.x] = {"value": value, "special": special}
  return true

func _random_spawn_value() -> int:
  var pool: Array = config.get("spawn_values", [2, 2, 2, 4])
  return int(pool.pick_random())

func _random_special() -> String:
  var weights: Dictionary = config.get("special_weights", {"none": 100})
  var keys: Array = weights.keys()
  keys.sort()
  var total := 0
  for key in keys:
    total += int(weights[key])
  if total <= 0:
    return "none"

  var roll := randi() % total
  var acc := 0
  for key in keys:
    acc += int(weights[key])
    if roll < acc:
      return key
  return "none"

func _play_soft_feedback(merged: bool) -> void:
  var tween := create_tween()
  tween.tween_property(self, "scale", Vector2(1.01, 1.01), 0.06)
  tween.tween_property(self, "scale", Vector2.ONE, 0.12)

  if merged:
    var player := get_node_or_null("MergeSfx")
    if player and player is AudioStreamPlayer and player.stream:
      player.play()

func _draw() -> void:
  var board_px := BOARD_SIZE * CELL_SIZE + (BOARD_SIZE + 1) * GAP
  var origin := Vector2((size.x - board_px) * 0.5, (size.y - board_px) * 0.5)
  draw_rect(Rect2(origin, Vector2(board_px, board_px)), Color("c7b59a"), true)

  for y in BOARD_SIZE:
    for x in BOARD_SIZE:
      var p := origin + Vector2(GAP + x * (CELL_SIZE + GAP), GAP + y * (CELL_SIZE + GAP))
      var rect := Rect2(p, Vector2(CELL_SIZE, CELL_SIZE))
      var cell: Dictionary = grid[y][x]
      var base_color: Color = config["special_colors"].get(cell["special"], Color("d9c7a5"))
      draw_rect(rect, base_color if cell["value"] > 0 else Color("ece4d6"), true)
      if cell["value"] > 0:
        var text := str(cell["value"])
        var font := ThemeDB.fallback_font
        var font_size := 26
        var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
        draw_string(font, rect.position + (rect.size - text_size) * 0.5 + Vector2(0, text_size.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("3f3528"))
        if cell["special"] != "none":
          draw_string(font, rect.position + Vector2(8, 20), cell["special"].left(1).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("5f5344"))
