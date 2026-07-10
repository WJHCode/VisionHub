# Harness 需求列表：多端家庭媒体播放器

本文档用于跟踪 iOS、macOS、tvOS 多端家庭媒体播放器的 Harness 需求。每个模块包含 AI 实现指令、任务清单、验收标准和实现备注，便于后续拆分给代码生成、测试或验收流程。

## 完成度维护规则

- 本文档是 VisionHub 功能完成度的唯一事实来源（source of truth）。
- 每次功能、工程配置或测试发生修改时，必须在同一次变更中同步下方完成度、实现状态、验证结果和待办事项。
- `已完成` 表示功能已接入实际业务路径并通过测试或平台构建；`部分完成` 表示已有可运行骨架，但仍使用样例数据、占位实现或缺少平台验证；`未开始` 表示还没有可用实现。
- 百分比按验收标准完成情况估算，不按代码量计算。只有接口或空实现时，最高计为 25%。
- 更新完成度时必须写明验证依据；不能因为类型、协议或 UI 占位代码已经存在就标记为完成。

最近同步：2026-07-10

基线提交：`0ccf251 feat: establish VisionHub tvOS architecture`

## 功能完成度总览

当前架构与演示闭环完成度约 **72%**；以“连接真实家庭媒体服务器并正常观看”为标准的可用 MVP 完成度约 **48%**。

| 模块 | 状态 | 完成度 | 已实现 | 主要缺口 |
| --- | --- | ---: | --- | --- |
| M0 工程与共享架构 | 部分完成 | 75% | 根目录 tvOS 工程已关联本地 `VisionHubCore`；共享 Swift Package 可构建 | iOS/macOS 原生 targets 尚未加入；tvOS 平台运行时未安装，App target 尚未完成构建验证 |
| M1 数据模型 | 部分完成 | 95% | 六个 CloudKit 友好 SwiftData 模型、服务器/播放列表 CRUD、稳定进度 ID、Keychain 凭据引用已实现并有测试 | 模型迁移和 CloudKit schema 真机验证未完成 |
| M2 SwiftData/CloudKit 同步 | 部分完成 | 68% | ModelContainer、CloudKit 标识、10 秒进度节流、暂停/后台立即保存和按 `updatedAt` 合并已实现 | 离线恢复及多设备 CloudKit 端到端同步仍需真实账号与设备验证 |
| M3 多用户管理 | 部分完成 | 88% | 用户选择/新增/编辑/删除、上次用户恢复、进度和播放列表用户隔离已实现 | tvOS 遥控器及多尺寸布局仍需实机验收 |
| M4 播放器与续播 | 部分完成 | 78% | AVPlayerEngine、自动 seek、节流存档、暂停/后台/退出立即保存、片尾完成判定和扫描 URL 播放入口已实现 | 带认证 WebDAV 的 AVPlayer 请求头注入及多平台实际播放仍待外部环境验证 |
| M5 多端媒体 UI | 部分完成 | 74% | 海报墙、响应式进度、详情、源管理、播放列表、重命名/删除、tvOS focus 和 macOS context menu 已接入 | CloudKit 同步提示及 iOS/tvOS/macOS 交互验收未完成 |
| M6 媒体源 | 部分完成 | 72% | WebDAV XML 解析、目录浏览、递归扫描、取消/重试、稳定 ID 增量入库和 Keychain 认证请求已接入 UI | 认证媒体播放链路需真实服务器验证；SMB 仍依赖后续选型与集成 |
| M7 元数据刮削 | 部分完成 | 78% | Keychain API Key、电影/剧集文件名识别、TMDB 电影/剧集搜索、候选确认、缓存编排和 UI 更新已实现 | 真实 TMDB Key 联调、季集详情增强和批量匹配策略未完成 |
| M8 Apple 全平台 | 部分完成 | 15% | iOS、macOS、tvOS 入口文件已准备 | 当前 Xcode 工程只有 tvOS target；iOS/iPadOS/macOS 构建与交互未验证 |

## 当前验证记录

