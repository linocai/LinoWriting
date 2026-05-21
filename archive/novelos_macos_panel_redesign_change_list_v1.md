# NovelOSMac 当前面板改造清单 v1

> 角色视角：资深 macOS / SwiftUI 前端面板设计师  
> 目标：把当前仓库里的 macOS 前端，从“功能骨架可用”提升到 HTML 原型里的“小说操作系统工作台”质感。  
> 范围：只改前端面板、视觉层级、交互布局和组件体系；不改变后端流程；不增加用户主流程动作。  
> 参照原型：`novel_macos_frontend_prototype_v1.html`  
> 参照仓库：`linocai/LinoWriting` → `NovelOSMac/Sources/NovelOSMac/Views`

---

## 0. 总判断

当前前端已经有正确的信息架构：

```text
RootShellView
├─ SidebarView
├─ MainWorkspaceView
│  ├─ ChapterStudioView
│  ├─ BaseFilesView
│  ├─ KnowledgeMatrixView
│  ├─ VersionsDebugView
│  ├─ ChaptersListView
│  └─ WritingSettingsView
└─ InspectorView
```

也已经拆出了：

```text
ChapterStudio 五步流程
基础文件编辑区
Knowledge Matrix
版本记录 / 调试区
章节列表
写作设置
```

问题不是“结构错了”，而是：

```text
当前 SwiftUI 面板更像系统默认控件拼出来的工程界面；
HTML 原型更像一个完整的 macOS 创作工作台。
```

所以本轮不要推翻代码结构，应该保留现有 View 拆分，集中重做以下四件事：

```text
1. 设计系统升级
2. 三栏布局质感升级
3. Chapter Studio 五步流程视觉重做
4. 基础文件 / Knowledge Matrix / Inspector 面板重新排版
```

---

## 1. 不要改的东西

以下内容保持不变。

### 1.1 用户主流程仍然只有五步

```text
1. 输入 Prompt
2. 审核结构化 Prompt
3. 审核正文
4. 批准正文
5. 确认基础文档更新
```

不要新增：

```text
单独审核 Context Pack
单独审核 Scene Plan
单独审核 Agent Run
单独确认 Audit Plan
单独确认 Revision Plan
```

### 1.2 不做聊天 UI

不要把 Chapter Studio 改成聊天气泡。Prompt 是章节指令，不是普通聊天消息。

### 1.3 不做 Scene Plan UI

后端已经取消按 Scene 生成。前端只允许出现“最多两个自然场景”的写作设置，不要做 Scene Plan 编辑器。

### 1.4 保留当前文件分层

继续使用：

```text
Views/RootShellView.swift
Views/DesignSystem.swift
Views/Components/BasicComponents.swift
Views/ChapterStudio/*.swift
Views/Workspaces/*.swift
```

不要把所有 UI 合并成一个巨大的 View。

---

# 2. P0 改造：设计系统必须先改

当前 `AppTheme` 太接近系统默认色：

```swift
Color(nsColor: .windowBackgroundColor)
Color(nsColor: .controlBackgroundColor)
Color(nsColor: .textBackgroundColor)
```

这会导致界面偏“系统表单感”，缺少 HTML 原型里的玻璃面板、柔和阴影和现代 macOS 工作台质感。

## 2.1 修改文件

```text
NovelOSMac/Sources/NovelOSMac/Views/DesignSystem.swift
NovelOSMac/Sources/NovelOSMac/Views/Components/BasicComponents.swift
```

## 2.2 新增设计 token

建议把 `AppTheme` 扩成下面这类结构：

```swift
enum AppTheme {
    static let backgroundBase = Color(red: 0.956, green: 0.956, blue: 0.972)
    static let sidebarBase = Color(red: 0.925, green: 0.925, blue: 0.945)

    static let panel = Color.white.opacity(0.72)
    static let panelSolid = Color.white
    static let panelSubtle = Color.black.opacity(0.04)

    static let line = Color.black.opacity(0.12)
    static let lineStrong = Color.black.opacity(0.20)

    static let text = Color(red: 0.12, green: 0.14, blue: 0.16)
    static let muted = Color(red: 0.42, green: 0.45, blue: 0.50)
    static let muted2 = Color(red: 0.54, green: 0.56, blue: 0.60)

    static let blue = Color(red: 0.04, green: 0.52, blue: 1.00)
    static let green = Color(red: 0.18, green: 0.64, blue: 0.31)
    static let orange = Color(red: 0.75, green: 0.42, blue: 0.01)
    static let red = Color(red: 0.82, green: 0.14, blue: 0.18)
    static let purple = Color(red: 0.51, green: 0.31, blue: 0.87)

    static let radiusXL: CGFloat = 22
    static let radiusLG: CGFloat = 16
    static let radiusMD: CGFloat = 12
    static let radiusSM: CGFloat = 10

    static let pagePadding: CGFloat = 22
    static let cardPadding: CGFloat = 18
    static let sectionGap: CGFloat = 16
}
```

如果要支持深色模式，先保留语义命名，不要在各个 View 里写死颜色。后续可用 `ColorScheme` 做 light/dark 分支。

## 2.3 新增通用 modifier

当前 `subtleBorder(_ radius: CGFloat = 8)` 半径太小，视觉显得硬。建议新增：

