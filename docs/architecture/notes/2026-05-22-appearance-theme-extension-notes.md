# 外观与主题扩展开发备忘录

状态：Accepted
创建日期：2026-05-22
适用范围：后续多品牌色、字体、阅读排版、交互样式、动效密度、可访问性外观、主题同步和三端主题架构设计。

## 1. 目的

本文记录浅色 / 深色外观基础设施为后续主题能力留下的架构边界。当前任务只实现 `跟随系统 / 浅色 / 深色`，不实现多套品牌色、字体主题或交互样式切换。

本文不是实施方案，不替代 `docs/plans/active/` 中的任务方案，不替代 `docs/spec/003-ui-design-system.md`，也不替代未来可能新增的 ADR。后续一旦要实现多主题、字体或交互样式，应先读取本文，再创建独立任务方案，并把被采纳的结论提升到 spec、正式 architecture 文档或 ADR。

## 2. 当前外观方案留下的扩展点

- `AppearancePreference` 只表达系统 / 浅色 / 深色，不承担完整主题身份。
- `UserDefaultsAppearancePreferenceStore` 是设备级偏好入口，说明当前外观不是语言空间主数据。
- `LangoTraceDesign` 应从静态 RGB token 演进为语义 palette 入口，为未来多主题保留替换点。
- 设置页使用 `外观 / Appearance` 作为用户可见入口，可以在未来扩展到更完整的显示偏好，但不应在当前阶段让用户误以为已有多套主题。
- `SettingsCapability.Kind.appearance` 可以承载外观设置；未来若出现复杂主题编辑器，应评估是否继续放在同一详情页，还是拆为独立高级设置页。
- `preferredColorScheme(_:)` 只解决浅色 / 深色外观，不解决品牌色、字体、密度、动效或阅读排版。
- 当前 `SettingsCapabilityDetailView` 以当前语言空间为默认详情上下文；外观和界面语言属于全局设备偏好，后续主题系统应继续把 global preference 和 language-space-scoped configuration 分开。
- 当前 `LangoTraceDesign.ColorToken` 的静态调用面可以作为兼容 facade，但它不是未来主题引擎本身。未来多主题若需要在运行期切换品牌 palette，需要环境化 resolver、theme registry 或等价注入机制。
- 2026-05-23 已审核通过的浅色 / 深色色号属于当前外观基础设施方案的实现基准，记录在 `docs/plans/active/2026-05-22-feature-appearance-light-dark-foundation.md`；它们不是未来多品牌主题注册表，也不代表字体、排版或交互样式主题已经决策。

## 3. 后续主题系统必须重新决策的问题

### 3.1 主题身份与外观模式是否分离

推荐分离：

```text
AppearancePreference
  system
  light
  dark

ThemeID
  standard
  ...
```

理由：

- 浅色 / 深色是系统外观模式。
- 主题是品牌色、阅读质感和组件语气的组合。
- 一个主题通常需要同时提供浅色和深色 palette。
- 如果把 `dark` 当作主题，将来会出现 `standardDark`、`blueDark`、`readerDark` 等混乱命名。

后续需要决策：

- 是否允许用户选择主题后仍跟随系统浅深色。
- 每个主题是否必须提供 light / dark / high contrast 变体。
- 是否允许主题只影响强调色，而不影响背景和文本。

### 3.2 字体与阅读排版是否属于主题

推荐不要把字体直接混入颜色主题。后续可以单独评估：

```text
TypographyProfile
  systemReadable
  studyDense
  writingComfort

ReadingProfile
  default
  largeLineHeight
  compactReview
```

理由：

- LangoTrace 的核心场景包括写作、双语对照、句子练习和记忆复习，字体和行距会直接影响可读性与学习效率。
- 字体偏好比颜色更容易触碰 Dynamic Type、VoiceOver、混合语言显示和目标语言文本朗读边界。
- 中文、日文、韩文、拉丁语系和未来 RTL 的字体策略不一定相同。

后续需要决策：

- 字体配置是 App 级、设备级，还是按阅读场景局部配置。
- 是否允许对母语文本和目标语言文本使用不同字体 fallback。
- 是否允许用户调节练习区与记录区的字号密度。
- 如何保证 Dynamic Type 仍是优先级更高的系统可访问性设置。

### 3.3 交互样式与动效密度是否可配置

推荐把交互样式与颜色主题分开。后续可以单独评估：

```text
InteractionProfile
  platformDefault
  focused
  compact

MotionProfile
  system
  reduced
```

理由：

- iPhone、iPad、macOS 的输入方式不同，交互密度不能用同一个皮肤开关控制。
- Reduce Motion 是系统可访问性设置，应被尊重，不能被主题覆盖。
- 语迹需要长期学习工具感，不能让“主题”变成过度动画或游戏化入口。

后续需要决策：

- 是否需要用户级“专注模式”密度，而不是主题密度。
- 是否让 macOS 支持更紧凑列表，而 iPhone 保持 44pt 触控底线。
- 交互样式是否允许按设备不同步。

### 3.4 是否按语言空间保存主题

推荐默认不按语言空间保存主题。

理由：

- 语言空间是一门目标语言的学习档案，主题是设备使用偏好。
- 用户切换英语空间和日语空间时，不应出现整个 App 突然换肤的意外。
- 如果未来要按语言区分视觉提示，应优先用轻量 language accent 或空间标识，而不是完整主题。

后续需要决策：

