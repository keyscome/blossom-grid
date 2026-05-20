extends Control

@onready var board: Control = $VBox/Board

func _ready() -> void:
  randomize()
  if board.has_method("start"):
    board.start()

func _unhandled_input(event: InputEvent) -> void:
  if not event.is_pressed() or event.is_echo():
    return

  if event.is_action_pressed("ui_left"):
    board.apply_player_move(Vector2i.LEFT)
  elif event.is_action_pressed("ui_right"):
    board.apply_player_move(Vector2i.RIGHT)
  elif event.is_action_pressed("ui_up"):
    board.apply_player_move(Vector2i.UP)
  elif event.is_action_pressed("ui_down"):
    board.apply_player_move(Vector2i.DOWN)
  elif event is InputEventKey:
    if event.keycode == KEY_A:
      board.apply_player_move(Vector2i.LEFT)
    elif event.keycode == KEY_D:
      board.apply_player_move(Vector2i.RIGHT)
    elif event.keycode == KEY_W:
      board.apply_player_move(Vector2i.UP)
    elif event.keycode == KEY_S:
      board.apply_player_move(Vector2i.DOWN)