```swift
extension View {
    func glassPanel(radius: CGFloat = AppTheme.radiusXL) -> some View
    func glassCard(radius: CGFloat = AppTheme.radiusXL) -> some View
    func softControl(radius: CGFloat = AppTheme.radiusMD) -> some View
    func focusRing(active: Bool) -> some View
}
```

视觉目标：

```text
Card：白色 72% 透明 + 1px 白色内边界 + 轻阴影 + blur / material
Side note：黑色 4% 背景 + 1px line + 16px radius
Editor：白色 82% 背景 + 12px radius + focus ring
```

## 2.4 重做 CardView

当前 `CardView`：

```swift
.background(AppTheme.surface)
.subtleBorder()
```

目标改成：

```text
radius: 22
background: rgba white / material
border: white 0.85 或 line 0.12
shadow: 0 20 50 rgba(20,25,35,.08)
overflow hidden
```

SwiftUI 实现建议：

```swift
.background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.radiusXL, style: .continuous))
.background(AppTheme.panel, in: RoundedRectangle(cornerRadius: AppTheme.radiusXL, style: .continuous))
.overlay(
    RoundedRectangle(cornerRadius: AppTheme.radiusXL, style: .continuous)
        .stroke(Color.white.opacity(0.85), lineWidth: 1)
)
.shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 14)
```

## 2.5 CardHeader / CardBody / CardFooter 调整

当前 padding 是 16，border 很平。建议：

```text
CardHeader: padding top 16, horizontal 18, bottom 12
CardBody: padding 18
CardFooter: padding 14 x 18, background white 46%, top border line
```

CardFooter 要有轻微半透明底色，这样按钮区和正文区分离。

---

# 3. P0 改造：RootShell 三栏要更像 macOS 工作台

## 3.1 修改文件

```text
Views/RootShellView.swift
NovelOSMac.swift
```

## 3.2 当前问题

当前 `RootShellView` 已经是：

```swift
NavigationSplitView {
    SidebarView()
} detail: {
    HStack {
        MainWorkspaceView()
        InspectorView()
    }
}
```

方向对，但有几个视觉问题：

```text
1. 右侧 Inspector 宽度只有 300，HTML 原型是 340。
2. detail 区用了 78pt 顶部空白，导致内容像被硬推下去。
3. 背景是系统 windowBackground，缺少原型中的柔和渐变和层次。
4. Sidebar、Main、Inspector 三栏之间的材质感不统一。
```

## 3.3 目标布局

```text
Sidebar: 260 pt
Main: flexible, min 760 pt
Inspector: 340 pt
```

```swift
SidebarView()
    .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 300)

InspectorView()
    .frame(width: 340)
```

## 3.4 背景改造

主窗口背景应是：

```text
浅灰基础色
左上轻微蓝色径向光
右上轻微紫色径向光
```

SwiftUI 可以做一个 `AppBackgroundView`：

```swift
struct AppBackgroundView: View {
    var body: some View {
        ZStack {
            AppTheme.backgroundBase
            RadialGradient(
                colors: [AppTheme.blue.opacity(0.08), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520
            )
            RadialGradient(
                colors: [AppTheme.purple.opacity(0.08), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }
}
```

## 3.5 不要用硬编码 78pt 顶部空白

当前有：

```swift
.safeAreaInset(edge: .top, spacing: 0) {
    Color.clear.frame(height: macOSTitlebarInset)
}
```

建议改成以下两种之一：

### 方案 A：隐藏标题栏，自己处理顶部间距

在 `NovelOSMac.swift` 的 WindowGroup 上用：

```swift
.windowStyle(.hiddenTitleBar)
.windowToolbarStyle(.unifiedCompact)
```

然后 Sidebar 顶部保留 14-20pt padding 即可。

### 方案 B：保留系统标题栏，不做 78pt 空 inset

Main 内容只保留正常：

```swift
.padding(.top, 20)
```

不要让 detail 区出现大块空白。

推荐方案 A，更接近 HTML 原型。

---

# 4. P0 改造：Sidebar 需要从“蓝色选中列表”改成“玻璃导航栏”

## 4.1 修改文件

```text
Views/RootShellView.swift
Views/Components/BasicComponents.swift
```

## 4.2 当前问题

当前 Sidebar 的 active item 是整块蓝色：

```swift
.background(appStore.selectedWorkspace == workspace ? AppTheme.blue : Color.clear)
.foregroundStyle(appStore.selectedWorkspace == workspace ? Color.white : AppTheme.text)
```

这会显得偏 iPad / 管理后台，不像 HTML 原型里的 macOS 创作工具。

## 4.3 目标效果

Sidebar 应该是：

```text
半透明浅灰背景
Novel Card 白色玻璃卡片
导航项默认透明
hover 浅白
active 白色卡片 + 轻阴影 + 黑色文字
icon 是一个小 tile，不是纯 SF Symbol 裸图标
```

## 4.4 改造动作

### 4.4.1 Novel Card

当前 card radius 8，太小。改为：

```text
padding: 14
radius: 16
background: white 65%
border: white 80%
shadow: 0 8 22 rgba(.04)
```

内容保留：

```text
Current Novel
小说名
第 N 章 · Canon vX
类型 pill + 已导入前三章 pill
```

### 4.4.2 Navigation Item

新增组件：

```swift
struct SidebarNavItem: View {
    let workspace: Workspace
    let isSelected: Bool
}
```

