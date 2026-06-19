# interface-localization 实现地图

状态：Current Implementation Map

最后更新：2026-05-18

## 1. 对应规范

- `docs/spec/006-interface-localization-and-language-boundaries.md`
- `docs/spec/interface-localization/2026-05-17-string-catalog-interface-language-settings-design.md`
- `docs/spec/interface-localization/2026-05-18-interface-language-expansion-design.md`
- `docs/testing/README.md`

## 2. 当前实现

- Core 偏好模型：`Packages/LangoTraceCore/Sources/LangoTraceCore/InterfaceLanguagePreference.swift`
- UI 语言环境和本地化封装：`Packages/LangoTraceUI/Sources/LangoTraceUI/`
- String Catalog：`Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings`
- App target 本地化声明：`project.yml`
- 验证入口：`scripts/verify.sh` 和 `docs/testing/README.md`

当前已经实现：

- `system / en / zh-Hans / es / ja / fr / de / ko / ru` 的偏好值。
- iOS 和 macOS target 的 `CFBundleLocalizations` 8 语言声明。
- App 内界面语言设置的基础 UI 和测试覆盖。
- 英文、简体中文的主要界面 chrome 验证记录。

## 3. 已知偏差

- String Catalog 仍未覆盖新增 6 种语言的所有 key，因此多语言扩展状态是 Partially Implemented。
- App 内显式语言只覆盖语迹自有 SwiftUI chrome，不覆盖权限弹窗、StoreKit、文件选择器、系统 Settings、App Store 元数据或第三方 UI。
- 当前没有发布级 8 语言截图和人工审校记录。

## 4. 复查方法

```bash
swift test --package-path Packages/LangoTraceCore
swift test --package-path Packages/LangoTraceUI
jq '[.strings | to_entries[] | select(([.value.localizations["es"], .value.localizations["ja"], .value.localizations["fr"], .value.localizations["de"], .value.localizations["ko"], .value.localizations["ru"]] | any(. == null)))] | length' Packages/LangoTraceUI/Sources/LangoTraceUI/Resources/Localizable.xcstrings
scripts/verify.sh
```

如果只改文档，按 `docs/README.md` 的文档检查命令收口。
