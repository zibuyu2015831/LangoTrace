# 三端页面清单事实源 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立 `docs/platform-page-inventory.md`，把 iPhone、iPad 和 macOS 当前所有页面、入口、状态、代码路径和审查关注点记录为长期事实源。

**Architecture:** 页面清单放在 `docs/` 根目录，作为跨平台 UI 当前事实源；导航规范继续留在 `docs/spec/002-navigation-and-routing.md`，审查记录继续留在 `docs/review/`。根目录入口文档补充阅读路径，后续 UI 任务必须同步更新页面清单。

**Tech Stack:** Markdown 文档、SwiftUI 代码事实、现有 docs 验证命令。

---

## 状态

Verified

## 文件结构

- Create: `docs/platform-page-inventory.md`
  - 记录三端页面覆盖矩阵、Root phase、共享页面、平台专属页面、临时 sheet / inspector / unavailable 页面、维护规则和验证方法。
- Modify: `docs/README.md`
  - 在目录职责和 UI 阅读路径中加入页面清单事实源。
- Move when verified: `docs/plans/done/2026-05-19-docs-platform-page-inventory.md`

## 任务

### Task 1: 创建页面清单事实源

- [x] 阅读 SwiftUI 页面代码，确认 Root phase、iPhone、iPad、macOS 页面和路由。
- [x] 新建 `docs/platform-page-inventory.md`。
- [x] 每个平台至少记录：页面名称、用户目的、入口、当前状态、主要代码路径、能力边界、审查关注点。

### Task 2: 更新入口文档

- [x] 在 `docs/README.md` 的 UI 设计阅读路径中加入 `platform-page-inventory.md`。
- [x] 在目录职责中说明该文件是跨平台页面事实源。

### Task 3: 验证

- [x] 运行 `find docs -maxdepth 3 -type f | sort`。
- [x] 运行文档 placeholder 扫描，无匹配。
- [x] 运行 `git diff --check`，无输出。
- [x] 运行 `git status --short`，确认 `docs/reference/LangoTrace 首页下一轮优化指导.md` 删除可随本次 commit 一起提交。

## 验证记录

- 2026-05-19：`find docs -maxdepth 3 -type f | sort` 已运行，能看到新增 `docs/platform-page-inventory.md`。
- 2026-05-19：`rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'` 无匹配。
- 2026-05-19：`git diff --check` 无输出。
- 2026-05-19：`git status --short` 显示本次页面清单、入口文档、iOS 听力 sheet 修复和已确认可提交的 reference 删除。