状态视觉：

```text
normal: transparent
hover: white 58%
selected: white 90% + 轻阴影 + 字重 720
```

不要使用整块蓝底。蓝色只用于小 icon、左侧细条或轻微 tint。

### 4.4.3 Sidebar Footer

HTML 原型底部有提示区。建议补上：

```text
Context Compiler、Knowledge Guard、Named Entity Linter 默认后台运行。
你只需要完成五个用户动作。
```

这会让用户理解：复杂 Agent 在后台，不需要他多操作。

---

# 5. P0 改造：TopBar 视觉层级调整

## 5.1 修改文件

```text
Views/Components/BasicComponents.swift
```

## 5.2 当前问题

`TopBarView` 用的是：

```swift
.font(.largeTitle.weight(.bold))
```

这在 macOS 上可能显得过大，而且不同页面标题高度不稳定。

## 5.3 目标效果

```text
kicker: 13pt, semibold, muted, optional uppercase
h1: 28pt, bold, letter spacing -0.02em
actions: 右侧横排，间距 8
整体 margin-bottom: 16
```

## 5.4 改造动作

`TopBarView` 改为：

```swift
Text(kicker)
    .font(.system(size: 13, weight: .semibold))
    .foregroundStyle(AppTheme.muted)

Text(title)
    .font(.system(size: 28, weight: .bold, design: .default))
    .tracking(-0.4)
```

顶部按钮不要使用系统 `.borderedProminent` 默认样式，改用自定义 `PrimaryButtonStyle`、`BlueButtonStyle`、`GhostButtonStyle`。

---

# 6. P0 改造：Chapter Stepper 要重做成原型里的五格玻璃进度条

## 6.1 修改文件

```text
Views/ChapterStudio/ChapterStudioView.swift
Views/Components/BasicComponents.swift
```

## 6.2 当前问题

当前 `ChapterStepperView` 是五个 Button 直接横排，每个 cell 用 8pt radius。虽然功能对，但不像原型。

## 6.3 目标效果

外层是一个完整容器：

```text
background: white 66%
border: white 80%
radius: 22
shadow: AppTheme.shadow
padding: 10
grid: 5 equal columns
gap: 8
```

内部 step：

```text
normal: transparent
hover: white 60%
active: solid white + blue border + blue soft shadow
done: green weak background
locked: opacity 0.48
```

## 6.4 改造动作

新增：

```swift
struct ChapterStepperContainer: View
struct ChapterStepCell: View
```

不要让 step cell 独立散在背景上，要有一个整体 stepper panel。

## 6.5 step cell 尺寸

```text
minHeight: 86
radius: 16
number circle: 24 x 24
title: 13pt / weight 780
subtitle: 12pt / muted / lineLimit 2
```

## 6.6 交互

点击已解锁步骤可以跳转，未解锁步骤 disabled。不要增加新的确认动作。

---

# 7. P0 改造：Prompt 输入页需要补回右侧说明和本章边界预览

## 7.1 修改文件

```text
Views/ChapterStudio/StepPromptInputView.swift
```

## 7.2 当前问题

当前第一步只有一个输入卡片：

```text
本章原始 Prompt
TextEditor
保存草稿 / 生成结构化 Prompt
```

HTML 原型里第一步是两栏：

```text
左：输入卡片 + 本章预设边界三块小卡
右：说明卡片组
```

当前少了这些视觉内容，导致第一步显得空、工具感不足。

## 7.3 目标布局

使用：

```swift
ViewThatFits(in: .horizontal) {
    HStack(alignment: .top, spacing: 16) {
        promptCard.frame(minWidth: 620)
        promptHelpRail.frame(width: 300)
    }

    VStack(alignment: .leading, spacing: 12) {
        promptCard
        promptHelpRail
    }
}
```

## 7.4 Prompt 卡片内部补三块 mini note

在 TextEditor 下方增加：

```text
本章出场
A / B / C

弱提及
A 的母亲 · 最多 1 次

新角色策略
默认禁止新增命名角色
```

这些不是新增用户动作，只是状态预览。

## 7.5 右侧说明卡

补回三张 `SideNoteView`：

```text
你只需要写方向
系统会自动读取 Memory、World Bible、人物卡和 Knowledge Matrix。

为什么不是聊天
Prompt 是章节指令，不是对话。用表单和版本记录承载，而不是无限聊天气泡。

下一步
生成结构化 Prompt 后，你只审核可见文本，不单独审核 Context Pack。
```

## 7.6 TextEditor 视觉

当前 TextEditor 太像系统默认输入框。改成：

```text
minHeight: 170
idealHeight: 240
background: white 82%
radius: 12
border: lineStrong
focus: blue ring 4pt opacity 0.1
```

---

# 8. P0 改造：结构化 Prompt 审核页要从 TextEditor 堆叠改成 Prompt Cards

## 8.1 修改文件

```text
Views/ChapterStudio/StepStructuredPromptReviewView.swift
```

## 8.2 当前问题

当前已经有两栏结构，但主体字段是普通 `TextEditor`：

```text
本章目标
必须发生
禁止发生
本章可用专名
文风与叙事限制
```

功能是对的，但视觉上缺少“结构化 Prompt”的可读层级。

## 8.3 目标效果

每个部分是一个 `PromptCard`：

