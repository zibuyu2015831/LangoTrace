# 架构文档

本目录用于记录语迹 LangoTrace 的工程架构、模块边界、数据模型、同步模型、AI Provider、长期记忆和安全边界。

架构文档描述“系统如何组织”，不替代 ADR。若涉及重要取舍，应在 `docs/decisions/` 中另写决策记录。

当前快速入口：

- [当前系统地图](002-system-map.md)：记录系统形态、App / Package 入口点、关键运行时对象、关键数据流、模块依赖方向、禁止反向依赖和故障恢复矩阵索引。系统地图是当前工程结构入口，不替代 ADR、spec 或任务方案。

`notes/` 子目录用于保存架构级开发备忘录。它记录尚未进入正式架构文档、spec、ADR 或任务方案的跨任务扩展提醒。创建涉及数据、同步、AI Provider、权限、附件、导出、StoreKit、三端架构或长期记忆的任务方案前，应检查 `notes/` 中是否有相关设计输入。

后续系统级架构文档应尽量覆盖：

- 系统形态和关键运行时边界。
- App、Package、Provider、Data、Speech、Sync 和平台 UI 的入口点。
- 关键数据流，例如启动恢复、语言空间切换、Entry 写入、AI 生成、TTS 生成 / 播放、导出和未来同步。
- 模块依赖方向和禁止反向依赖。
- 已知故障与恢复路径，以及对应测试或手动验证。

该要求吸收 VMark `dev-docs/architecture.md` 的系统地图经验，但 LangoTrace 的权威关系仍以本目录、`docs/spec/` 和 `docs/decisions/` 为准。
