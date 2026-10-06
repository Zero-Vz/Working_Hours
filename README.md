# 记工时 Working_Hours

离线优先的加班工时记录、统计与导出应用（Android / Flutter）。

- **不登录、日常使用不联网**：记录、统计、导出全部在本机完成，无广告无埋点
- 仅在你**主动点击**时联网两处：「更新节假日数据」与「检查软件更新」；
  为此只申请 `INTERNET` 一个权限，不上传任何个人数据
- 中文界面，Material 3，支持深色模式（跟随系统 / 浅色 / 深色）
- 仓库地址：<https://github.com/Zero-Vz/Working_Hours.git>

## 功能

| 页面 | 功能 |
| --- | --- |
| 记录列表 | **加班记录 / 请假记录两种分段**（顶部一键切换，筛选、搜索、汇总随模式联动）；**按天 / 按月两种查看方式**（点日期选精确日期后只显示当天记录，也可一键切回整月）；‹ › 按天或按月前后翻页；按项目/备注/类型（或请假理由）搜索；左滑删除（带撤销）；点击进入编辑；顶部按当前筛选范围汇总（含休息扣除提示）；**按月批量标记 / 取消「已结算」**（仅加班）；请假汇总显示天数、带薪/无薪与扣款 |
| 新增 / 编辑 | 日期选择器、开始/结束时间选择器，或**固定时长模式**（30分钟 ~ 23小时59分，含 3 小时、8 小时等快捷值，**填写的即为实际加班时长，结束时间 = 开始 + 时长 + 休息**）；**每条记录可单独设置休息时长**（默认「跟随设置」，也可选 0/15/30/45/60/90 分或自定义，位于时间卡片内）；**新增记录自动记忆上次的开始 / 结束时间与固定时长**；自动计算时长并支持跨天（+24h）；**按日历自动选定加班类型与倍率**（法定节假日→节假日 ×3、周末/放假连休→休息日 ×2、调休补班日→工作日 ×1.5、平日→工作日，可手动覆盖）；四个加班类型共用**完全一致的信息框**，**仅「自定义」类型点击信息框弹窗修改倍率或固定加班时薪**；时长 / 折算 / 金额实时预览并显示**休息时间扣除**；项目、备注（浮动标签位置一致）；是否调休、是否已结算；保存前校验 |
| 请假记录 | 带薪 / 无薪切换、请假天数（0.5 天起，快捷值）、**请假理由**、**扣工资金额**（**带薪假不一定是全日薪**：默认填 0 即不扣除，也可用「不扣除 / 扣 25% / 扣 50% / 扣 100%」快捷比例或手填部分扣款；无薪默认按日薪全额扣，同样可手填或**按日薪一键估算**）；点击编辑、左滑删除；计入统计页的请假汇总与整月总工资 |
| 统计 | **月度 / 年度双视图**：月度看单月三张指标卡（时长 / **增扣金额** / 加班费，**等高对齐**、增扣拆成「增 / 扣」两行显示不截断）、**整月总工资（含扣增）明细卡**、类型汇总、请假汇总、**四张趋势图**（每日时长、每日金额、每日增扣金额、每日请假扣款）；年度看全年三张指标卡（全年时长 / **全年增扣金额** / 全年加班费）、**全年总工资**、类型汇总、请假汇总、**四张按月趋势图**（每月时长 / 金额 / 增扣 / 请假扣款）；**趋势图可在折线图 / 条形图之间一键切换**（卡标题右侧图标或「设置 → 统计显示」全局开关）；**四张趋势图可各自独立隐藏**；长按图表显示**美化后的气泡提示**（月度横轴带「号」，如 `15号`；数值为 0 显示 `0`，其余两位小数）；仅保留 ‹ › 前后翻页 |
| 设置 | **分组 + 二级菜单**：薪资与时薪（**按时薪 或 按月薪，时薪 = 月薪 ÷ 21.75 ÷ 8**、**可按月单独调薪**、默认固定加班时薪）、**默认倍率**（独立二级菜单，四类倍率统一两位小数；首页描述按**两行两列**排版）、计算规则（扣休息与默认休息时长、四舍五入、默认项目）、**工资项**（补贴 / 绩效 / 个税 / 保险等**自定义名称与个数**，增项、扣项分组统计，**金额可按月单独设置**，首页描述按增 / 扣两行排版）、**节假日数据**（内置 2025/2026 年日历，**联网更新 / 导入文件 / 导出 / 恢复内置**）、**统计显示**（是否将月薪计入总工资、是否均摊到整月每个工作日、显示整月总工资还是仅加班趋势、**折线 / 条形切换**，以及**请假、增扣项与四张趋势图的独立开关**）、数据管理（**全量备份：JSON 一键导出 / 恢复加班 + 请假 + 工资项 + 设置**，加班 / 请假 / 工资项 CSV 导入导出、清空数据）；顶层保留主题外观，**「关于」提供项目主页、开发者与检查软件更新** |

