extends Control
var _circle_data = {}
var undo_stack = []  # Stack to store states for undo
var redo_stack = []  # Stack to store states for redo
var stack: Array = []
var redo_queue: Array = []
var touches: Dictionary = {}
var current_layer: Control
var is_touch_active = false
var current_color = Color.RED
var current_brush_type = "circle"
var current_line_2d: Line2D # store the reference of current Line2D node (for texture painting).
var current_thickness = 10
var current_texture: Texture = preload("res://Games/color_book/Assets/New folder/pattern_01.png")
var pencile: Texture = preload("res://Games/color_book/Assets/New folder/lines-hatching-grunge-graphite-pencil-transparent-background_1085577-68755-removebg-preview.png")
var last_position: Vector2 = Vector2()
var min_draw_distance = 5
var is_drawing = false
var redraw_interval = 0.01
var time_since_last_redraw = 0
@onready var drawing_panel: Control = $DrawingPanel
const LAYER = preload("res://Games/color_book/Scenes/layer.tscn")
var drawing_panel_rect: Rect2

@onready var circlemarker: AudioStreamPlayer2D = $CanvasLayer2/Control/circle/circlemarker
@onready var markersound: AudioStreamPlayer2D = $CanvasLayer2/Control/marker/markersound

@onready var designmarker: AudioStreamPlayer2D = $CanvasLayer2/Control/Texturecolor/designmarker
@onready var pencil: AudioStreamPlayer2D = $CanvasLayer2/Control/pen/pencil
@onready var erazr: AudioStreamPlayer2D = $CanvasLayer2/Control/erazer/erazr
@onready var ingamebutton: AudioStreamPlayer2D = $ingamebutton
var selected_brush: TextureButton = null
var selected_color: TextureButton = null


@onready var brush_container := get_node("CanvasLayer2/BrushContainer")  # Adjust path if needed
@onready var color_container := get_node("CanvasLayer2/ColorContainer") 

func _ready() -> void:
	var drawing_panel = $DrawingPanel
	drawing_panel_rect = drawing_panel.get_global_rect()
	set_process(true)
	Bgm.playing = false
		# Connect buttons to selection functions
	if brush_container:
		for brush in brush_container.get_children():
			if brush is TextureButton:  # Ensure it's a TextureButton
				brush.pressed.connect(func(): select_brush(brush))
	else:
		push_error("BrushContainer not found!")

	if color_container:
		for color in color_container.get_children():
			if color is TextureButton:  # Ensure it's a TextureButton
				color.pressed.connect(func(): select_color(color))
	else:
		push_error("ColorContainer not found!")

func select_brush(brush: TextureButton):
	if selected_brush:
		selected_brush.button_pressed = false  # Unpress previous brush
	
	selected_brush = brush
	selected_brush.button_pressed = true  # Keep new brush pressed

func select_color(color: TextureButton):
	if selected_color:
		selected_color.button_pressed = false  # Unpress previous color

	selected_color = color
	selected_color.button_pressed = true  # Keep new color pressed	
# Function to save the current state of the drawing
func _notification(what):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().change_scene_to_file("res://Scenes/lobby.tscn")
const MAX_STACK_SIZE = 100
func save_state():
	var state = []
	for child in drawing_panel.get_children():
		if child is Line2D:
			state.append({
				"points": child.points.duplicate(),
				"color": child.default_color,
				"width": child.width,
				"texture": child.texture,
				"joint_mode": child.joint_mode,
				"begin_cap": child.begin_cap_mode,
				"end_cap": child.end_cap_mode,
				"texture_repeat": child.texture_repeat,
				"texture_mode": child.texture_mode
				
			})
	undo_stack.append(state)
	redo_stack.clear()  # Clear redo stack on a new action
	
# Undo the last action
func undo():
	if undo_stack.size() > 0:
		var last_state = undo_stack.pop_back()
		redo_stack.append(save_current_state())  # Save current state for redo
		restore_state(last_state)
# Redo the last undone action
func redo():
	if redo_stack.size() > 0:
		var next_state = redo_stack.pop_back()
		undo_stack.append(save_current_state())  # Save current state for undo
		restore_state(next_state)   
# Save the current state of all Line2D objects
func save_current_state() -> Array:
	var state = []
	for child in drawing_panel.get_children():
		if child is Line2D:
			state.append({
				"points": child.points.duplicate(),
				"color": child.default_color,
				"width": child.width,
				"texture": child.texture,
				"joint_mode": child.joint_mode,
				"begin_cap": child.begin_cap_mode,
				"end_cap": child.end_cap_mode,
				"texture_repeat": child.texture_repeat,
				"texture_mode": child.texture_mode
				
			})
	return state
	
