# 加班记

一款简洁实用的加班工时记录与统计应用，支持离线使用，数据完全存储在本地。

## 功能特性

- **加班记录** — 记录每次加班的日期、起止时间、类型、项目、备注
- **三种加班类型** — 工作日(1.5 倍)、休息日(2 倍)、节假日(3 倍)，倍率可自定义
- **自动计算** — 跨天时长自动识别，折算工时与加班费实时计算
- **月度统计** — 按月汇总加班时长、折算工时、加班费，分类统计
- **年度图表** — fl_chart 折线图展示年度趋势，柱状图展示月度加班费
- **数据导出** — CSV 格式导出，通过系统分享发送
- **数据导入** — 粘贴 CSV 文本批量导入记录
- **深色模式** — 跟随系统自动切换，Material 3 设计语言

## 计算规则

| 项目     | 公式                             |
| -------- | -------------------------------- |
| 加班时长 | 结束时间 - 开始时间（跨天 +24h） |
| 折算工时 | 加班时长 × 倍率                  |
| 加班费   | 折算工时 × 时薪                  |

## 技术栈

| 技术                   | 用途       |
| ---------------------- | ---------- |
| Flutter 3.22+ / Dart 3 | 应用框架   |
| Riverpod               | 状态管理   |
| sqflite                | 本地数据库 |
| fl_chart               | 图表展示   |
| csv + share_plus       | 导入导出   |

## 项目结构

```
lib/
├── main.dart                 # 程序入口
├── app.dart                  # Material3 主题与导航
├── models/                   # 数据模型
├── database/                 # 数据库层
├── providers/                # 状态管理
├── screens/                  # 页面
│   ├── record_list_screen    # 记录列表
│   ├── record_form_screen    # 新增/编辑
│   ├── statistics_screen     # 统计图表
│   └── settings_screen       # 设置
├── utils/                    # 工具类
└── widgets/                  # 通用组件与图表
```

## 本地开发

### 环境要求

- Flutter SDK 3.22.0+
- Dart SDK 3.3.0+
- Android SDK (minSdk 23, targetSdk 34)
- JDK 17

### 构建步骤

```bash
# 1. 克隆仓库
git clone https://github.com/<your-username>/Working_Hours.git
cd Working_Hours

# 2. 配置本地 SDK 路径
echo "flutter.sdk=$(which flutter)" > android/local.properties

# 3. 安装依赖
flutter pub get

# 4. 运行分析
flutter analyze

# 5. 运行测试
flutter test

# 6. 构建 arm64-v8a APK
flutter build apk --release --target-platform android-arm64
```

构建产物位于 `build/app/outputs/flutter-apk/app-release.apk`。

## GitHub Actions CI/CD

推送到 `main` 或 `develop` 分支时自动触发构建：

- 代码分析 → 单元测试 → 构建 arm64-v8a APK
- APK 作为 Artifact 可下载（保留 30 天）
- `main` 分支推送自动创建 GitHub Release

也可在 Actions 页面手动触发构建（workflow_dispatch）。

## 截图

> 待补充

## 许可证

MIT License
