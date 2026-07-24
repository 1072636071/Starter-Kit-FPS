extends Node

## 全局地形分类阈值。
##
## 区分 Step（< step_height 的垂直高差，玩家与怪物均可不跳跃通过）
## 与 Wall（≥ step_height 的高差，阻挡玩家须跳、怪物不可达）。
##
## 玩家 Auto-Step 与怪物 NavMesh 的 agent_max_climb 共同引用此常量，
## 保证"统一可通行"语义在两套实现中一致。
##
## 参见：
##   - docs/adr/003-step-and-monster-navigation.md
##   - CONTEXT.md "step_height" 与 "Auto-Step" 术语条目

const STEP_HEIGHT: float = 0.3