func restore_state(state: Array):
	# Remove all current Line2D nodes
	for child in drawing_panel.get_children():
		if child is Line2D:
			child.queue_free()
	# Recreate Line2D nodes from saved state
	for line_data in state:
		var line = Line2D.new()
		line.points = line_data["points"]
		line.default_color = line_data["color"]
		line.width = line_data["width"]
		line.texture = line_data["texture"]
		line.joint_mode = line_data["joint_mode"]
		line.begin_cap_mode = line_data["begin_cap"]
		line.end_cap_mode =  line_data["end_cap"]
		line.texture_repeat =  line_data["texture_repeat"]
		line.texture_mode =  line_data["texture_mode"]
		drawing_panel.add_child(line)
func _handle_touch_input(event: InputEvent) -> void:
	
	if event is InputEventScreenTouch:
		
		if event.pressed:  # On touch start
			touches[event.index] = event.position
			
			
			handle_single_touch_start(event.position)  # Your touch start logic
			
		else:  # On touch release
			touches.erase(event.index)
			handle_single_touch_end(event.position)  # Your touch end logic
				
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		
		#if is_touch_active:  # Process drag only if touch is active
		handle_single_touch_drag(event.position)  # Your touch drag logic
		
# Called when the single touch starts
func handle_single_touch_start(position: Vector2) -> void:
	if current_brush_type == "texture" and touches.size() == 1:
		create_line2d()  # Create a new Line2D object
		if current_line_2d:
			save_state()
			#designmarker.play()
	elif current_brush_type == "erase":
		create_line2d_erazer()
		save_state()
		#erazr.play()
	elif current_brush_type == "pencile":
			create_line2d_pencil()
			save_state()
			#pencil.play()
	elif current_brush_type == "circle":
		create_line2d_round()
		if current_line_2d:
			save_state()
			#circlemarker.play()
	elif current_brush_type == "square":
		create_line2d_marker()
		save_state()
		#markersound.play()
# Called when the single touch is dragging
func handle_single_touch_drag(pos: Vector2) -> void:
	if touches.size() > 1:
		pos = touches[0]
	if current_line_2d:
		current_line_2d.add_point(pos)
# Called when the single touch ends
func handle_single_touch_end(position: Vector2) -> void:
	if current_line_2d:
		current_line_2d = null
func clear_canvas() -> void:
	# Save current state for undo before clearing
	if drawing_panel.get_child_count() > 0:
		save_state()
	# Remove all Line2D objects from the drawing panel
	for child in drawing_panel.get_children():
		if child is Line2D:
			child.queue_free()
	# Clear redo stack (new action clears redo history)
	redo_stack.clear()
	# Reset current drawing reference
	current_line_2d = null
	print("Canvas cleared and state saved.")
func _draw_smooth_line(start_pos: Vector2, end_pos: Vector2) -> void:
	var distance = start_pos.distance_to(end_pos)
	if distance < min_draw_distance:
		return
	var steps = int(distance / min_draw_distance)
	for i in range(steps):
		var t = float(i) / steps
		var interpolated_pos = start_pos.lerp(end_pos, t)
		_circle_data[interpolated_pos] = {
			"color": current_color,
			"brush_type": current_brush_type,
			"thickness": current_thickness,
			"texture": current_texture,
			"pencile": pencile
		}
	_circle_data[end_pos] = {
		"color": current_color,
		"brush_type": current_brush_type,
		"thickness": current_thickness,
		"texture": current_texture,
		"pencile": pencile
	}
	last_position = end_pos
func _process(delta: float) -> void:
	time_since_last_redraw += delta
	if time_since_last_redraw >= redraw_interval:
		if current_layer:
			current_layer.queue_redraw()
		time_since_last_redraw = 0
func _draw_of_layer(layer: Control) -> void:
	for position in _circle_data.keys():
		var data = _circle_data[position]
		var color = data["color"]
		var brush_type = data["brush_type"]
		var thickness = data["thickness"]
		var texture = data["texture"]
		var pencile = data["pencile"]
		var highlight_color = color
		highlight_color.a = 0.1
func _on_texturecolor_pressed() -> void:
	current_brush_type = "texture"
	current_texture = preload("res://Games/color_book/Assets/New folder/pattern_01 - Copy-photoaidcom-cropped.png")  # Use desired texture
	min_draw_distance = 1
	ingamebutton.play()
func _on_pen_pressed() -> void:
	current_brush_type = "pencile"
	ingamebutton.play()

	
func _on_circle_pressed() -> void:
	current_brush_type = "circle"
	current_color = Color.RED
	ingamebutton.play()
