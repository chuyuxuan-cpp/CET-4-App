# 四六级背单词 App 设计规格

日期：2026-08-03
状态：已获用户批准

## 背景与目标

一款面向四六级考生的移动端背单词应用，iOS/Android 双端（iOS 优先验证，最终双端发布）。核心闭环：每日学习新词 → 间隔复习巩固 → 生词本重点突破。

四个 Tab：
1. **背单词**：按每日学习计划学习新词
2. **自出卷**：按 1/3/7 天间隔自动出题复习
3. **生词本**：查看生词 + 专项自测
4. **设置**：学习计划、词书、提醒、数据管理

## 关键约束

- 开发者有 Python 经验，无 iOS/移动端开发经验
- 开发环境为 Windows，无 Mac；iPhone 真机
- 因此：Flutter 跨平台，Windows + Android 模拟器完成全部开发，Codemagic（或 GitHub Actions macOS runner）云端构建 iOS 包，Sideloadly 侧载到 iPhone 做阶段性真机验证；上架前再考虑购入 Mac

## 技术选型

| 项 | 选择 | 理由 |
|---|---|---|
| 框架 | Flutter (Dart) | 一套代码双端产出；对 Python 背景友好；生态成熟 |
| 状态管理 | Riverpod | 编译期安全，适合分层架构 |
| 本地数据库 | drift (SQLite ORM) | 类型安全，适合结构化学习记录 |
| 词库 | 预置 SQLite 文件打进安装包，首次启动复制到应用目录 | 完全离线，零运行时网络依赖 |
| 发音 | flutter_tts（系统 TTS） | 无需打包音频文件 |
| 每日提醒 | flutter_local_notifications | 本地定时推送，无需服务端 |

## 架构分层

```
UI 页面 (Screens/Widgets)
  ↓
Riverpod Providers（状态与业务编排）
  ↓
Repository（学习/复习/生词本/设置 四个仓库）
  ↓
drift 数据库（词库表 + 用户数据表）
```

目录按功能优先划分（feature-first）：`lib/features/study/`、`lib/features/quiz/`、`lib/features/notebook/`、`lib/features/settings/`、`lib/core/`（数据库、工具）。

## 数据模型

### words（词库表，只读，预置）
| 字段 | 类型 | 说明 |
|---|---|---|
| id | INTEGER PK | |
| word | TEXT | 单词 |
| phonetic | TEXT | 音标 |
| pos | TEXT | 词性 |
| meaning | TEXT | 中文释义 |
| example | TEXT | 例句（可为空） |
| book | TEXT | `cet4` / `cet6` |
| seq | INTEGER | 词书内序号，决定学习顺序 |

### progress（学习进度，每词每词书一条）
| 字段 | 类型 | 说明 |
|---|---|---|
| word_id | INTEGER FK → words.id | |
| book | TEXT | |
| first_learned_at | DATE | 首次学习日期 |
| stage | INTEGER | 复习阶段：1 / 3 / 7 / 99（已掌握） |
| next_review_at | DATE | 下次复习日期 |

### notebook（生词本）
| 字段 | 类型 | 说明 |
|---|---|---|
| word_id | INTEGER FK | |
| added_at | DATETIME | |
| source | TEXT | `manual`（手动星标）/ `unknown`（学习时标记不认识） |

### quiz_records（答题记录，供统计）
| 字段 | 类型 | 说明 |
|---|---|---|
| answered_at | DATETIME | |
| word_id | INTEGER FK | |
| quiz_type | TEXT | `review`（自出卷）/ `notebook`（生词本自测） |
| direction | TEXT | `en2cn` / `cn2en` |
| correct | BOOLEAN | |

### settings（单条记录）
| 字段 | 说明 |
|---|---|
| daily_quota | 每日新词量：10 / 20 / 30 / 50，默认 20 |
| active_book | 当前词书：`cet4` / `cet6`，默认 cet4 |
| reminder_enabled | 提醒开关 |
| reminder_time | 提醒时间（默认 20:00） |

## 模块设计

### 1. 背单词

- 取词：当前词书中无 progress 记录的单词，按 seq 升序取 daily_quota 个
- 卡片流程：只显示英文 → 点击翻面显示音标/词性/释义/例句 → 用户自评
  - **认识**：创建 progress，stage=1，next_review_at=明天
  - **不认识**：同样创建 progress（stage=1，明天复习），并自动加入生词本（source=unknown）
- 卡片上有星标按钮，随时手动加入生词本（source=manual）
- 当日任务不累积：没学完的部分作废，次日从词书顺序取新一批
- 卡片支持播放发音（flutter_tts）

### 2. 自出卷（间隔复习）

- 出题范围：当前词书中 `next_review_at ≤ 今天` 的 progress 记录
- 题型混合：
  - 英译中 → 四选一（干扰项从同词书随机抽取）
  - 中译英 → 填空（大小写不敏感，去除首尾空格后精确匹配）
  - 两个方向各占约一半，随机分配
- 判分后推进规则：
  - 答对：stage 按 1 → 3 → 7 → 99 推进，next_review_at = 今天 + stage 对应天数
  - 答错：stage 重置为 1，next_review_at = 明天
- 今日无待复习词时显示空状态页（不报错、不阻塞）

### 3. 生词本

- 列表查看：支持按加入时间 / 字母排序，支持手动移除
- 专项自测：从生词本抽词出题，题型与判分规则同自出卷
- 自测结果只写入 quiz_records，**不修改 progress**（不影响主复习循环，避免双重计算）

### 4. 设置

- 每日学习量（10/20/30/50）
- 切换词书（cet4 ⇄ cet6，progress 按词书独立保存，互不影响）
- 每日提醒：开关 + 时间选择器（flutter_local_notifications 定时推送）
- 数据管理：重置当前词书的全部学习数据（二次确认）

## 复习算法小结

```
新词学习（今天 D）
  → stage=1, next=D+1
复习答对
  → stage: 1→3→7→99，next = 今天 + 新stage值
复习答错
  → stage=1, next=明天
stage=99 后不再出现在自出卷
```

## 错误处理

- 词库文件复制失败 → 启动页提示重试，不进入主界面
- TTS 不可用（系统无语音引擎）→ 发音按钮置灰
- 通知权限被拒绝 → 设置页提醒项显示"未授权"，点击跳转系统设置

## 开发顺序

1. 项目骨架 + 词库数据准备（开源四六级词库清洗为 SQLite）+ 背单词模块
2. 复习引擎 + 自出卷模块
3. 生词本模块 + 专项自测
4. 设置模块 + 每日提醒 + 收尾打磨
5. Codemagic 云端构建 iOS 包，Sideloadly 真机验证

## 词库来源

GitHub 开源四六级词库（含音标、词性、释义；例句尽量保留，缺失可接受），离线清洗转换为 SQLite 预置文件。
