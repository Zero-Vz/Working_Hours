# 记工时 Working_Hours

纯离线的加班工时记录、统计与导出应用（Android / Flutter）。

- **不登录、不联网、不申请任何权限**，数据全部保存在本机
- 中文界面，Material 3，支持深色模式（跟随系统 / 浅色 / 深色）
- 仓库地址：<https://github.com/Zero-Vz/Working_Hours.git>

## 功能

| 页面 | 功能 |
| --- | --- |
| 记录列表 | **按天 / 按月两种查看方式**（点日期选精确日期后只显示当天记录，也可一键切回整月）；‹ › 按天或按月前后翻页；按项目/备注/类型搜索；左滑删除（带撤销）；点击进入编辑；顶部按当前筛选范围汇总（含休息扣除提示）；**按月批量标记 / 取消「已结算」** |
| 新增 / 编辑 | 日期选择器、开始/结束时间选择器，或**固定时长模式**（30分钟 ~ 23小时59分，含 3 小时、8 小时等快捷值，结束时间自动算出）；自动计算时长并支持跨天（+24h）；**按日历自动选定加班类型与倍率**（法定节假日→节假日 ×3、周末/放假连休→休息日 ×2、调休补班日→工作日 ×1.5、平日→工作日，可手动覆盖）；加班类型四个选项等宽对齐；**仅在「自定义」类型下**可修改倍率或改用固定加班时薪；时长 / 折算 / 金额实时预览并显示**休息时间扣除**；项目、备注（浮动标签位置一致）；是否调休、是否已结算；保存前校验 |
| 统计 | **月度 / 年度双视图**：月度看单月三张指标卡（时长 / 折算工时 / 加班费，**等高对齐**）、类型汇总、每日柱状图、年度趋势；年度看全年三张指标卡、类型汇总、年度趋势折线与 12 个月柱状图；支持前后翻页与回到本月 / 今年 |
| 设置 | **薪资录入方式：按时薪 或 按月薪（时薪 = 月薪 ÷ 21.75 ÷ 8，自动反推并重算）**；各类型默认倍率（**记录页只读，倍率统一在此处修改**）；默认固定加班时薪；默认项目；是否扣除休息时间（可设分钟数，**统计、折算与金额均按扣除后有效时长计算**）；折算工时是否四舍五入到分钟；主题外观；导出 CSV / 导入 CSV / 清空所有数据 |

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
│   │   ├── constants.dart          # 加班类型、计算方式、薪资方式、Box 名称、版本号
│   │   ├── holidays.dart           # 2025/2026 法定节假日与调休内置日历
│   │   ├── theme/app_theme.dart    # 浅色 / 深色主题
│   │   └── utils/
│   │       ├── time_utils.dart     # 时间解析、跨天时长、格式化、YearMonth
│   │       └── calc.dart           # 折算工时 / 金额计算规则（倍率、固定时薪、扣休息）
│   ├── data/
│   │   ├── models/
│   │   │   ├── overtime_record.dart   # 数据模型 + 手写 Hive TypeAdapter
│   │   │   └── app_settings.dart      # 设置模型（时薪 / 月薪 / 默认时薪等）
│   │   └── csv/
│   │       └── record_csv_service.dart  # 导出 / 解析 CSV
│   ├── providers/
│   │   ├── records_provider.dart   # 记录增删改查、导入去重、按月批量结算、金额重算
│   │   ├── settings_provider.dart  # 设置项
│   │   ├── filter_provider.dart    # 按天 / 按月筛选、项目搜索
│   │   └── stats_provider.dart     # 月度 / 年度 / 每日统计
│   └── ui/
│       ├── home/home_shell.dart    # 底部导航（记录 / 统计 / 设置）
│       ├── records/record_list_page.dart
│       ├── records/record_edit_page.dart
│       ├── stats/stats_page.dart
│       └── settings/settings_page.dart
├── test/
│   ├── calc_test.dart              # 时长 / 折算 / 金额 / 月薪 / 固定时薪 / CSV 单元测试
│   ├── holiday_test.dart           # 节假日与调休自动推断测试
│   └── page_smoke_test.dart        # 主要页面渲染与交互冒烟测试
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