func _on_marker_pressed() -> void:
	current_brush_type = "square"
	current_color = Color.RED
	ingamebutton.play()
	
func _on_purple_pressed() -> void:
	current_color = Color.PURPLE
	ingamebutton.play()	
func _on_red_pressed() -> void:
	current_color = Color.RED
	ingamebutton.play()
func _on_blue_pressed() -> void:
	current_color = Color.BLUE
	ingamebutton.play()
func _on_green_pressed() -> void:
	current_color = Color.GREEN
	ingamebutton.play()
func _on_yellow_pressed() -> void:
	current_color = Color.YELLOW
	ingamebutton.play()
func _on_deletebutton_pressed() -> void:
	clear_canvas()
	ingamebutton.play()
func _on_brown_pressed() -> void:
	current_color = Color.BROWN
	ingamebutton.play()
func _on_orange_pressed() -> void:
	current_color = Color.ORANGE
	ingamebutton.play()
func _on_pink_pressed() -> void:
	current_color = Color.PINK
	ingamebutton.play()
func _on_hotpink_pressed() -> void:
	current_color = Color.DEEP_PINK
	ingamebutton.play()
func _on_black_pressed() -> void:
	current_color = Color.BLACK
	ingamebutton.play()
func _on_gray_pressed() -> void:
	current_color = Color.DIM_GRAY
	ingamebutton.play()
func _on_cyan_pressed() -> void:
	current_color = Color.CYAN
	ingamebutton.play()
func _on_violet_pressed() -> void:
	current_color = Color.VIOLET
	ingamebutton.play()
func _on_maroon_pressed() -> void:
	current_color = Color.MAROON
	ingamebutton.play()
func _on_silver_pressed() -> void:
	current_color = Color.SILVER
	ingamebutton.play()
func _on_darkgreen_pressed() -> void:
	current_color = Color.DARK_GREEN
	ingamebutton.play()
func _on_lightyellow_pressed() -> void:
	current_color = Color.LIGHT_YELLOW
	ingamebutton.play()
#TODO abhi ke liye theek hai baad  mai erazer logic change
func _on_erazer_pressed() -> void:
	current_brush_type = "erase"
	current_color = Color.WHITE
	ingamebutton.play()
func _on_v_slider_value_changed(value: float) -> void:
		current_thickness = value
		
		
func _on_undo_pressed() -> void:
	undo()
	ingamebutton.play()
	
	
func _on_redo_pressed() -> void:
	redo()
	ingamebutton.play()
	
	
# creates a new Line2D for drawing texture purposes. 
func create_line2d() -> void:
	if current_line_2d:
		save_state()  # Save the completed line before starting a new one
	var line: Line2D = Line2D.new()
	drawing_panel.add_child(line)
	line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	line.texture_mode = Line2D.LINE_TEXTURE_TILE
	line.width = current_thickness
	line.texture = load("res://Games/color_book/Assets/New folder/pattern_01.png")
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	current_line_2d = line

	
	
func create_line2d_pencil() -> void:
	if current_line_2d:
		save_state()  # Save the completed line before starting a new one   
	var line: Line2D = Line2D.new()
	drawing_panel.add_child(line)
	line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	line.texture_mode = Line2D.LINE_TEXTURE_TILE
	line.width = 4
	line.texture = load("res://Games/color_book/Assets/New folder/pencile.jpeg")
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	current_line_2d = line
	line.default_color.a = 0.6

# creates a new Line2D for drawing texture purposes. 
func create_line2d_erazer() -> void:
	if current_line_2d:
		save_state()  # Save the completed line before starting a new one
	var line: Line2D = Line2D.new()
	drawing_panel.add_child(line)
	line.width = current_thickness
	line.default_color = Color.WHITE
	current_line_2d = line

func create_line2d_round() -> void:
	if current_line_2d:
		save_state()  # Save the completed line before starting a new one
	var line: Line2D = Line2D.new()
	drawing_panel.add_child(line)
	line.width = current_thickness
	line.default_color = current_color
	current_line_2d = line
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	
  
func create_line2d_marker() -> void:
	if current_line_2d:
		save_state()  # Save the completed line before starting a new one
	var line: Line2D = Line2D.new()
	drawing_panel.add_child(line)
	line.width = current_thickness
	line.default_color = current_color
	current_line_2d = line
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.default_color.a = 0.5
   
 
func create_new_layer() -> void:
	current_layer = LAYER.instantiate()
	drawing_panel.add_child(current_layer)
	current_layer.size = drawing_panel.size
	current_layer.position = Vector2.ZERO
	current_layer.draw.connect(_draw_of_layer.bind(current_layer))
	current_layer.queue_redraw()
   
func _on_drawing_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_handle_touch_input(event)
