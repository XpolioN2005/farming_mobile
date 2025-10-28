# plot.gd
extends TileMapLayer

const TILE_SIZE := 16
const HALF_TILE_OFFSET := Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)

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
		# local top-left -> add half-tile -> convert to global
		var local_pos = map_to_local(cell) + HALF_TILE_OFFSET
		positions.append(to_global(local_pos))
	return positions

func _ready():
	GameManeger.plot_node = self
	GameManeger.plots = get_all_plot_positions()

