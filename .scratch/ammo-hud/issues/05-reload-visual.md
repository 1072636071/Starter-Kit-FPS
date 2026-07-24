Status: ready-for-agent
Blocked by: 03, 04

# T5 — 换弹视觉（武器动画 + HUD 进度条）

## 构建内容

换弹期间武器模型经 Tween 移出视野再归位（复用 Container 动画机制，不切换模型）；右下角弹药处显示换弹进度条，随 `reload_time` 实时填充。

## 验收标准

- [ ] 复用 `container` Tween 实现换弹装填动画（区别于切枪动画）
- [ ] HUD 列表内当前武器行显示换弹进度条
- [ ] 验收：换弹可见武器动作 + 进度条读满

## 评论