- [x] `swift test`：17 个 `VisionHubCore` 单元测试通过（2026-07-10）。
- [x] Xcode `VisionHubCore` scheme：macOS 构建通过（2026-07-10，macOS 26.2 SDK）。
- [x] 根目录 `VisionHub.xcodeproj/project.pbxproj`：语法校验通过，本地 Package 可解析。
- [ ] tvOS App target：本机缺少 tvOS 26.2 Platform，尚未完成编译和运行验证。
- [ ] CloudKit：尚未使用有效开发者账号、容器和多台设备完成端到端验证。

## M1: 多端基础项目架构与数据模型定义 (Data Models)

给 AI 的指令：

> 请帮我使用 SwiftData 设计适合 iOS/macOS/tvOS 多端通用的数据模型，需要支持多用户、播放列表和播放进度。

### 任务 1.1：设计 `UserProfile` 模型

- [x] 目标：支持在同一个 App 内切换不同的家庭成员。
- [x] 字段：
  - `id: UUID`
  - `name: String`
  - `avatarEmoji: String`
  - `createdAt: Date`
- [x] 验收标准：
  - 模型可被 SwiftData 持久化。
  - 支持按 `createdAt` 或 `name` 排序展示。
  - 创建新用户时字段具备默认值，满足 CloudKit 同步约束。

### 任务 1.2：设计 `MediaServer` 服务器配置模型

- [x] 目标：存储家庭媒体服务器的连接信息。
- [x] 字段：
  - `id: UUID`
  - `name: String`
  - `host: String`
  - `basePath: String`
  - `protocolType: String`
  - `username: String`
  - `credentialId: String`
- [x] 约束：
  - `protocolType` 支持 `SMB` 和 `WebDAV`。
  - 密码/token 使用 Keychain 保存，SwiftData 只保存 `credentialId` 引用。
- [x] 验收标准：
  - 能创建、编辑、删除服务器配置。
  - 协议类型可被 UI 安全枚举，避免任意字符串导致连接逻辑分支错误。

### 任务 1.3：设计 `PlaybackProgress` 播放进度模型

- [x] 目标：精确记录某个用户在某个视频上的断点。
- [x] 字段：
  - `id: String`
  - `userId: UUID`
  - `lastPlayedTime: Double`
  - `duration: Double`
  - `isFinished: Bool`
  - `updatedAt: Date`
- [x] ID 建议：
  - 使用文件唯一 Hash，或使用 `userId + mediaPath` 的稳定组合键。
- [x] AI 提示：
  - 确保 `updatedAt` 字段用于处理多端同步时的“最新时间覆盖逻辑”。
- [x] 验收标准：
  - 同一个用户同一个视频只产生一条有效进度。
  - 不同用户观看同一个视频时进度互不覆盖。
  - 多端冲突时以 `updatedAt` 最新的记录为准。

### 任务 1.4：设计 `PlayList` 播放列表模型

- [x] 目标：用户自定义的视频分组。
- [x] 字段：
  - `id: UUID`
  - `userId: UUID`
  - `title: String`
  - `mediaIds: [String]`
  - `createdAt: Date`
  - `updatedAt: Date`
- [x] 验收标准：
  - 播放列表按当前用户隔离。
  - 支持新增、重命名、删除播放列表。
  - 支持添加和移除视频路径。

## M2: 基于 CloudKit / SwiftData 的跨端同步引擎 (Sync Engine)

给 AI 的指令：

> 请帮我配置 SwiftData 与 CloudKit 的容器集成，实现数据的云端自动同步，并处理冲突。

### 任务 2.1：启用 CloudKit 同步配置

- [ ] 目标：让 SwiftData 模型自动同步到用户的私有 iCloud 空间。
- [x] 实现：
  - 配置 `ModelConfiguration`。
  - 启用 `cloudKitContainerIdentifier`。
  - 确保所有模型属性符合 CloudKit 要求。
  - 为属性提供默认值或可选类型。
  - 根据需要建立 `@Relationship` 关系。
- [ ] 验收标准（需 CloudKit 真实环境验证）：
  - iOS、macOS、tvOS 使用同一 CloudKit Container。
  - 首次启动可创建本地 `ModelContainer`。
  - 关闭网络时本地可用，恢复网络后自动同步。
  - 数据模型不触发 CloudKit schema 兼容性错误。

### 任务 2.2：编写进度更新拦截器 (Throttler)

