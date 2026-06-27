# NewsDaily

macOS 每日热点新闻客户端。基于 SwiftUI + SwiftData + WKWebView，聚合 BBC / CNN / 联合早报 等来源的 RSS 新闻，支持 AI 全文翻译、选词翻译、生词本、对照阅读。完整实现 `macos-news-app-plan.md` 中描述的 MVP / AI 翻译 / 选词翻译 三大阶段。

## 系统要求

- macOS 14.0+（SwiftData 依赖）
- Swift 6.0+
- Xcode 16+（如需 .app 打包）

## 目录结构

按 plan 第 9 节工程结构组织：

```
NewsDaily/
├── Package.swift
├── SupportingFiles/
│   ├── Info.plist
│   ├── AppIcon.png
│   ├── AppIcon.icns
│   └── NewsDaily.entitlements
├── Sources/NewsDaily/
│   ├── NewsDailyApp.swift              # @main 入口 + Settings + MenuBarExtra
│   ├── App/                            # AppState / AppSettings
│   ├── Models/                         # 5 个 SwiftData @Model
│   ├── Services/
│   │   ├── Feed/                       # FeedParser / FeedService / SourceRegistry
│   │   ├── Article/                    # ArticleNormalizer / HotScoreService / ContentExtractor
│   │   ├── AI/                         # AIProviderClient / 3 个客户端 / TranslationService / Cache
│   │   └── Storage/                    # PersistenceController
│   ├── Features/
│   │   ├── ContentView.swift           # 三栏 NavigationSplitView
│   │   ├── Sidebar/SidebarView.swift
│   │   ├── ArticleList/                # ArticleListView / ArticleRowView
│   │   ├── Reader/                     # ReaderView / WebReaderView / ParallelTranslationView / SelectableTextView
│   │   ├── Translation/                # TranslationPopover / TranslationTaskView
│   │   ├── Vocabulary/VocabularyView.swift
│   │   └── Settings/                   # AIProviderSettingsView / AIProviderFormView
│   └── Resources/                      # sources.json / ai-providers.json
├── Scripts/run-app.sh                  # 构建并以 .app bundle 方式启动
└── Tests/NewsDailyTests/               # 单元测试
```

## 构建

```bash
cd NewsDaily
swift build            # Debug
swift build -c release # Release
swift test             # 跑测试
```

## 运行 macOS App

请优先用 `.app` bundle 方式启动：

```bash
Scripts/run-app.sh
```

这个脚本会：

- 执行 `swift build`
- 组装 `.build/NewsDaily.app`
- 复制 `Info.plist`
- 复制 SwiftPM 资源包 `NewsDaily_NewsDaily.bundle`
- 用 `open -n .build/NewsDaily.app` 启动

不要用下面这些方式测试真实 macOS UI 输入：

```bash
swift run NewsDaily
.build/arm64-apple-macosx/debug/NewsDaily
```

SwiftPM 直接运行的是裸 Mach-O 可执行文件，不是正规 `.app`。Settings 场景、菜单、first responder、文本输入法和键盘事件在裸可执行方式下可能出现异常，例如输入框能选中但键盘输入进不去。`swift run` 只建议用于非 UI 逻辑调试。

## 打包为 .app

开发阶段可直接使用：

```bash
Scripts/run-app.sh
```

如需生成适合 Finder / Launchpad / 分发使用的 `.app` 和 zip：

```bash
Scripts/package-app.sh
```

产物会生成到：

```text
dist/NewsDaily.app
dist/NewsDaily-macOS.zip
```

脚本会构建 Release、复制 `Info.plist`、复制 `AppIcon.icns`、复制 SwiftPM 资源包、执行 ad-hoc codesign，并扫描包内是否误带常见 API Key 形态。

如果后续迁移到正式 Xcode 工程，建议创建新的 macOS App 项目，将 `Sources/NewsDaily/` 整个目录拖入，并设置：

- Deployment Target: macOS 14.0
- App Sandbox: 启用 `network.client`、`files.user-selected.read-write`
- 把 `SupportingFiles/Info.plist` 设为 Info.plist（在 Xcode 中通常自动生成）
- 把 `SupportingFiles/NewsDaily.entitlements` 设为 entitlements 文件

## 功能映射