```text
本章目标        可编辑 pill
正文内容

必须发生        ✓ 列表
每条一行，有绿色 check icon

禁止发生        × 列表
每条一行，有红色 cross icon

本章可用专名    chips
A · ACTIVE / B · ACTIVE / C · ACTIVE / 旧码头 / 旧案 / A 的母亲 · MENTION 1

文风与叙事限制  可编辑
冷感、克制、少解释……
```

## 8.4 组件建议

新增：

```swift
struct PromptCard<Content: View>: View
struct EditablePromptBlock: View
struct EditableListBlock: View
struct EntityChipGrid: View
```

## 8.5 列表编辑方式

不要只用大 TextEditor。建议两种可选方案：

### 推荐方案：行级编辑

```text
每条 mustHappen / mustNotHappen 是一个 TextField 或 multiline TextField
左侧有 check / cross icon
右侧有小删除按钮
底部有“新增一条”小按钮
```

这不算新增主流程动作，只是编辑结构化 Prompt 的内部操作。

### 简化方案：继续用 TextEditor，但包进 PromptCard

如果先追求速度，可以保留现有 Binding，外面改成 PromptCard，并在标题上加 `可编辑` pill。

## 8.6 右侧提示区

当前 helpBlocks 内容方向对，但视觉要改成 HTML 的：

```text
soft-warning：你审核的是结构化 Prompt，不是底层 Context Pack。
side-note：Context Compiler 已隐藏本章不相关人物。
side-note：批准后直接整章生成，不进入 Scene Plan。
```

---

# 9. P0 改造：正文审核页要变成“阅读 + 修改 + 审计右栏”的创作界面

## 9.1 修改文件

```text
Views/ChapterStudio/StepDraftReviewView.swift
```

## 9.2 当前优点

当前已经有：

```text
正文编辑器
我的修改意见
自动审计摘要
越界检查
按我的意见修改
保存当前版本
我满意，进入批准
```

流程是对的。

## 9.3 当前问题

视觉上仍是系统 TextEditor + 普通侧栏，缺少原型里的“稿件阅读区”质感。

## 9.4 正文编辑器改造

目标：

```text
minHeight: 520
font: 15pt SF Pro Text / body
lineSpacing: 接近 1.8
background: white 82%
radius: 12
padding: 12
```

SwiftUI `TextEditor` 的 line-height 不好直接设置。建议用以下方向：

```swift
TextEditor(text: draftTextBinding)
    .font(.system(size: 15, weight: .regular, design: .default))
```

如果后续要更像写作编辑器，可以封装 AppKit `NSTextView`，但第一版不强制。

## 9.5 审计右栏改造

当前 `auditPanel` 放在 HStack 右侧，宽度 300。建议改成 320，内部使用：

```text
SideNoteView(title: 自动审计摘要)
AuditIssueCard list

SideNoteView(title: 越界检查)
Metric rows
```

Audit card 颜色：

```text
S0: red weak
S1: orange weak
S2: blue weak
```

不要显示过多复杂 JSON，只显示问题、人类可读位置、建议。

## 9.6 Footer 按钮层级

```text
主按钮：我满意，进入批准        blue
次按钮：按我的意见修改          default / dark
弱按钮：保存当前版本            ghost
```

如果 `finalApprovalBlockedReason != nil`，按钮 disabled，同时在 footer 上方显示红色 blocking notice。

---

# 10. P1 改造：批准正文页不要显示空状态，要显示“最终候选摘要”

## 10.1 修改文件

```text
Views/ChapterStudio/StepFinalApprovalView.swift
```

## 10.2 当前问题

当前有一个 `EmptyStateView`：

```text
批准正文后，系统会根据本章内容准备基础文档更新候选。
```

这会显得页面没有内容。

## 10.3 目标效果

正文批准页应该是一个“确认锁定”页面：

```text
左侧：最终版本摘要 card
右侧：批准意味着什么 / 版本控制 side notes
```

最终版本摘要包括：

```text
版本号
字数
审计状态
Canon 版本 vX -> 待生成 vX+1
Allowed Names 通过
Knowledge Guard 通过
```

## 10.4 增加最终正文预览

建议加一个折叠或只读短预览：

```text
最终正文预览：前 400 字 / 或摘要
```

不要让用户在这一步再次编辑正文。编辑只能回到第三步。

---

# 11. P1 改造：Canon Patch 页改成 Timeline，而不是普通列表

## 11.1 修改文件

```text
Views/ChapterStudio/StepCanonPatchReviewView.swift
```

## 11.2 当前问题

当前 patch item 是普通 VStack + Picker，能用但不够清楚。

## 11.3 目标效果

用 timeline 表达“本章将写入哪些基础文件”：

```text
Memory       新增章节事实
Character    更新 A/B/C 当前状态或关系
Knowledge    更新谁知道什么
World Bible  更新总 Bible 的关键长期信息
```

每条 patch：

```text
左侧 target badge
中间 title + summary
右侧 segmented decision：接受 / 修改 / 拒绝
```

如果选择“修改”，展开一个编辑框。

## 11.4 颜色

```text
Memory: blue
Character: orange
Knowledge: purple
World Bible: green
```

## 11.5 分组显示

如果 patch item 数量多，按 target 分组：

```text
Memory Updates
Character Card Updates
Knowledge Matrix Updates
World Bible Updates
```

第一版可以先不分组，但视觉上要像 timeline。

---