- [x] 目标：视频播放时进度每秒都在变化，不能频繁写入云端。
- [x] 实现：
  - 本地 UI 可每秒更新播放进度。
  - SwiftData 持久化和 CloudKit 同步每隔 10 秒触发一次。
  - 用户暂停、退出播放、切换视频时立即保存一次。
- [x] 验收标准：
  - 连续播放 60 秒时，持久化写入次数约为 6 次，而不是 60 次。
  - App 进入后台或播放器销毁前不会丢失最后进度。
  - 节流器可被单元测试验证。

## M3: 多用户管理与切换 UI 模块 (User Management)

给 AI 的指令：

> 使用 SwiftUI 编写一个跨端的“谁在看剧？”用户选择界面。tvOS 端需要支持遥控器焦点放大效果。

### 任务 3.1：多用户选择大厅 (User Picker View)

- [x] 目标：App 启动时或设置中，显示家庭用户选择界面。
- [x] tvOS 适配代码：
  - 每个用户头像是一个 `Button`。
  - 使用 `.buttonStyle(.card)` 或自定义 Focus 动效。
  - Siri Remote 选中时有悬浮放大和阴影效果。
- [ ] 验收标准：
  - iOS 和 macOS 可点击选择用户。
  - tvOS 可通过遥控器焦点移动和确认选择用户。
  - 用户头像、名称在不同屏幕尺寸下不重叠、不截断。

### 任务 3.2：全局当前用户状态管理 (`CurrentUserStore`)

- [x] 目标：通过可观察的 `CurrentUserStore` 维护当前用户，不强制使用单例。
- [x] 实现：
  - 维护 `currentProfile`。
  - App 启动时恢复上次选择的用户。
  - 所有播放历史和列表查询，都要带上 `currentProfile.id` 作为过滤条件。
- [x] 验收标准：
  - 切换用户后，播放历史、播放列表、续播提示同步切换。
  - 未选择用户时进入用户选择界面。
  - 查询层不会泄露其他用户数据。

## M4: 核心播放器与断点续播逻辑 (Player Core)

给 AI 的指令：

> 实现一个基于 AVPlayer 的 SwiftUI 视频播放组件，支持在打开视频时读取历史进度并 Seek，在退出时保存进度。

### 任务 4.1：播放器引擎外壳 (Player Wrapper)

- [x] 目标：通过 `PlayerEngine` 封装播放器，接收流媒体 URL 并与播放进度存储协作。
- [ ] 实现（AVPlayer 已完成，平台验收未完成）：
  - 基于 `AVPlayer` 构建 SwiftUI 可复用播放器组件。
  - 暴露播放、暂停、seek、当前时间读取能力。
  - 支持 iOS、macOS、tvOS 条件编译差异。
- [ ] 验收标准：
  - 可播放远程或局域网流媒体 URL。
  - 播放器生命周期与 SwiftUI 视图生命周期一致。
  - 退出播放器时可读取准确的当前播放秒数。

### 任务 4.2：断点续播与自动存档逻辑

- [x] 播放视图启动时：
  - 检查该视频在 SwiftData 中是否存在 `lastPlayedTime`。
  - 如果存在且 `isFinished == false`，提示用户“是否从 XX:XX 继续播放”，或自动执行 `player.seek(to:)`。
- [x] 退出与生命周期保存：
  - 将当前 `player.currentTime()` 写入 `PlaybackProgress`。
  - 更新 `updatedAt`。
  - 触发 SwiftData 保存。
- [ ] 验收标准：
  - 已看完的视频不会重复提示续播，除非业务规则要求允许重看。
  - 续播 seek 位置误差在可接受范围内。
  - 播放接近结尾时可自动标记 `isFinished`。

## M5: 多端 UI 适配与海报墙 (Multi-platform UI)

给 AI 的指令：

> 编写多端通用的媒体库海报墙界面。在 macOS/iPadOS 上支持鼠标悬停，在 tvOS 上支持遥控器聚焦。

### 任务 5.1：多端共享海报墙 (Media Grid View)

