# Workflow：新增三端平台页面或入口

适用场景：新增 iPhone、iPad、macOS 页面、设置入口、详情页、sheet、toolbar、sidebar、window scene、菜单命令或跨端共享状态入口。

## 1. 必读文档

- `docs/README.md`
- `docs/plans/README.md`
- `docs/product-main-reference.md` 第 7、8、9 节
- `docs/technical-framework-roadmap.md` 第 10 节
- `docs/platform-page-inventory.md`
- `docs/spec/002-navigation-and-routing.md`
- `docs/spec/003-ui-design-system.md`
- `docs/spec/004-swiftui-architecture.md`
- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/spec/010-apple-platform-interaction-and-accessibility.md`
- `docs/spec/009-testing-and-verification.md`

## 2. 任务方案要求

实现前必须创建或更新 active plan，并明确：

- 页面属于 iPhone、iPad、macOS 独有，还是三端共享内容不同承载。
- 共享状态、action seam、presentation model 和数据源。
- 是否更新 `docs/platform-page-inventory.md`。
- 是否需要本地化 key、Dynamic Type、VoiceOver、键盘、指针或窗口行为验证。
- 是否影响导航与路由规范。
- 页面承载的核心对象属于用户主数据、派生数据、配置对象还是运行期记录；若属于用户主数据，必须检查是否已覆盖基础生命周期，而不是只实现创建、导入或只读展示。

## 3. 关键落点

- UI package：共享 view、platform view、presentation model、helper、unit tests。
- App target：scene、window、root assembly、environment injection。
- Core package：跨端共享模型和状态机。
- `docs/platform-page-inventory.md`：页面事实源。
- `docs/spec/navigation/impl.md` 或相关 impl map：实现地图。

## 4. 测试要求

至少覆盖：

- 状态机、presentation model、routing helper 或 action seam 的单元测试。
- 多端共用能力不出现 iPhone-only、iPad-only 或 macOS-only 的隐性分叉。
- 本地化 key 和目标语言 / 界面语言边界。
- 可访问性标签、Dynamic Type、键盘或指针行为中与本任务相关的部分。

真实点击、截图和模拟器验证可以作为补充，但不能替代可自动化测试。

## 5. 故障与恢复路径

| 故障 | 恢复路径 | 验证 |
| --- | --- | --- |
| 当前语言空间被删除 | 路由回到 onboarding 或 fallback 空态 | routing / state 测试 |
| Shared action 失败 | UI 展示稳定失败态，不丢失本地草稿 | presentation 测试 |
| 平台承载不支持某交互 | 使用该平台原生等价入口 | 平台审查 |
| 本地化缺 key | 测试或脚本拦截 | UI package 测试 |

## 6. 完成前检查

运行相关 UI / Core 聚焦测试；涉及三端页面、导航结构或 App 启动结构时运行 `scripts/verify.sh`。完成前检查 `platform-page-inventory.md` 是否需要同步。

如果页面新增或升级了用户主数据对象入口，还必须回看 `docs/spec/007-data-storage-migration-export-and-attachments.md`：

- 是否定义了创建或导入入口。
- 是否定义了列表 / 查询 / 打开路径。
- 是否评估了更新路径。
- 是否定义了删除、软删除、恢复或受限删除语义。

若本轮只交付其中一部分，active plan 必须写明 deferred 项、原因和后续入口。

## 7. 反例

- 为 iPad 或 macOS 复制一套与 iPhone 不同的数据写入路径。
- 把平台差异写进 Repository、Provider profile 或同步模型。
- 用截图验证替代状态机和 action seam 测试。
- 新增页面但不更新页面清单和导航实现地图。
