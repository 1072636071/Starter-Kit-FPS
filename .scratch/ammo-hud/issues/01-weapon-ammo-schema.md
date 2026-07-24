Status: ready-for-agent
Blocked by: 无

# T1 — 武器弹药 schema 与配置

## 构建内容

`Weapon` 资源类新增 `display_name`（中文名）、`magazine_size`、`max_reserve`、`reload_time` 四个属性；两把武器 `.tres` 填入参数；`project.godot` 注册 `reload` 输入动作（R 键）。

## 验收标准

- [ ] `weapon.gd` 新增 4 个 `@export` 字段，含类型与默认值
- [ ] `blaster.tres`：display_name="爆能枪"、magazine_size=8、max_reserve=40、reload_time=1.5
- [ ] `blaster-repeater.tres`：display_name="连发枪"、magazine_size=24、max_reserve=96、reload_time=1.2
- [ ] `project.godot` 新增 `reload` 动作绑定 R 键

## 评论
