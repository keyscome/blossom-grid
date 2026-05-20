extends SceneTree

func _init() -> void:
  var board_script := load("res://scripts/Board.gd")
  var board = board_script.new()

  board._reset_grid()
  board.grid[0][0] = {"value": 2, "special": "none"}
  board.grid[0][1] = {"value": 2, "special": "none"}
  var result := board._slide_and_merge(Vector2i.LEFT)
  _assert(result["moved"], "slide should move")
  _assert(board.grid[0][0]["value"] == 4, "2+2 should merge to 4")

  board._reset_grid()
  board.grid[0][0] = {"value": 2, "special": "bloom"}
  board.grid[0][1] = {"value": 2, "special": "none"}
  var bloom_result := board._slide_and_merge(Vector2i.LEFT)
  _assert(bloom_result["bloom_triggers"] == 1, "bloom should trigger on merge")

  board.previous_merge_delta = 2
  board._reset_grid()
  board.grid[1][1] = {"value": 4, "special": "echo"}
  board.grid[1][2] = {"value": 8, "special": "none"}
  board._apply_echo()
  _assert(board.grid[1][2]["value"] == 16, "echo should copy a merge-like upgrade")

  print("board_logic_test passed")
  quit(0)

func _assert(condition: bool, message: String) -> void:
  if condition:
    return
  push_error(message)
  quit(1)