## 技术栈

- Flutter 3.22+ / Dart 3（本地与 CI 固定 **3.24.5**）
- 状态管理：Riverpod（`flutter_riverpod`）
- 本地数据库：Hive（离线优先，手写 TypeAdapter，无需代码生成）
- 图表：`fl_chart`
- 导出：`csv` + `share_plus`；导入：`file_picker`（系统文件选择器，无需存储权限）
- 打开外部链接：`url_launcher`（项目主页 / 更新发布页）
- 联网（仅更新节假日与检查更新）：`dart:io` `HttpClient`，不引入额外网络库
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
│   │   └── src/main/AndroidManifest.xml   # 应用名「记工时」，仅 INTERNET 一项权限（用于更新节假日 / 检查更新）
│   ├── build.gradle
│   ├── settings.gradle
│   └── gradle.properties
├── lib/
│   ├── main.dart                   # 入口：初始化 Hive 并注册 Adapter
│   ├── app.dart                    # MaterialApp（Material 3 / 中文 / 深色模式）
│   ├── core/
│   │   ├── constants.dart          # 加班类型、计算方式、薪资方式、Box 名称、版本号、更新地址
│   │   ├── holidays.dart           # 2025/2026 内置日历 + 节假日数据模型（HolidayData）与生效查询
│   │   ├── theme/app_theme.dart    # 浅色 / 深色主题
│   │   └── utils/
│   │       ├── time_utils.dart     # 时间解析、跨天时长、格式化、YearMonth
│   │       └── calc.dart           # 折算工时 / 金额计算规则（倍率、固定时薪、扣休息）
│   ├── data/
│   │   ├── models/
│   │   │   ├── overtime_record.dart   # 数据模型 + 手写 Hive TypeAdapter（含单条休息时长）
│   │   │   ├── leave_record.dart      # 请假记录（带薪 / 无薪、天数、理由、扣款）
│   │   │   ├── income_item.dart       # 工资项（增项 / 扣项，自定义名称与金额）
│   │   │   └── app_settings.dart      # 设置模型（时薪 / 按月调薪 / 统计显示 / 图表样式 / 记忆时间等）
│   │   ├── backup_service.dart        # 全量备份（JSON 导出 / 恢复）
│   │   ├── holiday_store.dart         # 节假日数据持久化（联网更新 / 导入结果按年份写入 Hive）
│   │   ├── holiday_file_service.dart  # 节假日 JSON / CSV 解析、导出与联网下载
│   │   ├── http_service.dart          # 极简 HTTP GET（更新节假日 / 检查更新共用）
│   │   ├── update_check_service.dart  # 检查软件更新（解析 Releases JSON、版本比较）
│   │   └── csv/
│   │       ├── record_csv_service.dart  # 加班记录导出 / 解析 CSV
│   │       ├── leave_csv_service.dart   # 请假记录导出 / 解析 CSV
│   │       └── income_csv_service.dart  # 工资项导出 / 解析 CSV（含按月金额）
│   ├── providers/
│   │   ├── records_provider.dart   # 记录增删改查、导入去重、按月批量结算、金额重算
│   │   ├── leaves_provider.dart    # 请假记录增删改查、导入去重
│   │   ├── income_items_provider.dart # 工资项管理与增项 / 扣项合计
│   │   ├── settings_provider.dart  # 设置项
│   │   ├── filter_provider.dart    # 按天 / 按月筛选、项目搜索、加班 / 请假分段
│   │   └── stats_provider.dart     # 月度 / 年度 / 每日统计、工资构成、金额趋势
│   └── ui/
│       ├── home/home_shell.dart    # 底部导航（记录 / 统计 / 设置）
│       ├── records/record_list_page.dart
│       ├── records/record_edit_page.dart
│       ├── records/leave_edit_page.dart
│       ├── stats/stats_page.dart
│       └── settings/
│           ├── settings_page.dart       # 设置首页（功能分组菜单）
│           ├── settings_common.dart     # 二级页共用的弹窗与卡片组件
│           ├── salary_settings_page.dart # 薪资与时薪（按时薪 / 月薪、按月调薪）
│           ├── rate_settings_page.dart  # 默认倍率（独立二级菜单）
│           ├── calc_settings_page.dart  # 计算规则（休息、取整、默认项目）
│           ├── income_items_page.dart   # 工资项管理（含按月金额）
│           ├── stats_settings_page.dart # 统计显示口径、图表样式与趋势开关
│           ├── holidays_settings_page.dart # 节假日数据（联网更新 / 导入导出 / 恢复内置）
│           └── data_settings_page.dart  # 数据管理（全量备份 / CSV 导入导出 / 清空）
├── assets/
│   └── holidays/holidays.json       # 节假日数据源文件（联网更新拉取，未打进 APK）
├── test/
│   ├── calc_test.dart              # 时长 / 折算 / 金额 / 月薪 / 固定时薪 / 总工资 / CSV 单元测试
│   ├── holiday_test.dart           # 节假日与调休自动推断测试
│   ├── leave_income_test.dart      # 请假记录与工资项模型 / CSV 测试
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
# 只构建 arm64-v8a（本项目唯一需要的架构，体积最小）
flutter build apk --release --target-platform android-arm64

