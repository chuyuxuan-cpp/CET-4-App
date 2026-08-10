# CET-4/6-App

一款面向大学英语四级、六级备考的 Flutter 背单词应用。内置词书与本地学习记录，支持在移动设备上进行日常学习和复习。

## 功能概览

- CET-4、CET-6 词书学习
- 按学习进度安排复习
- 单词释义、音标与发音
- 自出卷练习与答题记录
- 生词本管理
- 每日学习提醒

## iOS 安装

项目的 GitHub Actions 会构建无签名 iOS IPA。请在仓库的 **Actions** 页面打开成功的 iOS 工作流运行，下载 Artifact：`CET4App-iOS-unsigned`，解压后获得 `CET4App.ipa`。

已验证的安装方式是使用 [Sideloadly](https://sideloadly.io/)：

1. 在电脑上安装并打开 Sideloadly，将 iPhone 或 iPad 通过 USB 连接到电脑。
2. 将 `CET4App.ipa` 拖入 Sideloadly，选择已连接的设备。
3. 按 Sideloadly 的界面提示使用自己的 Apple ID 完成侧载。
4. 首次打开前，如系统提示，请在设备的“设置”中信任对应的开发者证书。

IPA 为无签名构建；侧载和证书状态由 Sideloadly 与 Apple ID 管理。请遵循 Apple 和 Sideloadly 的当前使用要求。

## 基本使用

1. 打开应用后，在“背单词”中选择词书并开始学习。
2. 根据单词卡片完成学习，应用会记录进度并安排后续复习。
3. 在“自出卷”中进行练习，在“生词本”中查看需要重点记忆的词。
4. 在“设置”中按需要配置每日学习提醒。

## 数据与隐私

词库随应用内置，并在首次启动时复制到应用文档目录。学习进度、生词本、练习记录和设置均保存于设备本地 SQLite 数据库中；应用不需要账号，也不使用服务端同步。

## 开发构建

需要安装 Flutter SDK（项目当前 CI 使用 Flutter 3.44.6）。在项目根目录执行：

```bash
flutter pub get
flutter run
```

运行测试：

```bash
flutter test test/widget_test.dart
```

构建 Android 发布包：

```bash
flutter build apk --release
```

构建无签名 iOS 包：

```bash
flutter build ios --release --no-codesign
```

## 词表来源

词表来源于 [mahavivo/english-wordlists](https://github.com/mahavivo/english-wordlists) 公开仓库。项目在本地对 CET-4 与 CET-6 词表进行预处理，并生成随应用分发的 SQLite 词库；本项目不在运行时请求该仓库或其他词库服务。

## 许可证

本项目代码采用 [MIT License](LICENSE)。内置词表来源于 [mahavivo/english-wordlists](https://github.com/mahavivo/english-wordlists)，请在使用、修改或再分发前查阅该词表仓库的适用许可。
