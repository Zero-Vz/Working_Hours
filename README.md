# 记工时 Working_Hours

纯离线的加班工时记录、统计与导出应用（Android / Flutter）。

- **不登录、不联网、不申请任何权限**，数据全部保存在本机
- 中文界面，Material 3，支持深色模式（跟随系统 / 浅色 / 深色）
- 仓库地址：<https://github.com/Zero-Vz/Working_Hours.git>

## 功能

| 页面 | 功能 |
| --- | --- |
| 记录列表 | 按日期倒序展示；按月切换/选择月份；按项目/备注/类型搜索；左滑删除（带撤销）；点击进入编辑；顶部显示当月汇总 |
| 新增 / 编辑 | 日期选择器、开始/结束时间选择器；自动计算时长并支持跨天（+24h）；加班类型（工作日 ×1.5 / 休息日 ×2 / 节假日 ×3 / 自定义倍率）；项目、备注；是否调休、是否已结算；保存前校验 |
| 统计 | 本月总加班时长、本月折算工时、本月预计加班费；按加班类型汇总；年度趋势折线图；月度每日柱状图 |
| 设置 | 时薪、各类型默认倍率、默认项目；是否扣除休息时间（可设分钟数）；折算工时是否四舍五入到分钟；主题外观；导出 CSV / 导入 CSV / 清空所有数据 |

## 技术栈

- Flutter 3.22+ / Dart 3（本地与 CI 固定 **3.24.5**）
- 状态管理：Riverpod（`flutter_riverpod`）
- 本地数据库：Hive（离线优先，手写 TypeAdapter，无需代码生成）
- 图表：`fl_chart`
- 导出：`csv` + `share_plus`；导入：`file_picker`（系统文件选择器，无需存储权限）
- 日期格式化：`intl`
- Android：`minSdk 23` / `targetSdk 34` / `compileSdk 34`

## 目录结构

```
Working_Hours/
├── .github/
│   └── workflows/
│       └── build-apk.yml          # GitHub Actions：编译 arm64-v8a APK
├── android/                        # Android 工程（Groovy Gradle）
│   ├── app/
│   │   ├── build.gradle            # minSdk 23 / targetSdk 34 / applicationId
│   │   └── src/main/AndroidManifest.xml   # 应用名「记工时」，无任何权限
│   ├── build.gradle
│   ├── settings.gradle
│   └── gradle.properties
├── lib/
│   ├── main.dart                   # 入口：初始化 Hive 并注册 Adapter
│   ├── app.dart                    # MaterialApp（Material 3 / 中文 / 深色模式）
│   ├── core/
│   │   ├── constants.dart          # 加班类型、Box 名称、版本号
│   │   ├── theme/app_theme.dart    # 浅色 / 深色主题
│   │   └── utils/
│   │       ├── time_utils.dart     # 时间解析、跨天时长、格式化、YearMonth
│   │       └── calc.dart           # 折算工时 / 金额计算规则
│   ├── data/
│   │   ├── models/
│   │   │   ├── overtime_record.dart   # 数据模型 + 手写 Hive TypeAdapter
│   │   │   └── app_settings.dart      # 设置模型（读写 settings Box）
│   │   └── csv/
│   │       └── record_csv_service.dart  # 导出 / 解析 CSV
│   ├── providers/
│   │   ├── records_provider.dart   # 记录增删改查、导入去重、金额重算
│   │   ├── settings_provider.dart  # 设置项
│   │   ├── filter_provider.dart    # 月份筛选、项目搜索
│   │   └── stats_provider.dart     # 月度 / 年度 / 每日统计
│   └── ui/
│       ├── home/home_shell.dart    # 底部导航（记录 / 统计 / 设置）
│       ├── records/record_list_page.dart
│       ├── records/record_edit_page.dart
│       ├── stats/stats_page.dart
│       └── settings/settings_page.dart
├── test/
│   └── calc_test.dart              # 时长 / 折算 / 金额 / CSV 单元测试
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

## 本地运行

```bash
# 1) 安装 Flutter 3.22+（本项目在 3.24.5 上验证）
flutter --version

# 2) 获取依赖
flutter pub get

# 3) 静态检查 + 单元测试
flutter analyze
flutter test

# 4) 连接设备 / 模拟器运行
flutter run
```

## 构建 APK

```bash
# 生成所有 ABI 的 APK
flutter build apk --release

# 只生成 64 位 arm64-v8a（推荐，体积更小）
flutter build apk --release --split-per-abi
```

产物路径：

```
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk     # arm64-v8a
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk   # armeabi-v7a
```

> Release 使用 debug 签名即可直接安装；如需自有签名，在
> `android/app/build.gradle` 的 `release` 中配置 `key.properties` 即可。

> **Windows 提示**：Android Gradle Plugin 默认禁止工程路径包含中文等非 ASCII 字符
> （本项目已在 `android/gradle.properties` 中加入 `android.overridePathCheck=true` 放行该检查），
> 但 Flutter 的 Dart AOT 快照器 / impellerc 在 Windows 下仍无法处理中文路径。
> 因此**本机编译请把项目放在纯英文路径**（如 `D:\projects\Working_Hours`）。
> GitHub Actions 的工作目录为纯 ASCII 路径，完全不受影响。

## GitHub Actions 自动构建

推送到仓库后，`.github/workflows/build-apk.yml` 会自动：

1. 安装 JDK 17 与 Flutter 3.24.5（缓存依赖）
2. `flutter pub get` → `flutter analyze` → `flutter test`
3. `flutter build apk --release --split-per-abi`
4. 上传 `working-hours-apk` 制品，其中
   **`Working_Hours-arm64-v8a-release.apk` 即为 v8a 安装包**（保留 30 天）

手动触发：仓库页 → **Actions** → **Build APK** → **Run workflow**。

也可以在本机执行 `gh workflow run build-apk.yml`。

### 首次推送

```bash
git add .
git commit -m "feat: 记工时 v1.0.0"
git branch -M main
git remote add origin https://github.com/Zero-Vz/Working_Hours.git
git push -u origin main
```

## 计算规则

| 项目 | 规则 |
| --- | --- |
| 时长 | `结束时间 - 开始时间`；结束时间早于等于开始时间时自动 **+24 小时**（跨天）；结束时间等于开始时间为非法输入，保存时拦截 |
| 折算工时 | `实际时长（可扣除休息时间） × 倍率`；开启「四舍五入到分钟」时先按分钟取整再换算小时 |
| 预计加班费 | `折算工时 × 时薪`，保留两位小数 |
| 金额重算 | 修改时薪 / 休息 / 取整设置时，历史记录金额按新规则自动重算 |

各类型默认倍率：工作日 1.5、休息日 2.0、节假日 3.0、自定义 1.0（均可在设置页修改）。

## CSV 格式

导出文件带 UTF-8 BOM（Excel 可直接打开中文），表头：

```csv
id,date,startTime,endTime,durationMinutes,type,rate,project,note,isCompensatory,isSettled,amount,createdAt,updatedAt
7,2026-10-05,18:00,02:30,510,休息日,2.0,机房割接,跨天加班,false,true,566.67,2026-10-05T09:30:00.000,2026-10-05T09:30:00.000
```

导入时按 `日期 + 起止时间 + 项目 + 类型` 去重，重复记录自动跳过。

## 数据与隐私

- 无网络权限（release 清单中无 `INTERNET` 等任何权限声明）
- 数据存放在应用私有目录的 Hive 文件中，卸载应用即删除
- 导出 CSV 通过系统分享面板完成，导入通过系统文件选择器完成