# 12. P0 改造：右侧 Inspector 必须补全，不只是“本章边界”

## 12.1 修改文件

```text
Views/RootShellView.swift
```

## 12.2 当前问题

当前 `InspectorView` 只有一个 section：

```text
本章边界
状态
本章出场
可用专名数
弱提及额度
新增命名角色
```

HTML 原型的 Inspector 是四块：

```text
本章安全边界
后台运行状态
用户只需关心
macOS 交互建议
```

当前少了 3 块，所以右栏信息密度不足。

## 12.3 目标结构

```text
InspectorView
├─ InspectorSection: 本章安全边界
│  ├─ Active Cast
│  ├─ Allowed Names
│  ├─ Mention Budget
│  └─ 新增命名角色
├─ InspectorSection: 后台运行状态
│  ├─ Context Compiler
│  ├─ Knowledge Guard
│  └─ Named Entity Linter
├─ InspectorSection: 用户只需关心
│  ├─ 1 输入本章 Prompt
│  ├─ 2 审核结构化 Prompt
│  ├─ 3 审核正文
│  ├─ 4 批准正文
│  └─ 5 确认基础文档更新
└─ InspectorSection: macOS 交互建议
```

## 12.4 视觉

Inspector 本身：

```text
width: 340
background: rgba(246,246,248,.78) / material
border-left: line
padding: 20 16 30
sticky / full height
```

Section：

```text
background: white 64%
border: white 86%
radius: 16
shadow: subtle
padding: 14
margin-bottom: 12
```

## 12.5 重要原则

Inspector 只做状态提示，不放必须点击的按钮。这样不会增加用户动作。

---

# 13. P1 改造：基础文件页要从“表单集合”变成“基础资产编辑器”

## 13.1 修改文件

```text
Views/Workspaces/BaseFilesView.swift
```

## 13.2 当前优点

当前已经有三类：

```text
World Bible
Character Cards
Memory / Chapter Facts
```

也支持新增、保存、删除，这是正确的。

## 13.3 当前问题

```text
1. 左侧 document selector 只是普通按钮列表，质感不足。
2. World Bible section 太像普通表单，没有“总 Bible”的档案感。
3. Character Card 缺少模型里已有的一些字段 UI。
4. Memory Facts 缺少时间线感。
5. TextEditor 多处没有统一的 editor 样式。
```

## 13.4 左侧基础文件导航

把当前 240pt 的 selector 改成独立 glass card：

```text
World Bible
总 Bible，含文风、现实逻辑、背景、禁用写法、杂项关键设定。

Character Cards
人物稳定特征、当前状态、人物关系、说话方式。

Memory / Chapter Facts
章节事实、历史事件、地点状态、物品状态。
```

Selected：白底 + 蓝色边框 + 微弱蓝背景。  
Normal：白底玻璃卡。

## 13.5 World Bible 编辑器

每个 section 应该像“档案块”，不是普通输入框堆叠。

建议显示：

```text
Section 标题
内容
重要性 pill
激活策略 pill
Tags chips
Canon vX
Updated at
删除按钮 icon-only
```

### 13.5.1 标签输入

当前 tags 用逗号 TextField 可以保留，但显示上需要同时渲染 chip preview。

### 13.5.2 激活策略解释

`ActivationPolicy` 对用户不直观。UI 文案应转换：

```text
always_in_context_brief → 总是进入简报
always_considered → 总是参与筛选
tag_matched → 标签命中时进入
manual_only → 仅手动调用
```

不要直接暴露 snake_case。

## 13.6 Character Cards 编辑器

当前 UI 没展示模型里的全部关键字段。至少补：

```text
aliases
role
stableTraits
currentState
dialogueStyle
relationships
forbiddenBehavior
lastActiveChapterNo
canonVersion
```

### 13.6.1 人物卡视觉

每个人物是一张 glass card：

```text
顶部：姓名 + 角色 pill + last active chapter
中间：稳定人格 / 当前状态 / 对话风格 / 禁止行为
底部：人物关系 nested cards
```

### 13.6.2 人物关系

关系不要只是两个 TextField。建议每条关系显示：

```text
目标人物
关系摘要
当前张力
lastChangedChapterNo
```

关系块使用浅灰 side-note 背景，避免卡片里再出现生硬表单。

## 13.7 Memory 编辑器

把 Memory Fact 改成时间线：

```text
第 4 章 · event
A 在旧码头发现门锁被换过……
Participants chips: A / B / C
Location pill: 旧码头
Evidence: 第4章第2段
Canon Status: confirmed
```

当前 Stepper + TextField 可以保留，但视觉上要被包成 timeline item。

## 13.8 保存 / 索引状态

顶部保留：

```text
保存修改
新增当前类型
```

`正在更新索引` 的状态很好，但要改成小型 status banner，别占主视觉。

---

# 14. P1 改造：Knowledge Matrix 要从粗表格变成“可编辑矩阵工作台”

## 14.1 修改文件

```text
Views/Workspaces/KnowledgeMatrixView.swift
```

## 14.2 当前优点

当前已经有：

```text
事实 / 秘密
作者
读者
每个角色
允许叙述
```

这符合后端规划。

## 14.3 当前问题

当前使用 `Grid` + 默认 `Picker`，容易变成密密麻麻的系统表格，视觉压力大。

## 14.4 目标效果

