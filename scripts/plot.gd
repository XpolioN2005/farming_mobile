extends TileMapLayer

func get_all_plots() -> Array[Vector2i]:
	var plots: Array[Vector2i] = []

	for cell in get_used_cells():
		var source_id = get_cell_source_id(cell)
		var atlas_coords = get_cell_atlas_coords(cell)
		
		if source_id == 0 and atlas_coords == Vector2i(1, 0):
			plots.append(cell)
	
	return plots

func get_all_plot_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for cell in get_all_plots():
		positions.append(map_to_local(cell))
	return positions

func _ready():
	GameManeger.plots = get_all_plot_positions()
	for pos in GameManeger.plots:
		print("Plot found at: ", pos)
