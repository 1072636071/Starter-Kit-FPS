# 01 — 武器纹理恢复

Status: done

## 父 issue

`.scratch/arena-fixes/PRD.md`

## 构建内容

玩家在游戏中看到两把枪（爆能枪、连发枪）显示正确的彩色纹理，而非纯灰/白色。切枪时两把枪均有颜色。

## 验收标准

- [ ] `models/weapons/Textures/colormap.png` 文件存在（从 `models/environment/Textures/colormap.png` 复制）
- [ ] 在 Godot 编辑器中重新导入 `blaster.glb` 和 `blaster-repeater.glb` 后无纹理加载错误
- [ ] 运行游戏，第一人称视野中爆能枪显示彩色纹理
- [ ] 切换到连发枪（E 键），连发枪同样显示彩色纹理
- [ ] 无 Godot 输出面板中关于 colormap.png 的加载警告

## 阻塞于

无——可立即开始。