Knowledge Matrix 是核心安全资产，视觉应该清楚、可筛选、状态颜色强。

顶部增加 summary strip：

```text
Author Only: N
Reader Known: N
A Unknown: N
可能越界: N
```

这些不是新增操作，只是状态摘要。

## 14.5 状态 Picker 改造成 Pill Picker

不要用默认 Picker。新增：

```swift
struct KnowledgeStatePicker: View {
    @Binding var state: KnowledgeState
}
```

显示为一个可点击 pill：

```text
known              green
strongly_suspects  green
suspects           orange
hinted             orange
partial            orange
may_know           orange
author_only        purple
unknown            neutral
reader_unknown     neutral
reader_known       green
```

点击后弹出 Menu 选择状态。

## 14.6 Header / Left Column

矩阵很宽，建议：

```text
横向滚动
顶部 header 视觉固定感
左侧事实列更宽、更像卡片
每行 zebra background
```

SwiftUI 第一版不强制做 sticky header，但要用背景和分割线做出层级。

## 14.7 允许叙述列

`allowedNarration` 很关键，不要放成普通 TextField。改成：

```text
multiline TextField / TextEditor
width 320
minHeight 44
```

要让用户能写：

```text
A 只能怀疑，不能确认。
读者只能看到 B 的反应，不能得到旁白定论。
```

---

# 15. P1 改造：版本与调试区名字和视觉要统一

## 15.1 修改文件

```text
NovelOSMacCore/Workspace.swift
Views/Workspaces/VersionsDebugView.swift
```

## 15.2 当前问题

`Workspace.title` 里：

```swift
case .versionsDebug: "版本记录"
```

HTML 原型和产品文案是：

```text
版本与调试
```

请改为：

```swift
case .versionsDebug: "版本与调试"
```

## 15.3 视觉目标

版本与调试是高级区，应该弱化主流程感。

```text
Kicker: 版本记录 · 高级区
Title: 生成记录会留痕，但不打扰写作流程
```

当前方向对，但卡片视觉要跟统一 glass card。

## 15.4 Agent Run 历史

Agent Run 建议改成 timeline：

```text
12:01 Intent Parser       pass
12:02 Context Compiler    pass
12:04 Prompt Expander     user approved
12:10 Audit Agents        suggest
```

当前已经接近，主要是统一卡片样式和 timeline item 样式。

---

# 16. P2 改造：章节列表更像资产列表

## 16.1 修改文件

```text
Views/Workspaces/ChaptersListView.swift
```

## 16.2 当前问题

当前章节列表只有四行 timeline mock，后续章节多了会不够用。

## 16.3 目标效果

第一版可保持 timeline，但每行增加更明确的信息：

```text
章节号
标题 / 状态
一句摘要
字数
Canon version
approved / current / locked pill
```

## 16.4 点击行为

点击章节行应切到该章节的 Chapter Studio。  
当前按钮“新建下一章”可以保留。

---

# 17. P2 改造：写作设置页要统一为两张策略卡

## 17.1 修改文件

```text
Views/Workspaces/WritingSettingsView.swift
```

## 17.2 当前问题

当前直接 `HStack` 两张卡，在窄窗口可能挤压。

## 17.3 目标效果

使用：

```swift
ViewThatFits(in: .horizontal) {
    HStack(alignment: .top, spacing: 16) { ... }
    VStack(alignment: .leading, spacing: 16) { ... }
}
```

## 17.4 控件风格

目标字数、最多场景、新角色策略都要用统一的 `SoftTextField` / `SoftPicker`，不要直接系统默认控件。

---

# 18. P0 改造：按钮样式统一

## 18.1 修改文件

```text
Views/Components/BasicComponents.swift
```

## 18.2 当前问题

当前混用：

```swift
.buttonStyle(.borderedProminent)
.buttonStyle(.plain)
Button("...")
```

导致按钮视觉不统一。

## 18.3 新增 ButtonStyle

```swift
struct PrimaryButtonStyle: ButtonStyle
struct BlueButtonStyle: ButtonStyle
struct GhostButtonStyle: ButtonStyle
struct DangerButtonStyle: ButtonStyle
```

视觉：

```text
Primary: dark background, white text
Blue: blue background, white text
Ghost: transparent, muted text
Danger: red weak background, red text
Default: white 82%, lineStrong border
```

## 18.4 各页面按钮层级

### Chapter Studio topbar

```text
自动保存 pill
导出本章 ghost
继续当前步骤 primary dark
```

### Step 1

```text
保存草稿 ghost/default
生成结构化 Prompt blue
```

### Step 2

```text
返回 Prompt ghost
批准并生成正文 blue
```

### Step 3

```text
按我的意见修改 default
保存当前版本 ghost
我满意，进入批准 blue
```

### Step 4

```text
返回正文审核 ghost
批准正文并提取更新 blue
```

### Step 5

```text
稍后确认 ghost
确认更新，完成本章 blue
```

---

# 19. P0 改造：输入控件统一

## 19.1 当前问题

TextEditor、TextField、Picker 在各页面各用各的系统样式。

## 19.2 新增组件

```swift
struct SoftTextEditor: View
struct SoftTextField: View
struct SoftPicker<Value: Hashable>: View
struct LabeledField<Content: View>: View
```

## 19.3 SoftTextEditor 目标

```text
background: white 82%
radius: 12
border: lineStrong
padding: 8 or 11
focus ring: blue 0.1 shadow
```

