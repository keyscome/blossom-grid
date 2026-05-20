extends SceneTree

func _init() -> void:
	var board_script := load("res://scripts/Board.gd")
	var board: Node = board_script.new()

	# ── Test 1: basic slide + merge ─────────────────────────────────────────
	board._reset_grid()
	board.grid[0][0] = {"value": 2, "special": "none"}
	board.grid[0][1] = {"value": 2, "special": "none"}
	var result := board._slide_and_merge(Vector2i.LEFT)
	_verify(result["moved"], "slide should detect movement")
	_verify(board.grid[0][0]["value"] == 4, "2+2 should merge to 4")
	_verify(board.grid[0][1]["value"] == 0, "source slot should be empty after merge")
	_verify(result["merge_delta"] == 2, "merge_delta should equal half of merged value")

	# ── Test 2: tile_moves tracking ─────────────────────────────────────────
	board._reset_grid()
	board.grid[0][0] = {"value": 2, "special": "none"}
	board.grid[0][1] = {"value": 2, "special": "none"}
	var r2 := board._slide_and_merge(Vector2i.LEFT)
	_verify(r2["tile_moves"].size() == 2, "two active tiles should produce two tile_moves")
	var consumed_count := 0
	for tm in r2["tile_moves"]:
		if tm["consumed"]:
			consumed_count += 1
	_verify(consumed_count == 1, "exactly one tile should be consumed in a merge")

	# ── Test 3: bloom triggers on merge ─────────────────────────────────────
	board._reset_grid()
	board.grid[0][0] = {"value": 2, "special": "bloom"}
	board.grid[0][1] = {"value": 2, "special": "none"}
	var r3 := board._slide_and_merge(Vector2i.LEFT)
	_verify(r3["bloom_positions"].size() == 1, "bloom merge should record one bloom_position")

	# ── Test 4: no false movement when board already compact ─────────────────
	board._reset_grid()
	board.grid[0][0] = {"value": 2, "special": "none"}
	board.grid[0][1] = {"value": 4, "special": "none"}
	var r4 := board._slide_and_merge(Vector2i.LEFT)
	_verify(not r4["moved"], "already-packed different values should not count as moved")

	# ── Test 5: multi-tile slide without merge ───────────────────────────────
	board._reset_grid()
	board.grid[0][2] = {"value": 2, "special": "none"}
	var r5 := board._slide_and_merge(Vector2i.LEFT)
	_verify(r5["moved"], "tile not at pack position should count as moved")
	_verify(board.grid[0][0]["value"] == 2, "tile should slide to leftmost slot")

	# ── Test 6: merged_positions entries match merge destinations ────────────
	board._reset_grid()
	board.grid[1][0] = {"value": 8, "special": "none"}
	board.grid[1][1] = {"value": 8, "special": "none"}
	var r6 := board._slide_and_merge(Vector2i.LEFT)
	_verify(r6["merged_positions"].size() == 1, "one merge should yield one entry")
	_verify(board.grid[1][0]["value"] == 16, "merged value should be 16")

	print("board_logic_test passed")
	quit(0)

func _verify(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

