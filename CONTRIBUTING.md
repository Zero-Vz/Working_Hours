# 贡献指南

感谢你对「加班记」项目的关注！以下是参与贡献的流程。

## 开发环境

- Flutter SDK 3.22.0+
- Dart SDK 3.3.0+
- JDK 17
- Android SDK (minSdk 23, targetSdk 34)

## 开发流程

1. Fork 本仓库
2. 创建功能分支：`git checkout -b feature/your-feature`
3. 安装依赖：`flutter pub get`
4. 开发并测试
5. 提交前检查：
   ```bash
   flutter analyze
   flutter test
   ```
6. 提交代码：使用语义化提交信息
   ```
   feat: 添加 XX 功能
   fix: 修复 XX 问题
   refactor: 重构 XX 模块
   docs: 更新 XX 文档
   style: 调整 XX 样式
   ```
7. 推送分支并创建 Pull Request

## PR 规范

- 填写 PR 模板中的所有必填项
- 确保 CI 检查通过（analyze + test + build）
- 一个 PR 只做一件事，保持变更范围最小
- 如有 UI 变更，附带截图或录屏

## 代码风格

- 遵循 [Effective Dart](https://dart.dev/guides/language/effective-dart) 规范
- 使用 `flutter analyze` 检查代码问题
- 文件末尾保留空行
- import 顺序：dart → flutter → package → relative

## 问题反馈

- 使用 GitHub Issues 提交 Bug 或功能建议
- 描述问题时包含：复现步骤、预期行为、实际行为、设备信息
