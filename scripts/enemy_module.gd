class_name EnemyModule
extends Node
## 敌人模块基类（ADR 022）。
## 挂为 monster_base 子节点的子节点即可工作。
## 子类覆盖四个生命周期钩子：
##   module_setup(enemy)      — _ready 时调用
##   on_enter_state(state)    — FSM 状态转换后
##   on_tick(delta)           — 每物理帧
##   on_damage(amount)        — 受击时
##   on_death()               — 死亡时
## monster_base._run_module_hook() 通过 has_method 检测，
## 未实现的方法自动跳过。