- [x] 目标：展示媒体条目、海报和播放进度。
- [x] 多端差异化处理（功能代码已接入，平台验收未完成）：
  - `#if os(tvOS)`：使用大尺寸 Grid，去掉滚动条显示，增强 focus 反馈。
  - `#if os(macOS)`：支持右键菜单，包括删除、重命名、加入播放列表。
  - iPadOS / iOS：支持触控选择和详情页跳转。
- [ ] 验收标准：
  - 不同平台使用同一媒体数据源。
  - 海报图、标题、播放进度在网格卡片内排版稳定。
  - tvOS 焦点移动不会造成布局跳动。
  - macOS 右键菜单操作能更新 SwiftData 数据。

### 任务 5.2：同步状态 UI 提示

- [ ] 目标（本地进度条已完成，云端刷新提示未完成）：
  - 在视频封面或详情页显示进度条，指示当前观看了多少。
  - 如果刚从云端同步了新进度，在 UI 上做一个轻量级的刷新提示。
- [ ] 实现：
  - 根据 `lastPlayedTime / duration` 计算播放百分比。
  - 监听播放进度模型变化并刷新 UI。
  - 云端同步更新后显示非阻塞提示。
- [ ] 验收标准：
  - 进度条能准确反映当前用户的观看进度。
  - 云端更新不会打断用户当前播放。
  - 同步提示不会遮挡主要操作。

## M6: 局域网媒体源 (Media Sources)

### 任务 6.1：WebDAV 浏览与扫描

- [x] 定义统一 `MediaSourceProvider` 接口。
- [x] 实现 WebDAV 连接测试和 `PROPFIND` 请求骨架。
- [x] 解析 WebDAV Multi-Status XML，并区分目录与媒体文件。
- [x] 支持目录浏览、递归扫描、取消任务和错误重试。
- [x] 将扫描结果使用稳定 ID 写入 `MediaItem`，并处理新增、更新和删除。
- [ ] 使用 Keychain 凭据完成认证请求和真实媒体播放。

### 任务 6.2：SMB Provider

- [x] 预留 SMB Provider 接口边界。
- [ ] 选定并集成支持 Apple 全平台的 SMB 实现。
- [ ] 完成连接、浏览、认证、可播放数据流和错误映射。

## M7: 在线元数据与缓存 (Metadata)

- [x] 定义可插拔 `MetadataProvider`。
- [x] 实现 TMDB 电影搜索响应解析。
- [x] 实现 SwiftData `MetadataCache` 读写骨架。
- [x] 提供安全的 API Key 配置入口。
- [x] 实现电影、剧集和季集文件名识别。
- [x] 将扫描、搜索、用户确认、缓存和 `MediaItem` 更新串成完整流程。
- [x] 缓存命中时不重复请求在线 Provider，并增加对应测试。

## M8: Apple 全平台 Targets

- [x] 准备 tvOS、iOS 和 macOS App 入口文件。
- [x] 根目录 tvOS 工程关联 `VisionHubCore`。
- [ ] 在当前 Xcode 工程创建 iOS/iPadOS target 并完成构建验证。
- [ ] 在当前 Xcode 工程创建 macOS target 并完成构建验证。
- [ ] 配置三个 target 共用 CloudKit Container、签名能力和迁移策略。
- [ ] 分别验收遥控器、触控、键鼠、菜单和窗口行为。

## 全局非功能需求

- [x] 多端通用代码应优先放在共享 Swift 模块中。
- [x] 平台差异使用条件编译或平台专属 View Modifier 隔离。
- [ ] SwiftData 模型需要考虑 CloudKit schema 约束和未来迁移。
- [x] 敏感信息使用 Keychain 保存，SwiftData 只保存凭据引用。
- [x] 所有用户相关查询必须以当前用户为边界。
- [x] 播放进度写入需要节流，避免 CloudKit 频繁同步。
- [x] 每次功能、工程或测试修改必须同步本文件中的模块完成度和验证记录。

## 建议实施顺序

1. M1 数据模型。
2. M2 CloudKit / SwiftData 容器与同步策略。
3. M3 用户选择与全局用户状态。
4. M4 播放器与断点续播。
5. M5 海报墙和同步状态反馈。
6. M6 WebDAV 浏览、扫描与真实播放。
7. M7 元数据自动匹配与缓存编排。
8. M8 iOS/iPadOS/macOS targets 与平台验收。