## 19.4 LabeledField 目标

```text
label left, hint right
7pt label bottom gap
13pt label, weight 720
12pt hint, muted
```

这会让各页输入区域统一。

---

# 20. P1 改造：Pill / Entity Chip 状态色要更贴近原型

## 20.1 当前问题

当前 `PillView` 用纯色文字 + 0.12 opacity 背景，方向对，但颜色不够接近原型。

## 20.2 建议

每个 tone 拆为：

```swift
struct TonePalette {
    let foreground: Color
    let background: Color
    let border: Color
}
```

而不是只用 `tone.color.opacity(...)`。

原因：例如 blue 的前景不应直接是系统蓝，而应略深一点，背景淡蓝。

## 20.3 EntityChip

当前 EntityChip 只是胶囊。建议加：

```text
ACTIVE: green weak
MENTION: orange weak
BACKGROUND: blue weak
LOCKED_OUT: neutral / muted
NEW_ALLOWED: purple weak
```

在结构化 Prompt 页和 Inspector 页必须统一。

---

# 21. P1 改造：基础布局断点

## 21.1 目标

```text
>= 1280: 三栏全部展示
1100-1279: Inspector 可折叠，默认展示
< 1100: 隐藏 Inspector，通过 toolbar 按钮打开
< 900: Stepper 横向滚动
```

## 21.2 当前状态

当前部分页面用了 `ViewThatFits`，这是好的。RootShell 层还需要根据窗口宽度隐藏右侧 Inspector。

## 21.3 实现建议

可以在 RootShell 里用 `GeometryReader`：

```swift
let shouldShowInspector = proxy.size.width >= 1100 && appStore.isInspectorVisible
```

小窗口时在 topbar 放一个 “Inspector” 图标按钮，但这只是显示/隐藏状态栏，不是主流程动作。

---

# 22. P1 改造：macOS 交互细节

## 22.1 hover 状态

HTML 原型有 hover。SwiftUI 可以用：

```swift
@State private var isHovered = false
.onHover { isHovered = $0 }
```

应用在：

```text
Sidebar nav item
step cell
button
card action icon
```

## 22.2 Toolbar / titlebar

建议隐藏标题栏后，保留系统窗口控制按钮区域。不要在 SwiftUI 里画假的红黄绿按钮，除非完全自定义窗口。HTML 里的 traffic dots 是原型表达，不一定要照抄。

## 22.3 键盘快捷键

可以加但不显示成新流程：

```text
Cmd + Enter: 执行当前步骤主按钮
Cmd + S: 保存草稿 / 保存基础文件
Cmd + Shift + I: 显示隐藏 Inspector
```

---

# 23. P0 改造：状态信息不要像错误提示一样跳出来

## 23.1 当前问题

多处 `statusMessage` 是普通 Text banner。方向对，但视觉需要统一。

## 23.2 新增组件

```swift
struct StatusBanner: View {
    let message: String
    let tone: PillTone
}
```

视觉：

```text
font: callout semibold
padding: 12 x 8
background: tone weak
radius: 8 or 12
```

使用在：

```text
ChapterStudioView
BaseFilesView
KnowledgeMatrixView
VersionsDebugView
```

---

# 24. P1 改造：文案统一

## 24.1 Workspace title

统一为：

```text
Chapter Studio
基础文件
Knowledge Matrix
版本与调试
章节列表
写作设置
```

不要一处叫“知识矩阵”，一处叫 “Knowledge Matrix”，除非设计上刻意中英混排。建议 Sidebar 用：

```text
Knowledge Matrix
```

页面 kicker 用：

```text
知识矩阵 · 防穿帮
```

## 24.2 Base Files 文案

统一：

```text
基础文件 · 可手动编辑
World Bible、人物卡、Memory 是可编辑资产
```

## 24.3 Canon Patch 文案

统一：

```text
确认基础文档更新
只显示会改变 Canon 的内容。你可以逐条接受、修改或拒绝。
```

---

# 25. 文件级施工清单

## 25.1 `DesignSystem.swift`

必须做：

```text
[ ] 增加 radius token
[ ] 增加 spacing token
[ ] 增加 glass panel colors
[ ] 增加 line / lineStrong
[ ] 增加 weak tone colors
[ ] 增加 AppBackgroundView
[ ] 增加 glassCard / glassPanel / softControl modifier
```

## 25.2 `BasicComponents.swift`

必须做：

```text
[ ] 重做 PillView，使每个 tone 有 foreground/background/border
[ ] 重做 CardView / CardHeader / CardBody / CardFooter
[ ] 新增 SideNoteView
[ ] 新增 PromptCard
[ ] 新增 StatusBanner
[ ] 新增 SoftTextEditor / SoftTextField
[ ] 新增 ButtonStyle：Primary / Blue / Ghost / Danger
[ ] 新增 KnowledgeStatePill / EntityChipGrid
[ ] 新增 TimelineItemView
```

## 25.3 `RootShellView.swift`

必须做：

```text
[ ] Main 背景改成 AppBackgroundView
[ ] Sidebar 宽度 ideal 260
[ ] Inspector 宽度改 340
[ ] 移除或重构 78pt 顶部硬 inset
[ ] Sidebar active item 改白色卡片风格
[ ] Inspector 增加 4 个 section
[ ] 小窗口隐藏 Inspector
```

