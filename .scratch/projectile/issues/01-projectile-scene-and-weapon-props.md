# 01 - 弹体场景与 Weapon 属性扩展

Status: resolved
Type: task

## 构建内容

新增一个可独立预览的发光胶囊体弹体场景（含飞行脚本），同时 Weapon 资源类新增弹体配置属性（颜色、大小、速度）。完成后，在编辑器中打开弹体场景即可看到发光胶囊体效果。

## 验收标准

- [ ] 新增 `objects/projectile.tscn` 场景，包含发光拉伸胶囊体（CapsuleMesh + emission 材质）
- [ ] 弹体脚本实现从起点飞向目标点的逻辑，到达后自动销毁
- [ ] 弹体飞行速度可配置（默认 80-120 m/s 范围）
- [ ] Weapon 资源类新增 `projectile_color`（Color）、`projectile_size`（Vector3）、`projectile_speed`（float）属性
- [ ] 弹体场景在编辑器中可独立预览，发光效果可见

## 阻塞于

无——可立即开始