| Plan 阶段 | 实现位置 |
| --- | --- |
| MVP：三栏 UI + RSS + 缓存 | `ContentView.swift`、`SidebarView.swift`、`ArticleListView.swift`、`FeedService.swift`、`FeedParser.swift` |
| 阶段 2：AI Provider 与翻译 | `Features/Settings/`、`Services/AI/`、`ReaderView.swift`、`ParallelTranslationView.swift` |
| 阶段 3：选词翻译 | `SelectableTextView.swift`、`WebReaderView.swift`、`TranslationPopover.swift`、`VocabularyView.swift` |
| 阶段 4：热点聚合 | `HotScoreService.swift`（recency/source/keyword/duplicateTopic 加权） |
| 阶段 5：产品化 | `MenuBarExtra`、`Settings` 场景、`UNUserNotificationCenter` 通知、App Sandbox entitlements |

## 配置

### 内置来源

`Sources/NewsDaily/Resources/sources.json` 默认包含：
- BBC World
- CNN World / CNN Top Stories
- NYT World（默认关闭）
- Reuters World（默认关闭，可能间歇性失效）
- 联合早报（默认配置但无 RSS URL，需要确认官方源）
- Guardian World（默认关闭）

### 内置 AI Provider 模板

`Sources/NewsDaily/Resources/ai-providers.json` 默认包含：
- DeepSeek（`openAICompatibleChat`）
- 智谱 GLM（`openAICompatibleChat`）
- 小米 MiMo（`customHTTP`）
- OpenAI（`openAIResponses`）
- 自定义 OpenAI 兼容接口

App 首次启动时若 SwiftData 中无 Provider，会自动从模板加载 5 个 Provider，但 **不会自动填入 API Key**。需要在设置页填入 Key 后才能进行翻译。

API Key 保存于用户本机的 SwiftData 配置库：

```text
~/Library/Application Support/NewsDaily/NewsDaily.store
```

这个文件位于 app bundle 和源码仓库之外，打包脚本不会复制它。

## 快捷键

| 快捷键 | 功能 |
| --- | --- |
| ⌘R | 刷新所有来源 |
| ⌘T | 翻译当前文章 |
| ⌘F | 搜索 |
| ⌘, | 打开设置 |
| Space | 快速预览（系统默认 List 行为） |

## 安全

- API Key 仅存储于用户本机 `~/Library/Application Support/NewsDaily/NewsDaily.store`。
- 打包脚本只复制可执行文件、`Info.plist`、图标和 SwiftPM 资源包，不复制用户本机配置库。
- 上传 GitHub 时不要提交 `.build/`、`dist/`、DerivedData 或个人 `Application Support` 数据。
- App Sandbox entitlements 仅申请 `network.client` 和 `files.user-selected.read-write`。
- 不默认上传阅读历史 / 收藏 / 生词本到任何服务器。
- iCloud 同步开关存在但默认关闭，且为预留接口，未启用 CloudKit 容器。

## 测试覆盖

单元测试覆盖 plan 第 14.1 节要求的核心场景：

- `FeedParserTests` — RSS 2.0 / Atom 1.0 解析、错误处理、日期解析
- `ArticleNormalizerTests` — URL 规范化、追踪参数剥离、去重 ID、相似度
- `HotScoreServiceTests` — recency/source/keyword/duplicateTopic 分数与综合计算
- `TranslationChunkerTests` — JSON 提取（含 Markdown 代码块）、Prompt 构造、内容哈希
- `AIProviderClientTests` — Factory 选择、OpenAI 响应解析、请求体构造
- `SourceRegistryTests` — RSS 自动发现、内置配置加载
- `ContentExtractorTests` — HTML 正文 / Title / Meta 抽取
- `MacTextFieldTests` — macOS 输入框、搜索框、Provider 表单 Model ID 输入同步

## 已知限制与后续工作

按 plan 第 15 节里程碑，本实现覆盖阶段 1-3 的核心功能。**阶段 4（热点聚合）** 已实现基础 `hotScore`，但主题聚类（Embeddings）尚未实现；**阶段 5（产品化）** 中 iCloud 同步、签名公证、崩溃日志上传等仍需在打包阶段补齐。

后端代理（plan 第 17 节）未在本仓库实现，因为个人自用版本可以直接在 App 内调用厂商 API；如发布给他人，请按 plan 指引另起 Cloudflare Workers / Vapor 后端。
