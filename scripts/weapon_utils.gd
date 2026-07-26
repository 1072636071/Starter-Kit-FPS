class_name WeaponUtils
## 武器工具类：共享的武器资源加载逻辑
##
## 提供 static func load_all_weapons() -> Array[Weapon]
## 扫描 res://weapons/ 目录下所有 .tres 文件并返回 Weapon 数组。
## shop_ui.gd 和 run_director.gd 共用此方法，消除重复代码。
extends RefCounted

## 加载 res://weapons/ 目录下所有 .tres 武器资源
static func load_all_weapons() -> Array[Weapon]:
	var pool: Array[Weapon] = []
	var dir := DirAccess.open("res://weapons/")
	if dir == null:
		return pool
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var res: Resource = load("res://weapons/" + fname)
			if res is Weapon:
				pool.append(res)
		fname = dir.get_next()
	dir.list_dir_end()
	return pool
