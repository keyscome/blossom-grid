extends SceneTree

func _init() -> void:
	var board_script := load("res://scripts/Board.gd")
	var board: Node = board_script.new()

	board._reset_grid()
	board.grid[0][0] = {"value": 2, "special": "none"}
	board.grid[0][1] = {"value": 2, "special": "none"}
	var result := board._slide_and_merge(Vector2i.LEFT)
	_verify(result["moved"], "slide should move")
	_verify(board.grid[0][0]["value"] == 4, "2+2 should merge to 4")

	board._reset_grid()
	board.grid[0][0] = {"value": 2, "special": "bloom"}
	board.grid[0][1] = {"value": 2, "special": "none"}
	var bloom_result := board._slide_and_merge(Vector2i.LEFT)
	_verify(bloom_result["bloom_triggers"] == 1, "bloom should trigger on merge")
	board._reset_grid()
	board.grid[0][0] = {"value": 2, "special": "none"}
	board.grid[0][1] = {"value": 2, "special": "none"}
	board.grid[0][2] = {"value": 4, "special": "none"}
	board.grid[0][3] = {"value": 8, "special": "none"}
	board.grid[1][0] = {"value": 16, "special": "none"}
	board.grid[1][1] = {"value": 32, "special": "none"}
	board.grid[1][2] = {"value": 64, "special": "none"}
	board.grid[1][3] = {"value": 128, "special": "none"}
	board.grid[2][0] = {"value": 256, "special": "none"}
	board.grid[2][1] = {"value": 512, "special": "none"}
	board.grid[2][2] = {"value": 1024, "special": "none"}
	board.grid[2][3] = {"value": 2048, "special": "none"}
	board.grid[3][0] = {"value": 4096, "special": "none"}
	board.grid[3][1] = {"value": 8192, "special": "none"}
	board.grid[3][2] = {"value": 0, "special": "none"}
	board.grid[3][3] = {"value": 16384, "special": "none"}
	board._resolve_special_after_merge({"bloom_triggers": 1})
	_verify(board.grid[3][2]["value"] == 2, "bloom post-merge should spawn value 2")
	_verify(board.grid[3][2]["special"] == "none", "bloom post-merge should spawn non-special")

	board.previous_merge_delta = 2
	board._reset_grid()
	board.grid[1][1] = {"value": 4, "special": "echo"}
	board.grid[1][2] = {"value": 8, "special": "none"}
	board._apply_echo()
	_verify(board.grid[1][2]["value"] == 16, "echo should copy a merge-like upgrade")

	board._reset_grid()
	board.grid[1][1] = {"value": 2, "special": "moss"}
	board.grid[1][2] = {"value": 4, "special": "none"}
	board._apply_moss()
	_verify(board.grid[1][2]["value"] == 8, "moss should upgrade a neighbor")

	board._reset_grid()
	board.grid[2][1] = {"value": 2, "special": "flow"}
	board.grid[2][2] = {"value": 4, "special": "none"}
	board.grid[2][3] = {"value": 0, "special": "none"}
	board._try_flow_move(Vector2i(1, 2), Vector2i.RIGHT)
	_verify(board.grid[2][2]["special"] == "flow", "flow should move into the next cell")
	_verify(board.grid[2][3]["value"] == 4, "flow should push the chain forward")

	print("board_logic_test passed")
	quit(0)

func _verify(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
