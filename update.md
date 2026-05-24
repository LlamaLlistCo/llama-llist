[TOC]

# update

## 一、作业功能点对齐说明

本项目围绕《移动应用开发与测试》大作业要求，按“任务一：原生底层增强 + 任务二：全场景适配 + HapTest 测试”组织实现内容。

当前已落地并可展示的功能点主要包括：

1. **原生底层增强（Native + NAPI）**：关键词提取 Native 模块接入与业务联动。  
2. **算法增强（笔记应用方向）**：笔记全文索引/搜索排序接口。  
3. **全场景适配（手机/平板）**：平板双栏（列表-详情）布局与交互。  
4. **HapTest 测试**：两种测试策略（等价类 + 边界值）用例补齐。

---

## 二、任务一：原生底层增强（Native Engine Upgrade）

### 1) Native 模块接入（C++ + NAPI）

- 在前端工程中接入 Native 模块能力，ArkTS 通过 NAPI 调用 Native 逻辑。
- 已在页面业务中接入关键词提取能力，用于 AI 分析与内容处理流程。

**对应文件**：
- `frontend/LlamaLlistApp/entry/src/main/cpp/`（Native 模块目录）
- `frontend/LlamaLlistApp/entry/src/main/ets/common/native/KeywordNative.*`
- `frontend/LlamaLlistApp/entry/src/main/ets/pages/NoteEdit.ets`

### 2) 算法增强：笔记全文索引/搜索排序

- 新增面向笔记场景的“全文索引 + 加权排序”能力。
- 提供接口：`GET /notes/search/index?q=关键词&limit=20`
- 排序策略：
  - 标题命中：高权重
  - 摘要命中：中权重
  - 正文命中：低权重
  - 本地关键词命中：额外加权
- 返回结果按 `score` 降序，支持笔记检索与推荐排序展示。

**对应文件**：
- `backend/app/routers/ai.py`

### 3) 安全性与正确性（任务一配套能力）

- AI 云端 Provider URL 强制 HTTPS 并进行格式校验。
- 模型连通性检测接口可提前验证配置正确性。
- 上传文件增加后缀白名单与大小限制。
- AI 待办写入接口采用强类型请求体。

**对应文件**：
- `backend/app/routers/settings.py`
- `backend/app/routers/files.py`
- `backend/app/routers/ai.py`

---

## 三、任务二：全场景适配（Cross-Device Adaptation）

### 1) 手机/平板双设备形态支持

- 模块设备类型配置覆盖：`phone`、`tablet`。
- 针对平板场景实现差异化布局而非简单拉伸。

**对应文件**：
- `frontend/LlamaLlistApp/entry/src/main/module.json5`
- `frontend/LlamaLlistApp/entry/src/main/ets/pages/Index.ets`

### 2) 平板分栏架构（列表-详情）

- 主界面实现双栏结构：左侧列表、右侧详情展示。
- 补齐平板端交互细节：选中态、滚动区与信息密度优化。

**对应文件**：
- `frontend/LlamaLlistApp/entry/src/main/ets/pages/Index.ets`

### 3) Native ABI 多架构构建适配

- Native 构建配置支持 `arm64-v8a` 与 `x86_64`，覆盖真机与模拟器主流架构。

**对应文件**：
- `frontend/LlamaLlistApp/build-profile.json5`
- `frontend/LlamaLlistApp/entry/build-profile.json5`

---

## 四、应用功能增强（支撑展示效果）

### 1) AI 设置与模型检测

- 设置中心支持配置 Provider URL、API Key、模型名。
- 新增“检测模型”按钮，联动后端检测接口并即时提示结果。

**对应文件**：
- `frontend/LlamaLlistApp/entry/src/main/ets/pages/Index.ets`
- `backend/app/routers/settings.py`

### 2) AI 总结链路（云端 + 本地）

- 笔记摘要支持云端模型生成。
- 云端不可用时自动降级为本地算法总结，保证功能可用性与连续性。

**对应文件**：
- `backend/app/routers/ai.py`
- `backend/app/local_ai.py`

### 3) NoteEdit 导入/导出能力

- 导入：支持 `md/txt/word/doc/docx` 文件导入。
- 导出：支持 `md/txt/word` 格式导出。
- 导入过程包含后缀/空文件/格式匹配等校验与反馈。

**对应文件**：
- `frontend/LlamaLlistApp/entry/src/main/ets/pages/NoteEdit.ets`

### 4) Markdown Native 解析引擎（C++）

- 已实现 C++ 侧 Markdown 解析引擎，并通过 NAPI 暴露三类能力：
  - `parseMarkdown`：将 Markdown 解析为结构化块（标题、段落、引用、列表、待办、代码块、分割线）
  - `renderMarkdownToPlainText`：将 Markdown 渲染为纯文本
  - `exportMarkdown`：按结构化文档生成规范 Markdown
- 编辑页已接入解析结果回填：导入 `md` 文件时不再仅原样写入文本，而是按解析块回填到编辑器，标题/摘要同步提取并回填。
- 预览模式基于 Native 解析块进行结构化渲染。

**对应文件**：
- `frontend/LlamaLlistApp/entry/src/main/cpp/markdown_engine.cpp`
- `frontend/LlamaLlistApp/entry/src/main/cpp/markdown_engine.h`
- `frontend/LlamaLlistApp/entry/src/main/cpp/keyword_napi.cpp`
- `frontend/LlamaLlistApp/entry/src/main/ets/common/native/MarkdownNative.ets`
- `frontend/LlamaLlistApp/entry/src/main/ets/pages/NoteEdit.ets`

---

## 五、HapTest 测试（作业第4部分）

按要求完成两种策略测试用例：

1. **等价类划分（Equivalence Partition）**  
   - 覆盖待办筛选在不同状态/优先级组合下的匹配行为。  
2. **边界值分析（Boundary Value）**  
   - 覆盖摘要长度 299/300/301 的规范化处理结果。

**对应文件**：
- `frontend/LlamaLlistApp/entry/src/ohosTest/ets/test/Ability.test.ets`

---

## 六、功能点与作业要求映射

### 已满足的核心要求（可用于报告呈现）

- 任务一（Native 增强）：
  - Native 模块接入（NAPI 调用）
  - 算法增强（全文索引/排序）
  - 安全性/正确性加强（配置校验、上传限制、强类型接口）

- 任务二（全场景适配）：
  - 手机 + 平板设备支持
  - 平板分栏架构（列表-详情）
  - 多 ABI 构建适配

- HapTest：
  - 已完成两种测试策略用例