## 25.4 `ChapterStudioView.swift`

必须做：

```text
[ ] Stepper 外层加 glass container
[ ] Step cell radius 改 16
[ ] active / done / disabled 状态按原型重做
[ ] TopBar 按钮样式统一
[ ] 页面 padding 统一 22
```

## 25.5 `StepPromptInputView.swift`

必须做：

```text
[ ] 改成左主卡 + 右说明栏
[ ] Prompt 输入框用 SoftTextEditor
[ ] 输入框下补：本章出场 / 弱提及 / 新角色策略
[ ] 右侧补三张说明 side note
```

## 25.6 `StepStructuredPromptReviewView.swift`

必须做：

```text
[ ] 本章目标改 PromptCard
[ ] 必须发生改 check list 风格
[ ] 禁止发生改 cross list 风格
[ ] 可用专名改 EntityChipGrid
[ ] 文风限制改 PromptCard
[ ] 右侧帮助区改 soft-warning + side-note
```

## 25.7 `StepDraftReviewView.swift`

必须做：

```text
[ ] 正文编辑器 minHeight 520
[ ] 正文字体和行距更接近阅读稿件
[ ] 审计右栏改 SideNote + AuditIssueCard
[ ] Footer 按钮换统一样式
[ ] S0 blocking notice 视觉加强
```

## 25.8 `StepFinalApprovalView.swift`

必须做：

```text
[ ] 移除空洞 EmptyState
[ ] 增加最终候选摘要
[ ] 增加只读短预览或确认说明
[ ] 右侧帮助卡视觉统一
```

## 25.9 `StepCanonPatchReviewView.swift`

必须做：

```text
[ ] Patch item 改 timeline 风格
[ ] target badge 固定宽度
[ ] 接受 / 修改 / 拒绝用 segmented control
[ ] 修改态展开 SoftTextEditor
[ ] target 颜色统一：Memory blue / Character orange / Knowledge purple / WorldBible green
```

## 25.10 `BaseFilesView.swift`

必须做：

```text
[ ] 左侧基础文件 selector 改 glass card nav
[ ] World Bible section 改档案卡
[ ] Character Card 补 aliases / dialogueStyle / forbiddenBehavior / lastActiveChapterNo
[ ] Relationship card 补 lastChangedChapterNo
[ ] Memory 改 timeline item
[ ] 所有输入控件换 SoftTextField / SoftTextEditor
```

## 25.11 `KnowledgeMatrixView.swift`

必须做：

```text
[ ] 顶部增加 summary strip
[ ] 默认 Picker 改 KnowledgeStatePillPicker
[ ] Header row 强化背景
[ ] Row 增加 zebra background
[ ] allowedNarration 改 multiline editor
[ ] 状态色统一
```

## 25.12 `Workspace.swift`

必须做：

```text
[ ] versionsDebug title 从“版本记录”改为“版本与调试”
[ ] ActivationPolicy / ImportanceLevel 如需显示给用户，增加中文 displayName
[ ] KnowledgeState 增加中文 displayName 或 humanReadableLabel
```

---

# 26. 验收标准

完成后，用以下标准验收。

## 26.1 一眼看上去

应该像：

```text
macOS 创作工作台
小说操作系统
章节资产编辑器
```

不应该像：

```text
系统默认表单
聊天窗口
后台管理 CRUD
调试工具
```

## 26.2 用户动作

用户在主流程里仍然只看到五个动作：

```text
输入 Prompt
审核结构化 Prompt
审核正文
批准正文
确认基础文档更新
```

Inspector、Audit、Context、Agent Run 都不能变成新动作。

## 26.3 视觉对齐 HTML 原型

必须接近以下特征：

```text
三栏结构：260 / flexible / 340
浅灰渐变背景
半透明玻璃 Sidebar
圆角 22 的主卡片
圆角 16 的侧边说明卡
五步 stepper 是一个整体玻璃容器
正文审核页有明显阅读区和审计右栏
Inspector 至少 4 个 section
基础文件页像档案编辑器，不像普通表单
Knowledge Matrix 状态色强，可读性高
```

## 26.4 代码质量

```text
不要在每个页面复制颜色、圆角、阴影。
不要在业务 View 里写大量重复按钮样式。
不要新增主流程状态。
不要引入 Scene Plan。
不要把 Agent 调试信息推到主流程。
```

---

# 27. 推荐施工顺序

```text
第 1 批：DesignSystem + BasicComponents
第 2 批：RootShell + Sidebar + Inspector
第 3 批：Chapter Studio Stepper + Prompt 输入页
第 4 批：结构化 Prompt 页 + 正文审核页
第 5 批：Final Approval + Canon Patch
第 6 批：Base Files + Knowledge Matrix
第 7 批：Chapters List + Writing Settings + Versions Debug
```

不要一开始就改所有页面。先统一设计系统和根布局，否则后面会反复返工。

---

# 28. 最重要的一句话

当前代码的产品结构已经对了；下一步不是重构流程，而是把面板从“SwiftUI 默认控件集合”改造成“有质感、有边界、有安全感的 macOS 小说创作工作台”。

重点是：

```text
玻璃三栏
大圆角卡片
五步主流程
状态只提示，不打扰
基础文件像资产库
Knowledge Matrix 像安全控制台
正文审核像真正的写作编辑器
```