使用到的 GitHub Action 均已运行在 Node.js 24 上
（`actions/checkout@v7`、`actions/setup-java@v6`、`actions/upload-artifact@v7`、
`subosito/flutter-action@v2`），Actions 日志中不再出现
「Node.js 20 is deprecated」与「setup-java v4 is deprecated」警告。

手动触发：仓库页 → **Actions** → **Build APK** → **Run workflow**。

也可以在本机执行 `gh workflow run build-apk.yml`。

### 首次推送

```bash
git add .
git commit -m "feat: 记工时 v1.2.0"
git branch -M main
git remote add origin https://github.com/Zero-Vz/Working_Hours.git
git push -u origin main
```

## 计算规则

| 项目 | 规则 |
| --- | --- |
| 时长 | `结束时间 - 开始时间`；结束时间早于等于开始时间时自动 **+24 小时**（跨天）；结束时间等于开始时间为非法输入，保存时拦截。也可用「固定时长」直接指定 3 小时、8 小时等，结束时间按开始时间 + 时长自动算出 |
| 休息扣除 | 开启「扣除休息时间」后，`有效时长 = 时长 - 休息分钟数`，记录列表、统计与编辑页均显示**原始时长与扣除后的有效时长** |
| 折算工时（按倍率） | `有效时长 × 倍率`；开启「四舍五入到分钟」时先按分钟取整再换算小时 |
| 折算工时（按固定时薪） | `有效时长`（不乘倍率），用于展示 |
| 预计加班费（按倍率） | `折算工时 × 时薪`，保留两位小数 |
| 预计加班费（按固定时薪） | `有效时长 × 固定加班时薪`，保留两位小数 |
| 时薪 | 设置为「按时薪」时直接使用填写的值；设置为「按月薪」时 `时薪 = 月薪 ÷ 21.75 ÷ 8` |
| 金额重算 | 修改时薪 / 月薪 / 默认固定时薪 / 休息 / 取整设置时，历史记录金额按新规则自动重算 |

各类型默认倍率：工作日 1.5、休息日 2.0、节假日 3.0、自定义 1.0（均可在设置页修改，
新增记录页仅在类型为「自定义」时才允许修改倍率 / 切换为固定加班时薪）。

### 日历自动加班类型

`lib/core/holidays.dart` 内置 2025、2026 年国务院办公厅发布的节假日安排，
新增记录时按所选日期自动带出类型与倍率，随时可手动覆盖：

| 日期 | 类型 |
| --- | --- |
| 法定节假日当天（元旦、除夕至初三、清明、劳动、端午、中秋、国庆） | 节假日 ×3 |
| 放假连休中的非法定日、普通周末 | 休息日 ×2 |
| 调休补班的周末（如 2025-02-08、2026-02-14） | 工作日 ×1.5 |
| 其余工作日 | 工作日 ×1.5 |

未收录年份（2027 年起，国务院尚未发布）自动退化为「周六周日 = 休息日、其余 = 工作日」。

## CSV 格式

导出文件带 UTF-8 BOM（Excel 可直接打开中文），表头：

```csv
id,date,startTime,endTime,durationMinutes,type,rate,calcMode,fixedWage,project,note,isCompensatory,isSettled,amount,createdAt,updatedAt
7,2026-10-05,18:00,02:30,510,休息日,2.0,fixed,60,机房割接,跨天加班,false,true,510.00,2026-10-05T09:30:00.000,2026-10-05T09:30:00.000
```

- `calcMode`：`rate`（按倍率）/ `fixed`（按固定时薪）
- 旧版 CSV（没有 `calcMode`、`fixedWage` 两列）仍然可以正常导入，默认按倍率计算
- 导入时按 `日期 + 起止时间 + 项目 + 类型` 去重，重复记录自动跳过

## 数据与隐私

- 无网络权限（release 清单中无 `INTERNET` 等任何权限声明）
- 数据存放在应用私有目录的 Hive 文件中，卸载应用即删除
- 导出 CSV 通过系统分享面板完成，导入通过系统文件选择器完成