# 如需一次生成全部架构的分包
flutter build apk --release --split-per-abi
```

产物路径：

```
build/app/outputs/flutter-apk/app-release.apk                      # 仅含 arm64-v8a（--target-platform）
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk            # split-per-abi 的 v8a 分包
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk          # split-per-abi 的 v7a 分包
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
3. `flutter build apk --release --target-platform android-arm64`
   （**只构建 arm64-v8a，不再产出 v7a / x86_64**）
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
git commit -m "feat: 记工时 v1.3.0"
git branch -M main
git remote add origin https://github.com/Zero-Vz/Working_Hours.git
git push -u origin main
```

## 计算规则

| 项目 | 规则 |
| --- | --- |
| 时长 | `结束时间 - 开始时间`；结束时间早于等于开始时间时自动 **+24 小时**（跨天）；结束时间等于开始时间为非法输入，保存时拦截 |
| 固定时长 | 填写的**就是实际加班时长**：开启扣休息时 `结束时间 = 开始 + 时长 + 休息`，关闭时 `结束时间 = 开始 + 时长`，两种情况下有效时长都等于所填时长 |
| 休息扣除 | 开启「扣除休息时间」后，`有效时长 = 时长 - 休息分钟数`；**每条记录的休息时长默认「跟随设置」，也可单独设置**（记录自带值优先），记录列表、统计与编辑页均显示原始时长与扣除后的有效时长 |
| 折算工时（按倍率） | `有效时长 × 倍率`；开启「四舍五入到分钟」时先按分钟取整再换算小时 |
| 折算工时（按固定时薪） | `有效时长`（不乘倍率），用于展示 |
| 预计加班费（按倍率） | `折算工时 × 时薪`，保留两位小数 |
| 预计加班费（按固定时薪） | `有效时长 × 固定加班时薪`，保留两位小数 |
| 时薪 | 设置为「按时薪」时直接使用填写的值；设置为「按月薪」时 `时薪 = 月薪 ÷ 21.75 ÷ 8`；**月薪可按月单独调整**（如 10 月起调薪），当月记录按当月月薪反推时薪，未单独设置的月份仍用默认月薪 |
| 金额重算 | 修改时薪 / 月薪 / 默认固定时薪 / 休息 / 取整设置时，历史记录金额按新规则自动重算 |
| 请假扣款 | 带薪与无薪都按记录填写的扣款金额扣减：**带薪默认 0 = 不扣除**（带薪假不一定是全日薪，可按「不扣除 / 25% / 50% / 100%」比例或手填部分扣款），无薪默认按日薪全额扣减；两者都可用日薪（月薪 ÷ 21.75 或时薪 × 8）一键估算 |
| 工资项 | 每月固定金额：增项（补贴、绩效…）相加，扣项（税费、保险…）相减，仅统计启用中的条目；**金额可按月单独设置**（如绩效只有某些月份有），未设置的月份保持默认金额 |
| 整月总工资 | `月薪（可选）+ 加班费 + 增项 - 扣项 - 请假扣款`；开启「月薪计入总工资」才计入月薪，**全年按 12 个月汇总月薪与工资项** |
| 趋势图 | **折线图 / 条形图可一键切换**（卡片标题右侧图标即时切换，「设置 → 统计显示」为全局开关），共四组：**时长**（月度 = 每日有效时长，与指标卡口径一致；年度 = 每月有效时长）、**金额**（月度 = 每日加班费，开启「均摊到每个工作日」时再加上平摊的月薪与工资项；年度 = 每月加班费 + 当月固定金额）、**增扣金额**（工资项净额，月度固定按工作日平摊，年度为每月净额）、**请假扣款**（独立成图，仍不计入主金额趋势）；两种样式共用同一套坐标、轴刻度与气泡提示 |
| 展示开关 | 「设置 → 统计显示」可分别关闭**请假**与**增扣项**的展示，也可**单独隐藏四张趋势图（时长 / 金额 / 增扣 / 请假扣款）**：关闭后对应汇总卡与趋势图不再渲染；**总工资的计算口径不受影响** |

各类型默认倍率：工作日 1.50、休息日 2.00、节假日 3.00、自定义 1.00，均可在
「设置 → 默认倍率」中修改；**所有倍率统一按两位小数显示**，设置页与记录页长度一致。
新增记录页四个类型共用同一个信息框，只有类型为「自定义」时点击信息框才会弹窗
修改倍率或切换为固定加班时薪。

### 日历自动加班类型

`lib/core/holidays.dart` 内置 2025、2026 年国务院办公厅发布的节假日安排，
新增记录时按所选日期自动带出类型与倍率，随时可手动覆盖：

| 日期 | 类型 |
| --- | --- |
| 法定节假日当天（元旦、除夕至初三、清明、劳动、端午、中秋、国庆） | 节假日 ×3 |
| 放假连休中的非法定日、普通周末 | 休息日 ×2 |
| 调休补班的周末（如 2025-02-08、2026-02-14） | 工作日 ×1.5 |
| 其余工作日 | 工作日 ×1.5 |

内置数据存在 `lib/core/holidays.dart`，**2027 年起国务院尚未发布安排时会自动退化为
「周六周日 = 休息日、其余 = 工作日」**。为避免后续年份缺失，可在
**「设置 → 计算与记录 → 节假日数据」**里更新数据：

| 方式 | 说明 |
| --- | --- |
| 联网更新 | 从仓库内 `assets/holidays/holidays.json` 拉取最新数据（需联网，地址可自行修改） |
| 从文件导入 | 选择本地 **JSON 或 CSV** 文件，离线也能更新 |
| 导出当前数据 | 导出为 JSON 并通过系统分享面板保存 / 传输 |
| 恢复内置数据 | 丢弃更新结果，回到随 APK 发布的 2025 / 2026 数据 |

更新按**年份**覆盖：导入 2027 年数据只替换 2027 年，2025 / 2026 原样保留；
更新结果保存在 Hive 中，重启后仍然生效；页面上会显示当前来源（内置 / 联网更新 /
导入文件）、覆盖年份与最近更新时间。

### 节假日数据格式

**JSON**（`assets/holidays/holidays.json` 与应用导出均为该格式）：

```json
{
  "name": "2027年放假安排",
  "statutory": ["2027-01-01", "2027-01-02"],
  "makeup": ["2027-02-07"],
  "breaks": ["2027-01-01..2027-01-05"]
}
```

- `statutory`：法定节假日（3 倍）；`makeup`：调休补班（按工作日）；
  `breaks`：放假连休的全部日期（含法定当天与调休休息日）
- 日期既可写单日 `2027-01-01`，也可写区间 `2027-01-01..2027-01-05`（首尾都包含）
- 字段别名兼容 `holidays` / `legal`、`makeupWorkdays` / `workdays`、
  `holidayBreaks` / `rests`；非法日期会被跳过并在确认弹窗里提示数量

**CSV**（需含表头 `kind,date[,note]`）：

```csv
kind,date,note
statutory,2027-01-01,元旦
makeup,2027-02-07,春节调休
break,2027-01-01..2027-01-05,春节连休
```

- `kind` 支持 `statutory` / `makeup` / `break`，也兼容中文值
  「法定、节假日」「补班、调休」「放假、连休」

## CSV 格式

导出文件带 UTF-8 BOM（Excel 可直接打开中文），可在「设置 → 数据管理」中导出 / 导入。

### 加班记录

```csv
id,date,startTime,endTime,durationMinutes,type,rate,calcMode,fixedWage,breakMinutes,project,note,isCompensatory,isSettled,amount,createdAt,updatedAt
7,2026-10-05,18:00,02:30,510,休息日,2.0,fixed,60,-1,机房割接,跨天加班,false,true,510.00,2026-10-05T09:30:00.000,2026-10-05T09:30:00.000
```

- `calcMode`：`rate`（按倍率）/ `fixed`（按固定时薪）
- `breakMinutes`：`-1` 表示**跟随设置**，`>= 0` 表示本条记录单独的休息分钟数
- 旧版 CSV（没有 `calcMode`、`fixedWage`、`breakMinutes` 等列）仍然可以正常导入，
  默认按倍率计算、休息时长跟随设置
- 导入时按 `日期 + 起止时间 + 项目 + 类型` 去重，重复记录自动跳过

### 请假记录

```csv
id,date,days,type,reason,deductAmount,createdAt,updatedAt
5,2026-10-05,1.5,unpaid,病假,650.50,2026-10-05T09:30:00.000,2026-10-05T09:30:00.000
```

- `type`：`paid`（带薪，默认不扣除，也可填部分扣款）/ `unpaid`（无薪，按 `deductAmount` 扣款），
  兼容导入中文值「带薪 / 无薪」
- 导入时按 `日期 + 类型 + 理由 + 天数` 去重，重复记录自动跳过

### 工资项

```csv
id,name,kind,amount,active,monthlyOverrides,createdAt,updatedAt
3,绩效,income,500,true,2026-10=800;2026-12=0,2026-10-01T09:00:00.000,2026-10-05T09:30:00.000
4,社保,deduct,860,true,,2026-10-01T09:00:00.000,2026-10-05T09:30:00.000
```

- `kind`：`income`（增项）/ `deduct`（扣项）
- `monthlyOverrides`：**按月金额**，`YYYY-MM=金额` 用 `;` 分隔；未列出的月份使用
  `amount` 中的默认金额，填 `0` 表示该月不计入
- 导入时按 `名称 + 类型` 去重，重复项自动跳过

### 全量备份（JSON）

「设置 → 数据管理 → **导出全部数据**」生成 `记工时_全部数据_yyyyMMdd_HHmm.json`，
一次性包含**设置 + 全部加班记录 + 请假记录 + 工资项**；
「**恢复全部数据**」会先列出条目数量并要求确认，再合并导入
（重复记录、同名同类型工资项自动跳过，**不会删除已有数据**；
设置按白名单键覆盖，备份中不含设置时保持当前设置）。

## 数据与隐私

- 权限：仅 `INTERNET`，且**只在你主动点击「联网更新节假日」或「检查软件更新」时才会联网**
  （清单里再无其他权限，不后台联网、不上传任何个人数据）
- 日常记录、统计、导出完全离线；数据存放在应用私有目录的 Hive 文件中，卸载应用即删除
- 导出 CSV / JSON 通过系统分享面板完成，导入通过系统文件选择器完成
- 项目主页、开发者主页与更新发布页用系统浏览器打开，链接见「设置 → 关于」
