# 页面地图

## iPhone

平台：iPhone
页面 / 入口：Welcome
当前状态：只读说明 / 自动跳转
对应产品对象：Settings / Privacy
主要动作：650ms 后进入下一启动阶段
外部请求或权限风险：无真实请求，但过早显示 AI 未配置状态
审核结论：调整

平台：iPhone
页面 / 入口：Onboarding / 创建语言空间
当前状态：真实内存状态
对应产品对象：Space
主要动作：选择母语、目标语言、水平，自建第一个语言空间
外部请求或权限风险：无
审核结论：保留结构，精简说明文案

平台：iPhone
页面 / 入口：今日
当前状态：Local Mock
对应产品对象：Entry / Rendering / Practice
主要动作：创建记录、查看最近记录、进入详情
外部请求或权限风险：无，photo / listen 为 unavailable
审核结论：与记录合并为默认记录工作台

平台：iPhone
页面 / 入口：记录
当前状态：Local Mock
对应产品对象：Entry
主要动作：创建记录、查看 Entry 列表
外部请求或权限风险：无
审核结论：与今日合并

平台：iPhone
页面 / 入口：练习
当前状态：Local Mock
对应产品对象：Practice
主要动作：进入 mock PracticeSession
外部请求或权限风险：无
审核结论：保留，需从显性 Rendering 状态出发

平台：iPhone
页面 / 入口：记忆
当前状态：Local Mock / unavailable
对应产品对象：Memory
主要动作：查看 mock memory，查看 vector index unavailable
外部请求或权限风险：无
审核结论：保留，补三层记忆模型和来源回溯

平台：iPhone
页面 / 入口：设置 Tab
当前状态：只读说明 / Local Mock
对应产品对象：Settings
主要动作：查看能力说明
外部请求或权限风险：无
审核结论：降级为 toolbar / 语言空间菜单 / 系统设置入口

平台：iPhone
页面 / 入口：Entry 创建 sheet
当前状态：Local Mock
对应产品对象：Entry
主要动作：保存内存 Entry
外部请求或权限风险：无
审核结论：保留，补 TextEditor label、dismiss 保护和真实保存边界

平台：iPhone
页面 / 入口：Entry detail
当前状态：Local Mock
对应产品对象：Entry / Rendering / Practice / Memory
主要动作：查看母语记录、目标语言文本、句子对照、练习入口
外部请求或权限风险：无，RequestPreviewCard 显示 Local Mock
审核结论：重构 Rendering 状态层级

## iPad

平台：iPad
页面 / 入口：顶部工作台工具条
当前状态：Local Mock / unavailable
对应产品对象：Entry / Search / Panels
主要动作：新建记录、搜索说明、左右面板切换
外部请求或权限风险：无
审核结论：保留但补 shortcut / toolbar 语义和窄宽度策略

平台：iPad
页面 / 入口：左侧时间线 / 筛选 / Pages
当前状态：Local Mock
对应产品对象：Entry / Memory / Settings
主要动作：选择 Entry、筛选、进入 Memory / ImportExport / Settings
外部请求或权限风险：无
审核结论：重构，时间线和配置入口分离

平台：iPad
页面 / 入口：中间工作区
当前状态：Local Mock
对应产品对象：Entry / Rendering / Practice / Memory
主要动作：阅读双语内容、进入练习
外部请求或权限风险：无
审核结论：保留，补宽度断点和主内容优先策略

平台：iPad
页面 / 入口：右侧学习面板
当前状态：Local Mock
对应产品对象：Rendering / Practice / Memory / Settings
主要动作：查看句子解释、记忆候选、练习状态、请求预览
外部请求或权限风险：无
审核结论：从功能清单改为状态驱动 Inspector

## macOS

平台：macOS
页面 / 入口：Sidebar
当前状态：Local Mock / unavailable
对应产品对象：Entry / Practice / Memory / Settings
主要动作：切换 Today / Entries / Practice / Memory / ImportExport / Settings
外部请求或权限风险：无
审核结论：重构为内容域 source list，移出 Settings 和 ImportExport

平台：macOS
页面 / 入口：Toolbar
当前状态：Local Mock / unavailable
对应产品对象：Panels / Search / Entry
主要动作：切换 Sidebar / Inspector、搜索、创建记录
外部请求或权限风险：无
审核结论：保留并补 commands、keyboard shortcuts、Settings scene

平台：macOS
页面 / 入口：Inspector
当前状态：Local Mock
对应产品对象：Rendering / Memory / Settings
主要动作：显示请求预览、元数据、记忆候选、设置说明
外部请求或权限风险：无
审核结论：保留，增加上下文动作和更紧凑密度

平台：macOS
页面 / 入口：底部 AI / Sync / Settings 图标
当前状态：只读说明 / Local Mock / unavailable
对应产品对象：AI Provider / Sync / Settings
主要动作：进入对应设置详情或设置 overview
外部请求或权限风险：无
审核结论：拆分语义，AI / Sync 作为状态入口，gear 作为通用设置

## 共享组件

- `LanguageSpaceFooter`：保留，改为 Space summary / 状态入口，不再让语言空间成为纯 unavailable 死路。
- `EntryTimelineRow`：保留，补 hover / focus / Dynamic Type 和来源回溯。
- `SentencePairView`：保留，Listen 不能空 action，补 compact 布局。
- `RequestPreviewCard`：保留，移动到用户触发 Rendering 前可见的位置。
- `CapabilityStatusRow` / `CapabilityStatusBadge`：保留，重建状态矩阵。
- `UnavailableCapabilityView`：保留，改为可访问 modal / empty-state pattern。
