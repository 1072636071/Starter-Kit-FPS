Status: completed
Blocked by: T1, T2, T3

# T4 — 领域模型更新与 ADR 020

## 构建内容

1. **创建 ADR 020**（`docs/adr/020-melee-slash-vfx.md`）：记录近战剑弧粒子特效的架构决策
   - 技术选型：GPUParticles3D vs 其他方案（Mesh+Shader、AnimatedSprite3D、半透明盒子、地面圈）
   - 配色与渲染层分离：玩家青白/layer 2 vs 敌人红橙/layer 3
   - 触发时机：与伤害结算活跃帧同步
   - 粒子行为参数：发射盒尺寸、方向、扩散、阻尼、重力
   - 性能评估：峰值 ~480 粒子，GPU 端计算

2. **更新 CONTEXT.md**：在「近战系统（Melee）」术语表中新增两个术语
   - **Melee Slash VFX（近战剑弧特效）**：定义剑弧拖尾粒子特效的概念、配色、渲染层、生命周期、引用 ADR 020
   - **MeleeVFX（近战特效工具类）**：定义 `MeleeVFX` 静态工具类的职责和两个静态方法签名

## 验收标准

- [x] ADR 020 包含完整的决策、背景、替代方案对比表、影响分析
- [x] ADR 020 列出新增/修改的文件清单和渲染层分配
- [x] CONTEXT.md「Melee Slash VFX」术语包含玩家/敌人配色、渲染层、粒子数量、引用 ADR 020
- [x] CONTEXT.md「MeleeVFX」术语包含 `create_slash()` 和 `trigger()` 两个静态方法签名
- [x] 术语与代码实现一致（无词汇表与代码的矛盾）

## 完成备注

- ADR 020 遵循现有 ADR 格式（参考 ADR 019），包含决策、背景、替代方案、影响四部分
- 替代方案表对比了 5 种方案（GPUParticles3D、Mesh+Shader、AnimatedSprite3D、半透明盒子、地面圈），注明否决原因
- CONTEXT.md 新增术语插入在「Melee Cooldown Implementation」之后、「怪物武器与动画」之前