# 发布文档

本目录用于记录语迹 LangoTrace 的买断制、StoreKit、TestFlight、App Store、版本策略、隐私标签和发布检查清单。

发布相关事项必须从早期开始记录，因为语迹处理日记、照片、音频、AI 请求和本地数据同步，涉及较高隐私与审核风险。

## 当前发布隐私提醒

- 练习跟读录音已经接入麦克风权限。iOS / macOS 的 `NSMicrophoneUsageDescription` 必须说明录音仅用于本地跟读练习，不会自动上传或发送给 AI Provider。
- macOS target 必须保留 App Sandbox audio input entitlement；移除或改名 entitlements 文件时需要同步 `project.yml` 和 App 装配测试。
- 当前练习录音默认 local-only、excluded from default export、不同步、不进入可恢复备份。后续若把用户音频纳入导出、同步、对象存储或 AI 发音评分，必须先创建新的 active plan，并复查 App Store privacy labels、隐私政策、权限文案和删除 / 恢复路径。
- 发布前需要真实 iPhone 和 macOS 本机各完成一次麦克风授权、录音、停止、完成、拒绝授权恢复路径验证；模拟器通过不等于发布级麦克风验收通过。