- 是否需要语言空间级 accent color。
- accent 是否只用于空间标识，不影响状态色和危险色。
- 多空间同目标语言时 accent 如何避免误导。

### 3.5 外观和主题是否同步

推荐第一版不自动同步外观偏好。

理由：

- 外观选择常受设备环境影响，例如 iPhone 夜间使用、Mac 白天工作。
- iPad Stage Manager、macOS 多窗口和 iPhone 单手使用的视觉密度不完全相同。
- 同步主题会引入“设备 A 切换深色导致设备 B 改变”的意外。

后续需要决策：

- 是否提供“在设备间同步外观偏好”的显式开关。
- 同步的是 `AppearancePreference`、`ThemeID`，还是只同步自定义主题定义。
- 如果用户在设备 B 没有某个自定义字体或主题资源，fallback 规则是什么。

## 4. 未来主题注册表候选模型

如果后续实现多主题，推荐引入只读注册表，而不是在 UI 中散落主题定义：

```text
ThemeRegistry
  theme(id)
  allThemes

LangoTraceTheme
  id
  localizedNameKey
  lightPalette
  darkPalette
  highContrastLightPalette
  highContrastDarkPalette
  allowedAccentRoles
```

注册表需要回答两个层次的问题：

```text
AppearancePreference
  controls system / light / dark rendering mode

ThemeSelection
  controls selected visual identity, if such a feature exists later

ResolvedTheme
  resolved from ThemeSelection + current ColorScheme + accessibility contrast
```

原则：

- 每个主题必须提供浅色和深色 palette。
- 每个主题必须说明高对比策略。
- 状态色 role 不能被任意主题重写为含义冲突的颜色。
- 主题注册表属于 UI / design system 层，不进入 Core 学习模型。
- 用户自定义主题如果出现，应另建持久化模型和导出边界，不直接复用静态注册表。
- 如果继续保留 `LangoTraceDesign.ColorToken.*` 作为调用面，它应从当前环境 resolver 取值，而不是继续依赖编译期固定 `static let` 来表达用户可切换主题。

## 5. 不应提前实现的内容

当前浅色 / 深色任务不应提前实现：

- `ThemeID` 持久化字段。
- `ThemeSelection`、`ResolvedTheme` 或环境化 theme registry。
- 用户自定义主题编辑器。
- 自定义字体导入。
- 主题资源同步。
- 主题市场或主题包。
- 按语言空间自动换主题。
- 用主题覆盖 AI、同步、隐私、危险操作、错误状态的语义色。
- 把动效、音效、触感反馈与颜色主题强绑定。

## 6. 可访问性硬约束

后续任何主题扩展都必须保持：

- 文字对比度在浅色、深色和高对比环境下可读。
- 选中、错误、警告、不可用、本地预览、隐私本地、隐私外发不能只靠颜色表达。
- Dynamic Type 优先级高于主题字号。
- Reduce Motion 优先级高于主题动效。
- iPhone 和 iPad 触控目标不低于 44pt。
- macOS 保留键盘焦点、hover、菜单和窗口语义。
- 主题不得改变 AI 请求、同步、权限、Keychain、导出和隐私说明的真实边界。

## 7. 文档提升条件

以下任一情况出现时，应把本文部分内容提升到正式 spec、architecture 或 ADR：

- 准备实现多套品牌色。
- 准备支持字体或排版配置。
- 准备同步外观或主题偏好。
- 准备允许每个语言空间设置 accent 或主题。
- 准备引入用户自定义主题。
- 准备改变 `LangoTraceDesign` 的公共 token API。
- 准备把主题能力作为付费功能或 App Store 展示卖点。

## 8. 后续任务建议

后续任务方案至少应回答：

- 当前任务改变的是外观模式、主题身份、字体、密度，还是动效。
- 偏好归属是设备级、App 级、窗口级、语言空间级，还是同步级。
- 是否尊重系统浅深色、Increase Contrast、Reduce Motion 和 Dynamic Type。
- 是否会影响 AI / Sync / Privacy / Error 等状态色语义。
- 三端设置入口是否共享一套详情内容。
- 该偏好是否允许在没有当前语言空间时展示和修改。
- 当前 `ColorToken` facade 是否足够，还是需要正式引入环境化 theme registry。
- 是否需要截图、伪本地化、高对比和 VoiceOver 验证。

## 9. 当前阶段结论

当前阶段应只实现浅色 / 深色外观基础设施，并保持：

- 用户入口叫 `外观 / Appearance`。
- 用户选项限制为 `跟随系统 / 浅色 / 深色`。
- 外观偏好为设备级本地偏好。
- 颜色 token 走语义 palette。
- 多品牌色、字体、交互样式和同步主题另开任务重新决策。
- 无语言空间时仍允许修改外观；不得为外观伪造语言空间。
- 本轮 light / dark palette 不是完整主题注册表；未来多主题必须新增明确的环境解析边界。

## 10. 严格审查记录

- 2026-05-22：基于当前代码审查后确认，`SettingsCapabilityDetailView` 当前强依赖 `LanguageSpacePreview`，而 `LangoTraceSettingsSceneView` 只为界面语言提供 placeholder。外观设置必须提升为全局详情上下文，不能复用语言空间 placeholder。
- 2026-05-22：基于当前 `LangoTraceDesign.ColorToken` 审查后确认，静态 token facade 可保留以降低迁移成本，但它不能被当作未来多主题引擎。未来主题系统必须有 `ThemeSelection` / `ResolvedTheme` / `ThemeRegistry` 或等价 resolver。
