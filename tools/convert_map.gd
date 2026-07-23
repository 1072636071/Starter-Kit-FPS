@tool
extends EditorScript

## Map Conversion Pipeline
## Reads city map layout from JSON and generates a GridMap scene for the FPS project.
## Run via: File > Run (Ctrl+Shift+X) in the Godot editor.
##
## JSON format (resources/city-map-data.json):
##   {"cells": [{"x": int, "y": int, "orientation": int, "structure": int}, ...]}
## Exported from City Builder project.

# Path to map layout JSON (exported from City Builder)
const MAP_JSON_PATH := "res://resources/city-map-data.json"

# Structure model files in the SAME ORDER as City Builder's structures array
const STRUCTURE_MODELS := [
	"res://models/city/road-straight.glb",
	"res://models/city/road-straight-lightposts.glb",
	"res://models/city/road-corner.glb",
	"res://models/city/road-split.glb",
	"res://models/city/road-intersection.glb",
	"res://models/city/pavement.glb",
	"res://models/city/pavement-fountain.glb",
	"res://models/city/building-small-a.glb",
	"res://models/city/building-small-b.glb",
	"res://models/city/building-small-c.glb",
	"res://models/city/building-small-d.glb",
	"res://models/city/building-garage.glb",
	"res://models/city/grass.glb",
	"res://models/city/grass-trees.glb",
	"res://models/city/grass-trees-tall.glb",
]

const MESH_LIBRARY_PATH := "res://resources/city-mesh-library.tres"
const OUTPUT_SCENE_PATH := "res://scenes/city-level.tscn"
const CELL_SIZE := Vector3(4, 4, 4)


func _run():
	print("=== Map Conversion Pipeline ===")

	# Step 1: Build MeshLibrary with trimesh collision
	var mesh_library := _build_mesh_library()
	if not mesh_library:
		push_error("Failed to build MeshLibrary.")
		return

	# Ensure resources directory exists
	DirAccess.make_dir_recursive_absolute("res://resources")
	ResourceSaver.save(mesh_library, MESH_LIBRARY_PATH)
	print("MeshLibrary saved to: %s" % MESH_LIBRARY_PATH)

	# Step 2: Load map data from JSON
	var cells := _load_map_json()
	if cells.is_empty():
		push_error("Failed to load map data from: %s" % MAP_JSON_PATH)
		return
	print("Loaded map with %d cells." % cells.size())

	# Step 3: Create GridMap scene
	var root := Node3D.new()
	root.name = "CityLevel"

	var gridmap := GridMap.new()
	gridmap.name = "GridMap"
	gridmap.cell_size = CELL_SIZE
	gridmap.cell_center_x = false
	gridmap.cell_center_y = false
	gridmap.cell_center_z = false
	gridmap.mesh_library = mesh_library
	root.add_child(gridmap)
	gridmap.owner = root

	# Step 4: Fill GridMap with map data
	for cell in cells:
		var pos := Vector3i(cell["x"], 0, cell["y"])
		gridmap.set_cell_item(pos, cell["structure"], cell["orientation"])

	print("GridMap filled with %d cells." % cells.size())

	# Step 5: Save scene
	var scene := PackedScene.new()
	scene.pack(root)
	ResourceSaver.save(scene, OUTPUT_SCENE_PATH)
	print("Scene saved to: %s" % OUTPUT_SCENE_PATH)

	# Cleanup
	root.free()

	print("=== Conversion complete! ===")


func _build_mesh_library() -> MeshLibrary:
	var mesh_library := MeshLibrary.new()

	for i in range(STRUCTURE_MODELS.size()):
		var model_path: String = STRUCTURE_MODELS[i]

		if not ResourceLoader.exists(model_path):
			push_warning("Model not found: %s (index %d)" % [model_path, i])
			continue

		var mesh := _extract_mesh(model_path)
		if not mesh:
			push_warning("No mesh found in: %s (index %d)" % [model_path, i])
			continue

		mesh_library.create_item(i)
		mesh_library.set_item_name(i, model_path.get_file().get_basename())
		mesh_library.set_item_mesh(i, mesh)
		mesh_library.set_item_mesh_transform(i, Transform3D().scaled(CELL_SIZE))

		# Generate trimesh collision from scaled mesh
		var trimesh_shape := _create_scaled_trimesh(mesh, CELL_SIZE)
		if trimesh_shape:
			mesh_library.set_item_shapes(i, [trimesh_shape])

		print("  [%d] %s — mesh + trimesh collision OK" % [i, mesh_library.get_item_name(i)])

	return mesh_library


func _load_map_json() -> Array:
	if not FileAccess.file_exists(MAP_JSON_PATH):
		push_error("Map JSON not found: %s" % MAP_JSON_PATH)
		return []

	var file := FileAccess.open(MAP_JSON_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to open: %s" % MAP_JSON_PATH)
		return []

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		push_error("JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return []

	var data = json.data
	if not data is Dictionary or not data.has("cells"):
		push_error("Invalid JSON format: expected {\"cells\": [...]}")
		return []

	return data["cells"]


func _create_scaled_trimesh(mesh: Mesh, scale: Vector3) -> ConcavePolygonShape3D:
	var scaled := ArrayMesh.new()
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in range(verts.size()):
			verts[v] *= scale
		arrays[Mesh.ARRAY_VERTEX] = verts
		scaled.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return scaled.create_trimesh_shape()


func _extract_mesh(packed_scene_path: String) -> Mesh:
	var packed_scene: PackedScene = ResourceLoader.load(packed_scene_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not packed_scene:
		return null

	var scene_state: SceneState = packed_scene.get_state()
	for i in range(scene_state.get_node_count()):
		if scene_state.get_node_type(i) == "MeshInstance3D":
			for j in range(scene_state.get_node_property_count(i)):
				if scene_state.get_node_property_name(i, j) == "mesh":
					return scene_state.get_node_property_value(i, j)

	return null
