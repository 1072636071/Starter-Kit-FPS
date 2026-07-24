# 01 - 建立 step_height 共享常量

Status: resolved
Type: task

## 构建内容

项目首次拥有一个单一来源的 `step_height = 0.3` 常量，作为后续玩家 Auto-Step 与怪物 NavMesh `agent_max_climb` 共同引用的真实源。消除魔数散布。这是预重构工单——本身不产生可演示的端到端行为，但让后续工单不再各自硬编码阈值，保证"统一可通行"语义在两套实现中一致。

参见 [ADR 003](../../../docs/adr/003-step-and-monster-navigation.md)。

## 验收标准

- [ ] 全局可访问的 `step_height` 常量（autoload script 或静态类），默认值 `0.3`
- [ ] [CONTEXT.md](../../../CONTEXT.md) 中 "step_height" 术语条目引用此常量的具体位置
- [ ] 不改动任何现有角色的运行时行为（纯增量，向后兼容）

## 阻塞于

无——可立即开始
